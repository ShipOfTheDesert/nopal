module Make (A : Nopal_mvu.App.S) = struct
  type lifecycle = Created | Running | Shut_down

  type t = {
    model_var : A.model Lwd.var;
    viewport_var : Nopal_element.Viewport.t Lwd.var;
        (* mutable: external input updated by platform, monotonic-ish lifecycle *)
    view_lwd : A.msg Nopal_element.Element.t Lwd.t;
    init_cmd : A.msg Nopal_mvu.Cmd.t;
    sub_mgr : A.msg Sub_manager.t;
    queue : A.msg Queue.t;
        (* unbounded: a pathological Cmd.perform chain could grow this without
           limit. Acceptable for PoC — subscription count is typically small
           and cascading dispatches are shallow. Revisit if profiling shows
           unbounded growth in real applications. *)
    focus : string -> unit;
    schedule_after : int -> (unit -> unit) -> unit;
    recording : bool;
        (* Hot-path guard: [false] for [create], [true] for
           [create_with_telemetry]. The runtime cannot match the abstract
           [recorder] itself, so [dispatch] tests this flag to skip all telemetry
           work in one branch when off — keeping the plain runtime inert (REQ-N1
           "zero-cost by inspection") without calling into [Telemetry] per
           message. *)
    recorder : Telemetry.recorder;
        (* Telemetry target threaded through the dispatch loop. [Telemetry.off]
           for runtimes built by [create] (records nothing, zero per-event cost);
           an [On] recorder for [create_with_telemetry]. *)
    serialize_msg : A.msg -> string;
        (* Serialiser for recorded [Message] events. Never forced while
           [recorder] is [off] (REQ-N1). *)
    serialize_model : A.model -> string;
        (* Serialiser for recorded [Model_transition] events. Never forced while
           [recorder] is [off] (REQ-N1). *)
    on_fire : string -> unit;
        (* Subscription-firing hook handed to [Sub_manager.diff]. Built once at
           construction (not per [refresh]) so the hot subscription seam
           allocates no closure per call; on the [off] path this single closure's
           body is an inert [record_subscription off]. *)
    mutable processing : bool;
        (* mutable: re-entrancy guard for dispatch loop —
           checked and toggled within a single synchronous call frame *)
    mutable lifecycle : lifecycle;
        (* mutable: monotonic state machine Created -> Running -> Shut_down.
           Checked on dispatch, start, and shutdown to enforce valid transitions. *)
  }

  (* Shared record constructor for both public constructors below. The only
     difference between [create] and [create_with_telemetry] is the recorder and
     serialisers wired in here, so they share this assembly to keep the two
     entry points in lockstep. *)
  let make ?(focus = fun _id -> ()) ?(schedule_after = fun _ms _f -> ())
      ~recording ~recorder ~serialize_msg ~serialize_model () =
    let init_model, init_cmd = A.init () in
    let model_var = Lwd.var init_model in
    let viewport_var = Lwd.var Nopal_element.Viewport.desktop in
    {
      model_var;
      viewport_var;
      view_lwd = Lwd.map2 (Lwd.get viewport_var) (Lwd.get model_var) ~f:A.view;
      init_cmd;
      sub_mgr = Sub_manager.create ();
      queue = Queue.create ();
      focus;
      schedule_after;
      recording;
      recorder;
      serialize_msg;
      serialize_model;
      on_fire = (fun label -> Telemetry.record_subscription recorder label);
      processing = false;
      lifecycle = Created;
    }

  let create ?focus ?schedule_after () =
    make ?focus ?schedule_after ~recording:false ~recorder:Telemetry.off
      ~serialize_msg:(fun _msg -> "<opaque>")
      ~serialize_model:(fun _model -> "<opaque>")
      ()

  let create_with_telemetry ?focus ?schedule_after
      ?(serialize_msg = fun _msg -> "<opaque>")
      ?(serialize_model = fun _model -> "<opaque>") () =
    let recorder, handle = Telemetry.create () in
    let rt =
      make ?focus ?schedule_after ~recording:true ~recorder ~serialize_msg
        ~serialize_model ()
    in
    (rt, handle)

  let model rt = Lwd.peek rt.model_var
  let view rt = rt.view_lwd
  let viewport rt = Lwd.peek rt.viewport_var

  (* Call graph for the dispatch loop (mutual recursion):
     dispatch -> process_queue -> drain -> execute_cmd -> dispatch (queued)
                               -> refresh -> dispatch (from sub setup, queued)
     process_queue uses a while loop to avoid stack growth when refresh
     dispatches messages that require another drain/refresh cycle. *)
  let rec refresh rt =
    let m = model rt in
    let subs = A.subscriptions m in
    Sub_manager.diff ~on_fire:rt.on_fire
      ~dispatch:(fun msg -> dispatch rt msg)
      subs rt.sub_mgr

  and drain rt =
    while not (Queue.is_empty rt.queue) do
      let msg = Queue.pop rt.queue in
      let m = model rt in
      (* Record the message before [update] so a raising [update] still leaves
         the dispatched message in the log (the harness dumps history on
         exception). The transition is only recorded once [update] returns.
         Both blocks are behind [rt.recording] so a plain runtime does no
         telemetry work here at all (REQ-N1). *)
      if rt.recording then
        Telemetry.record_message rt.recorder msg ~serialize:rt.serialize_msg;
      let new_model, cmd = A.update m msg in
      Lwd.set rt.model_var new_model;
      if rt.recording then (
        Telemetry.record_transition rt.recorder ~before:m ~after:new_model
          ~serialize:rt.serialize_model;
        (* [Cmd.none] means no command was issued, so skip it — the log records
           only commands that do something, labelled by [Cmd.describe]'s stable
           output (Task 2), which the [Command] event and fragment assertions
           rely on. A typed [Cmd.is_none] predicate avoids coupling the skip to
           the literal ["none"] label string. *)
        if not (Nopal_mvu.Cmd.is_none cmd) then
          Telemetry.record_command rt.recorder (Nopal_mvu.Cmd.describe cmd));
      execute_cmd rt cmd
    done

  and process_queue rt =
    let continue = ref true in
    while !continue do
      drain rt;
      refresh rt;
      if Queue.is_empty rt.queue then continue := false
    done;
    rt.processing <- false

  and dispatch rt msg =
    (match rt.lifecycle with
    | Running -> ()
    | Created -> invalid_arg "Runtime: dispatch before start"
    | Shut_down -> invalid_arg "Runtime: dispatch after shutdown");
    Queue.push msg rt.queue;
    if not rt.processing then (
      rt.processing <- true;
      process_queue rt)

  and execute_cmd rt cmd =
    Nopal_mvu.Cmd.interpret ~focus:rt.focus
      ~dispatch:(fun msg -> dispatch rt msg)
      ~schedule_after:(fun ms msg ->
        rt.schedule_after ms (fun () ->
            match rt.lifecycle with
            | Running -> dispatch rt msg
            | Created
            | Shut_down ->
                ()))
      cmd

  let start rt =
    (match rt.lifecycle with
    | Created -> ()
    | Running -> invalid_arg "Runtime: already started"
    | Shut_down -> invalid_arg "Runtime: start after shutdown");
    rt.lifecycle <- Running;
    execute_cmd rt rt.init_cmd;
    (* This diff is not redundant with the one inside process_queue/refresh.
       If init_cmd is Cmd.none (the common case), no dispatch occurs, so
       process_queue never runs and refresh never fires. This explicit diff
       is the only thing that sets up initial subscriptions in that case.
       When init_cmd does dispatch, process_queue/refresh will have already
       diffed, making this call idempotent (Sub_manager skips known keys). *)
    let m = model rt in
    let subs = A.subscriptions m in
    Sub_manager.diff ~on_fire:rt.on_fire
      ~dispatch:(fun msg -> dispatch rt msg)
      subs rt.sub_mgr

  let shutdown rt =
    (match rt.lifecycle with
    | Running -> ()
    | Created -> invalid_arg "Runtime: shutdown before start"
    | Shut_down -> invalid_arg "Runtime: already shut down");
    rt.lifecycle <- Shut_down;
    Sub_manager.stop_all rt.sub_mgr

  let set_viewport rt vp =
    if Nopal_element.Viewport.equal (Lwd.peek rt.viewport_var) vp then ()
    else (
      Lwd.set rt.viewport_var vp;
      let m = model rt in
      let subs = A.subscriptions m in
      let vp_subs = Nopal_mvu.Sub.extract_on_viewport_changes subs in
      List.iter (fun (_key, f) -> dispatch rt (f vp)) vp_subs)
end

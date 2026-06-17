module Make (A : Nopal_mvu.App.S) = struct
  (* One state machine replaces the old [processing : bool] + [lifecycle]
     (Created/Running/Shut_down) pair: [Idle]/[Processing] split the old
     "Running" state by whether the dispatch loop is currently draining, while
     [Created] and [Shut_down] keep the pre-start / post-shutdown guards the
     public contract depends on. Boolean flags would readmit illegal
     combinations the variant makes unrepresentable. *)
  type phase = Created | Idle | Processing | Shut_down

  type t = {
    model_var : A.model Lwd.var;
    viewport_var : Nopal_element.Viewport.t Lwd.var;
        (* mutable: external input updated by platform, monotonic-ish lifecycle *)
    view_lwd : A.msg Nopal_element.Element.t Lwd.t;
    init_cmd : A.msg Nopal_mvu.Cmd.t;
    sub_mgr : A.msg Sub_manager.t;
    interpret_atom :
      dispatch:(A.msg -> unit) ->
      A.msg Nopal_mvu.Sub.atom ->
      (unit -> unit, string) result;
        (* Platform-supplied per-atom subscription interpreter handed to
           [Sub_manager.diff]. The runtime owns key lifecycle; the backend owns
           setup. Defaults to {!default_interpret_atom} (Custom + viewport, which
           need no platform event listener); [nopal_web] passes one that also
           drives [every], keydown, resize, and visibility (REQ-F3). *)
    queue : A.msg Queue.t;
        (* unbounded: a pathological Cmd.perform chain could grow this without
           limit. Acceptable for PoC — subscription count is typically small
           and cascading dispatches are shallow. Revisit if profiling shows
           unbounded growth in real applications. *)
    focus : string -> unit;
    schedule_after : int -> (unit -> unit) -> unit;
    on_error : string -> unit;
        (* Reports any exception raised by [A.update], [A.subscriptions], an
           effect thunk, or telemetry serialization, plus every post-shutdown
           dispatch that is dropped. The loop never propagates these — it reports
           and continues (REQ-F1/F2). *)
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
    mutable phase : phase;
        (* mutable: lifecycle + re-entrancy state machine. Created -> Idle on
           [start]; Idle <-> Processing around each dispatch loop; -> Shut_down
           on [shutdown]. All moves go through [apply_move]. *)
  }

  (* Default error sink: stderr maps to the browser console under jsoo. Public
     [?on_error] overrides it (the kitchen sink wires it to a visible toast). *)
  let default_on_error msg = prerr_endline ("[nopal_runtime] " ^ msg)

  (* Per-atom interpreter for runtimes with no platform event sources (the
     native default; backends like [nopal_web] override via [?interpret_atom]).
     [Custom] runs its setup with [dispatch]; [Viewport] is a no-op because
     viewport changes are delivered through {!set_viewport}, not a listener. The
     remaining built-ins have no native source, so they return [Error] — surfaced
     via [on_error], never a silent no-op (REQ-F3). The match is exhaustive: a
     new atom constructor is a compile error here. *)
  let default_interpret_atom ~dispatch atom =
    match atom with
    | Nopal_mvu.Sub.Custom { setup; _ } -> Ok (setup dispatch)
    | Viewport _ -> Ok (fun () -> ())
    | (Every _ | Keydown _ | Keyup _ | Resize _ | Visibility _) as a ->
        Error
          (Printf.sprintf
             "no event source for %s subscription %S on this runtime"
             (Nopal_mvu.Sub.describe_atom a)
             (Nopal_mvu.Sub.atom_key a))

  (* Shared record constructor for both public constructors below. The only
     difference between [create] and [create_with_telemetry] is the recorder and
     serialisers wired in here, so they share this assembly to keep the two
     entry points in lockstep. *)
  let make ?(focus = fun _id -> ()) ?(schedule_after = fun _ms _f -> ())
      ?(on_error = default_on_error) ?(interpret_atom = default_interpret_atom)
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
      interpret_atom;
      queue = Queue.create ();
      focus;
      schedule_after;
      on_error;
      recording;
      recorder;
      serialize_msg;
      serialize_model;
      on_fire = (fun label -> Telemetry.record_subscription recorder label);
      phase = Created;
    }

  let create ?focus ?schedule_after ?on_error ?interpret_atom () =
    make ?focus ?schedule_after ?on_error ?interpret_atom ~recording:false
      ~recorder:Telemetry.off
      ~serialize_msg:(fun _msg -> "<opaque>")
      ~serialize_model:(fun _model -> "<opaque>")
      ()

  let create_with_telemetry ?focus ?schedule_after ?on_error ?interpret_atom
      ?(serialize_msg = fun _msg -> "<opaque>")
      ?(serialize_model = fun _model -> "<opaque>") () =
    let recorder, handle = Telemetry.create () in
    let rt =
      make ?focus ?schedule_after ?on_error ?interpret_atom ~recording:true
        ~recorder ~serialize_msg ~serialize_model ()
    in
    (rt, handle)

  let model rt = Lwd.peek rt.model_var
  let view rt = rt.view_lwd
  let viewport rt = Lwd.peek rt.viewport_var

  (* Single source of truth for legal phase moves. Every transition names its
     intent and is decided here by one exhaustive match over (intent, phase), so
     adding a phase makes every move a compile error rather than a silent gap.
     Illegal public moves raise [Invalid_argument] (the contract for [start] /
     [shutdown]); the internal Begin/End moves are only ever invoked from a valid
     phase. *)
  type move = Start | Shutdown | Begin_processing | End_processing

  let apply_move rt move =
    let next =
      match (move, rt.phase) with
      | Start, Created -> Idle
      | Start, (Idle | Processing) -> invalid_arg "Runtime: already started"
      | Start, Shut_down -> invalid_arg "Runtime: start after shutdown"
      | Shutdown, (Idle | Processing) -> Shut_down
      | Shutdown, Created -> invalid_arg "Runtime: shutdown before start"
      | Shutdown, Shut_down -> invalid_arg "Runtime: already shut down"
      | Begin_processing, Idle -> Processing
      | Begin_processing, (Created | Processing | Shut_down) ->
          invalid_arg "Runtime: begin_processing from invalid phase"
      | End_processing, Processing -> Idle
      | End_processing, (Created | Idle | Shut_down) ->
          invalid_arg "Runtime: end_processing from invalid phase"
    in
    rt.phase <- next

  (* Report an exception caught at a callback site and swallow it so the dispatch
     loop continues (REQ-F1). The raw backtrace is captured on the handler's
     first line so a later [try] inside [on_error] cannot clobber it. *)
  let report rt label exn raw_bt =
    rt.on_error
      (Printf.sprintf "%s: %s\n%s" label (Printexc.to_string exn)
         (Printexc.raw_backtrace_to_string raw_bt))

  (* Run a unit-returning callback; report and swallow any exception. A graceful
     [Stdlib.Exit] ([exit n] raises it) is re-raised, not reported — the loop's
     error-reporting catch-all must not turn a handled exit into a spurious
     failure. *)
  let guard rt label f =
    try f () with
    | Stdlib.Exit as exn -> raise exn
    | exn ->
        let raw_bt = Printexc.get_raw_backtrace () in
        report rt label exn raw_bt

  (* Run a value-returning callback; on success [Some v], on exception report and
     return [None] so the caller can skip the dependent work. [Stdlib.Exit] is
     re-raised rather than reported (see {!guard}). *)
  let guard_opt rt label f =
    match f () with
    | v -> Some v
    | exception (Stdlib.Exit as exn) -> raise exn
    | exception exn ->
        let raw_bt = Printexc.get_raw_backtrace () in
        report rt label exn raw_bt;
        None

  (* Call graph for the dispatch loop (mutual recursion):
     dispatch -> process_queue -> drain -> execute_cmd -> dispatch (queued)
                               -> refresh -> dispatch (from sub setup, queued)
     process_queue uses a while loop to avoid stack growth when refresh
     dispatches messages that require another drain/refresh cycle. Every callback
     site (update, subscriptions, effect thunks, telemetry serialization) is
     individually guarded so a single poisoned message cannot drop the queue. *)
  (* Build the per-atom interpreter [Sub_manager.diff] calls, weaving the
     firing seam in: each message a subscription dispatches is preceded by
     [on_fire] with the atom's {!Nopal_mvu.Sub.describe_atom} label so telemetry
     records a [Subscription] event (inert on the plain runtime). [interpret]
     now owns dispatch, so this is where the seam lives — not inside
     [Sub_manager], which no longer sees the dispatch path. *)
  let rec interpret_for_diff rt atom =
    let label = Nopal_mvu.Sub.describe_atom atom in
    let recording_dispatch msg =
      rt.on_fire label;
      dispatch rt msg
    in
    rt.interpret_atom ~dispatch:recording_dispatch atom

  and refresh rt =
    let m = model rt in
    match guard_opt rt "subscriptions" (fun () -> A.subscriptions m) with
    | None -> ()
    | Some subs ->
        Sub_manager.diff ~on_error:rt.on_error
          ~interpret:(interpret_for_diff rt) subs rt.sub_mgr

  and drain rt =
    while not (Queue.is_empty rt.queue) do
      let msg = Queue.pop rt.queue in
      let m = model rt in
      (* Record the message before [update] so a raising [update] still leaves
         the dispatched message in the log (the harness dumps history on
         exception). The transition is only recorded once [update] returns.
         Both blocks are behind [rt.recording] so a plain runtime does no
         telemetry work here at all (REQ-N1). A raising serialiser is reported
         but does not block the message (REQ-F1). *)
      if rt.recording then
        guard rt "telemetry: serialize message" (fun () ->
            Telemetry.record_message rt.recorder msg ~serialize:rt.serialize_msg);
      match guard_opt rt "update" (fun () -> A.update m msg) with
      | None -> ()
      | Some (new_model, cmd) ->
          Lwd.set rt.model_var new_model;
          if rt.recording then (
            guard rt "telemetry: serialize transition" (fun () ->
                Telemetry.record_transition rt.recorder ~before:m
                  ~after:new_model ~serialize:rt.serialize_model);
            (* [Cmd.none] means no command was issued, so skip it — the log
               records only commands that do something, labelled by
               [Cmd.describe]'s stable output, which the [Command] event and
               fragment assertions rely on. A typed [Cmd.is_none] predicate
               avoids coupling the skip to the literal ["none"] label string. *)
            if not (Nopal_mvu.Cmd.is_none cmd) then
              guard rt "telemetry: describe command" (fun () ->
                  Telemetry.record_command rt.recorder
                    (Nopal_mvu.Cmd.describe cmd)));
          execute_cmd rt cmd
    done

  and process_queue rt =
    (* [Fun.protect] guarantees the phase resets to [Idle] even if an unguarded
       exception escapes the loop body, so a stray failure cannot wedge the
       runtime in [Processing] forever. *)
    Fun.protect
      ~finally:(fun () -> apply_move rt End_processing)
      (fun () ->
        let continue = ref true in
        while !continue do
          drain rt;
          refresh rt;
          if Queue.is_empty rt.queue then continue := false
        done)

  and dispatch rt msg =
    match rt.phase with
    | Created -> invalid_arg "Runtime: dispatch before start"
    | Shut_down ->
        (* REQ-F2: post-shutdown dispatch (including late Perform/Task
           completions) is dropped, not raised. *)
        rt.on_error "Runtime: dispatch after shutdown — message dropped"
    | Processing ->
        (* Already draining — enqueue; the running loop will pick it up. *)
        Queue.push msg rt.queue
    | Idle ->
        Queue.push msg rt.queue;
        apply_move rt Begin_processing;
        process_queue rt

  and execute_cmd rt cmd =
    (* Effect thunks run platform/user code; guard the interpret call so a
       raising perform/task/focus thunk is reported, not propagated (REQ-F1).
       Post-shutdown completions route back through [dispatch], which drops. *)
    guard rt "command effect" (fun () ->
        Nopal_mvu.Cmd.interpret ~focus:rt.focus
          ~dispatch:(fun msg -> dispatch rt msg)
          ~schedule_after:(fun ms msg ->
            rt.schedule_after ms (fun () -> dispatch rt msg))
          cmd)

  let start rt =
    apply_move rt Start;
    execute_cmd rt rt.init_cmd;
    (* This diff is not redundant with the one inside process_queue/refresh.
       If init_cmd is Cmd.none (the common case), no dispatch occurs, so
       process_queue never runs and refresh never fires. This explicit diff
       is the only thing that sets up initial subscriptions in that case.
       When init_cmd does dispatch, process_queue/refresh will have already
       diffed, making this call idempotent (Sub_manager skips known keys). *)
    let m = model rt in
    let subs = A.subscriptions m in
    Sub_manager.diff ~on_error:rt.on_error ~interpret:(interpret_for_diff rt)
      subs rt.sub_mgr

  let shutdown rt =
    apply_move rt Shutdown;
    Sub_manager.stop_all rt.sub_mgr

  let set_viewport rt vp =
    if Nopal_element.Viewport.equal (Lwd.peek rt.viewport_var) vp then ()
    else (
      Lwd.set rt.viewport_var vp;
      let m = model rt in
      let subs = A.subscriptions m in
      (* Viewport changes are delivered here, not through a platform listener
         (see [default_interpret_atom]), so dispatch every viewport atom's
         handler directly. *)
      List.iter
        (fun atom ->
          match atom with
          | Nopal_mvu.Sub.Viewport { handler; _ } -> dispatch rt (handler vp)
          | Every _
          | Keydown _
          | Keyup _
          | Resize _
          | Visibility _
          | Custom _ ->
              ())
        (Nopal_mvu.Sub.atoms subs))
end

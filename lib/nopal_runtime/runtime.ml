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
    mutable processing : bool;
        (* mutable: re-entrancy guard for dispatch loop —
           checked and toggled within a single synchronous call frame *)
    mutable lifecycle : lifecycle;
        (* mutable: monotonic state machine Created -> Running -> Shut_down.
           Checked on dispatch, start, and shutdown to enforce valid transitions. *)
  }

  let create ?(focus = fun _id -> ()) ?(schedule_after = fun _ms _f -> ()) () =
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
      processing = false;
      lifecycle = Created;
    }

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
    Sub_manager.diff ~dispatch:(fun msg -> dispatch rt msg) subs rt.sub_mgr

  and drain rt =
    while not (Queue.is_empty rt.queue) do
      let msg = Queue.pop rt.queue in
      let m = model rt in
      let new_model, cmd = A.update m msg in
      Lwd.set rt.model_var new_model;
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
    Sub_manager.diff ~dispatch:(fun msg -> dispatch rt msg) subs rt.sub_mgr

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

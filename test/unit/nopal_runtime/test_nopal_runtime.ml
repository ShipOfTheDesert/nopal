let sample_view rt view_fn =
  let root = Lwd.observe (view_fn rt) in
  let v = Lwd.quick_sample root in
  Lwd.quick_release root;
  v

let test_subscription_start_stop () =
  let setup_called = ref false in
  let cleanup_called = ref false in
  let mgr = Nopal_runtime.Sub_manager.create () in
  let make_sub active =
    if active then
      Nopal_mvu.Sub.custom "tick" (fun _dispatch ->
          setup_called := true;
          fun () -> cleanup_called := true)
    else Nopal_mvu.Sub.none
  in
  let dispatch _msg = () in
  Nopal_runtime.Sub_manager.diff ~dispatch (make_sub true) mgr;
  Alcotest.(check bool) "setup was called" true !setup_called;
  Alcotest.(check (list string))
    "tick is active" [ "tick" ]
    (Nopal_runtime.Sub_manager.active_keys mgr);
  Nopal_runtime.Sub_manager.diff ~dispatch (make_sub false) mgr;
  Alcotest.(check bool) "cleanup was called" true !cleanup_called;
  Alcotest.(check (list string))
    "no active subs" []
    (Nopal_runtime.Sub_manager.active_keys mgr)

let test_subscription_stability () =
  let setup_count = ref 0 in
  let mgr = Nopal_runtime.Sub_manager.create () in
  let sub =
    Nopal_mvu.Sub.custom "stable" (fun _dispatch ->
        incr setup_count;
        fun () -> ())
  in
  let dispatch _msg = () in
  Nopal_runtime.Sub_manager.diff ~dispatch sub mgr;
  Nopal_runtime.Sub_manager.diff ~dispatch sub mgr;
  Nopal_runtime.Sub_manager.diff ~dispatch sub mgr;
  Alcotest.(check int) "setup called exactly once" 1 !setup_count

(* --- Test App for Runtime tests --- *)

module Counter_app : Nopal_mvu.App.S with type model = int and type msg = int =
struct
  type model = int
  type msg = int

  let init () = (0, Nopal_mvu.Cmd.none)

  let update model msg =
    let new_model = model + msg in
    (new_model, Nopal_mvu.Cmd.none)

  let view _vp model = Nopal_element.Element.text (string_of_int model)
  let subscriptions _model = Nopal_mvu.Sub.none
end

module R = Nopal_runtime.Runtime.Make (Counter_app)

let test_init_sets_model_and_view () =
  let rt = R.create () in
  R.start rt;
  Alcotest.(check int) "initial model is 0" 0 (R.model rt);
  let v = sample_view rt R.view in
  Alcotest.(check bool)
    "initial view is Text \"0\"" true
    (Nopal_element.Element.equal v (Nopal_element.Element.text "0"))

let test_dispatch_updates_model () =
  let rt = R.create () in
  R.start rt;
  R.dispatch rt 5;
  Alcotest.(check int) "model after dispatch 5" 5 (R.model rt);
  R.dispatch rt 3;
  Alcotest.(check int) "model after dispatch 3" 8 (R.model rt);
  let v = sample_view rt R.view in
  Alcotest.(check bool)
    "view reflects model" true
    (Nopal_element.Element.equal v (Nopal_element.Element.text "8"))

let test_queued_dispatch_no_recursion () =
  (* App where update dispatches another message via Cmd.perform.
     Also asserts queue depth stays bounded to catch accidental infinite loops. *)
  let update_count = ref 0 in
  let max_depth = ref 0 in
  let current_depth = ref 0 in
  let module Reentrant_app :
    Nopal_mvu.App.S with type model = int and type msg = int = struct
    type model = int
    type msg = int

    let init () = (0, Nopal_mvu.Cmd.none)

    let update model msg =
      incr update_count;
      if !update_count > 100 then
        Alcotest.fail "update called >100 times — likely infinite loop";
      incr current_depth;
      if !current_depth > !max_depth then max_depth := !current_depth;
      let new_model = model + msg in
      let cmd =
        if msg = 10 then Nopal_mvu.Cmd.perform (fun dispatch -> dispatch 1)
        else Nopal_mvu.Cmd.none
      in
      decr current_depth;
      (new_model, cmd)

    let view _vp model = Nopal_element.Element.text (string_of_int model)
    let subscriptions _model = Nopal_mvu.Sub.none
  end in
  let module R2 = Nopal_runtime.Runtime.Make (Reentrant_app) in
  let rt = R2.create () in
  R2.start rt;
  R2.dispatch rt 10;
  Alcotest.(check int) "both updates ran" 2 !update_count;
  Alcotest.(check int) "max depth is 1 (no recursion)" 1 !max_depth;
  Alcotest.(check int) "final model is 11" 11 (R2.model rt)

let test_view_not_called_during_update () =
  (* REQ-F8: Dispatch a message whose Cmd.perform dispatches a second message.
     Both updates happen in one process_queue cycle. Verify that view is never
     called while update is in progress, and that view recomputes only once
     (batched) when sampled after the cycle completes. *)
  let view_count = ref 0 in
  let view_during_update = ref false in
  let in_update = ref false in
  let module View_spy_app :
    Nopal_mvu.App.S with type model = int and type msg = int = struct
    type model = int
    type msg = int

    let init () = (0, Nopal_mvu.Cmd.none)

    let update model msg =
      in_update := true;
      let cmd =
        if msg = 1 then Nopal_mvu.Cmd.perform (fun dispatch -> dispatch 2)
        else Nopal_mvu.Cmd.none
      in
      let result = (model + msg, cmd) in
      in_update := false;
      result

    let view _vp model =
      incr view_count;
      if !in_update then view_during_update := true;
      Nopal_element.Element.text (string_of_int model)

    let subscriptions _model = Nopal_mvu.Sub.none
  end in
  let module R3 = Nopal_runtime.Runtime.Make (View_spy_app) in
  let rt = R3.create () in
  R3.start rt;
  (* Reset view_count after init/start to isolate the dispatch cycle *)
  view_count := 0;
  R3.dispatch rt 1;
  Alcotest.(check bool)
    "view was never called during update" false !view_during_update;
  Alcotest.(check int) "model is 3 (1 + 2)" 3 (R3.model rt);
  (* Sample the Lwd graph — this triggers a single view recomputation *)
  let v = sample_view rt R3.view in
  Alcotest.(check bool)
    "view reflects final model" true
    (Nopal_element.Element.equal v (Nopal_element.Element.text "3"));
  Alcotest.(check int)
    "view called exactly once on sample (not per update)" 1 !view_count

let test_cmd_perform_and_task () =
  let perform_ran = ref false in
  let task_ran = ref false in
  let module Cmd_app :
    Nopal_mvu.App.S with type model = int and type msg = int = struct
    type model = int
    type msg = int

    let init () =
      ( 0,
        Nopal_mvu.Cmd.batch
          [
            Nopal_mvu.Cmd.perform (fun dispatch ->
                perform_ran := true;
                dispatch 10);
            Nopal_mvu.Cmd.task
              (Nopal_mvu.Task.from_callback (fun resolve ->
                   task_ran := true;
                   resolve 20));
          ] )

    let update model msg = (model + msg, Nopal_mvu.Cmd.none)
    let view _vp model = Nopal_element.Element.text (string_of_int model)
    let subscriptions _model = Nopal_mvu.Sub.none
  end in
  let module R4 = Nopal_runtime.Runtime.Make (Cmd_app) in
  let rt = R4.create () in
  R4.start rt;
  Alcotest.(check bool) "perform ran" true !perform_ran;
  Alcotest.(check bool) "task ran" true !task_ran;
  Alcotest.(check int) "final model is 30" 30 (R4.model rt)

let test_cmd_after_uses_scheduler () =
  let scheduled = ref [] in
  let schedule_after ms callback = scheduled := (ms, callback) :: !scheduled in
  let module After_app :
    Nopal_mvu.App.S with type model = int and type msg = int = struct
    type model = int
    type msg = int

    let init () = (0, Nopal_mvu.Cmd.after 500 99)
    let update _model msg = (msg, Nopal_mvu.Cmd.none)
    let view _vp model = Nopal_element.Element.text (string_of_int model)
    let subscriptions _model = Nopal_mvu.Sub.none
  end in
  let module R5 = Nopal_runtime.Runtime.Make (After_app) in
  let rt = R5.create ~schedule_after () in
  R5.start rt;
  Alcotest.(check int) "one item scheduled" 1 (List.length !scheduled);
  let ms, callback = List.hd !scheduled in
  Alcotest.(check int) "scheduled with 500ms" 500 ms;
  Alcotest.(check int) "model before callback" 0 (R5.model rt);
  callback ();
  Alcotest.(check int) "model after callback is 99" 99 (R5.model rt)

let test_cmd_after_rejected_after_shutdown () =
  let scheduled = ref [] in
  let schedule_after ms callback = scheduled := (ms, callback) :: !scheduled in
  let module After_shutdown_app :
    Nopal_mvu.App.S with type model = int and type msg = int = struct
    type model = int
    type msg = int

    let init () = (0, Nopal_mvu.Cmd.after 1000 42)
    let update _model msg = (msg, Nopal_mvu.Cmd.none)
    let view _vp model = Nopal_element.Element.text (string_of_int model)
    let subscriptions _model = Nopal_mvu.Sub.none
  end in
  let module R7 = Nopal_runtime.Runtime.Make (After_shutdown_app) in
  let rt = R7.create ~schedule_after () in
  R7.start rt;
  Alcotest.(check int) "one item scheduled" 1 (List.length !scheduled);
  let _ms, callback = List.hd !scheduled in
  R7.shutdown rt;
  Alcotest.(check int) "model before callback" 0 (R7.model rt);
  callback ();
  Alcotest.(check int)
    "model unchanged after post-shutdown callback" 0 (R7.model rt)

let test_subscription_dispatches_during_refresh () =
  let setup_count = ref 0 in
  let module Sub_dispatch_app :
    Nopal_mvu.App.S with type model = int and type msg = int = struct
    type model = int
    type msg = int

    let init () = (0, Nopal_mvu.Cmd.none)
    let update model msg = (model + msg, Nopal_mvu.Cmd.none)
    let view _vp model = Nopal_element.Element.text (string_of_int model)

    let subscriptions model =
      if model >= 0 then
        Nopal_mvu.Sub.custom "dispatch-on-setup" (fun dispatch ->
            incr setup_count;
            if !setup_count = 1 then dispatch 100;
            fun () -> ())
      else Nopal_mvu.Sub.none
  end in
  let module R8 = Nopal_runtime.Runtime.Make (Sub_dispatch_app) in
  let rt = R8.create () in
  R8.start rt;
  Alcotest.(check int) "setup called once during start" 1 !setup_count;
  Alcotest.(check int)
    "model reflects dispatched message from sub setup" 100 (R8.model rt);
  Alcotest.(check int) "setup not called again (stable key)" 1 !setup_count

let test_shutdown () =
  let cleanup_called = ref false in
  let module Shutdown_app :
    Nopal_mvu.App.S with type model = int and type msg = int = struct
    type model = int
    type msg = int

    let init () = (0, Nopal_mvu.Cmd.none)
    let update model msg = (model + msg, Nopal_mvu.Cmd.none)
    let view _vp model = Nopal_element.Element.text (string_of_int model)

    let subscriptions _model =
      Nopal_mvu.Sub.custom "alive" (fun _dispatch ->
          fun () -> cleanup_called := true)
  end in
  let module R6 = Nopal_runtime.Runtime.Make (Shutdown_app) in
  let rt = R6.create () in
  R6.start rt;
  Alcotest.(check bool)
    "subscription active before shutdown" false !cleanup_called;
  R6.shutdown rt;
  Alcotest.(check bool) "cleanup called after shutdown" true !cleanup_called;
  let raised =
    try
      R6.dispatch rt 1;
      false
    with
    | Invalid_argument _ -> true
  in
  Alcotest.(check bool)
    "dispatch after shutdown raises Invalid_argument" true raised

let test_view_equals_all_element_variants () =
  let module Variant_app :
    Nopal_mvu.App.S with type model = int and type msg = int = struct
    type model = int
    type msg = int

    let init () = (0, Nopal_mvu.Cmd.none)
    let update _model msg = (msg, Nopal_mvu.Cmd.none)

    let view _vp model =
      match model with
      | 0 -> Nopal_element.Element.text "hello"
      | 1 -> Nopal_element.Element.empty
      | 2 -> Nopal_element.Element.box [ Nopal_element.Element.text "child" ]
      | 3 ->
          Nopal_element.Element.row
            [ Nopal_element.Element.text "a"; Nopal_element.Element.text "b" ]
      | _ -> Nopal_element.Element.text "default"

    let subscriptions _model = Nopal_mvu.Sub.none
  end in
  let module RV = Nopal_runtime.Runtime.Make (Variant_app) in
  let rt = RV.create () in
  RV.start rt;
  let check_view msg expected_elem =
    RV.dispatch rt msg;
    let v = sample_view rt RV.view in
    Alcotest.(check bool)
      ("view matches for model=" ^ string_of_int msg)
      true
      (Nopal_element.Element.equal v expected_elem)
  in
  check_view 1 Nopal_element.Element.empty;
  check_view 2
    (Nopal_element.Element.box [ Nopal_element.Element.text "child" ]);
  check_view 3
    (Nopal_element.Element.row
       [ Nopal_element.Element.text "a"; Nopal_element.Element.text "b" ]);
  check_view 0 (Nopal_element.Element.text "hello")

let test_subscription_key_replacement () =
  let setup_a_count = ref 0 in
  let cleanup_a_called = ref false in
  let setup_b_count = ref 0 in
  let mgr = Nopal_runtime.Sub_manager.create () in
  let sub_a =
    Nopal_mvu.Sub.custom "shared-key" (fun _dispatch ->
        incr setup_a_count;
        fun () -> cleanup_a_called := true)
  in
  let sub_b =
    Nopal_mvu.Sub.custom "shared-key" (fun _dispatch ->
        incr setup_b_count;
        fun () -> ())
  in
  let dispatch _msg = () in
  Nopal_runtime.Sub_manager.diff ~dispatch sub_a mgr;
  Alcotest.(check int) "setup_a called once" 1 !setup_a_count;
  Alcotest.(check bool) "cleanup_a not yet called" false !cleanup_a_called;
  (* Same key — sub_manager should treat it as stable (not replaced) *)
  Nopal_runtime.Sub_manager.diff ~dispatch sub_b mgr;
  Alcotest.(check int) "setup_b never called (key stable)" 0 !setup_b_count;
  Alcotest.(check bool)
    "cleanup_a not called (key stable)" false !cleanup_a_called;
  Alcotest.(check (list string))
    "key still active" [ "shared-key" ]
    (Nopal_runtime.Sub_manager.active_keys mgr)

let test_dispatch_before_start_raises () =
  let rt = R.create () in
  let raised =
    try
      R.dispatch rt 1;
      false
    with
    | Invalid_argument _ -> true
  in
  Alcotest.(check bool)
    "dispatch before start raises Invalid_argument" true raised

let test_start_twice_raises () =
  let rt = R.create () in
  R.start rt;
  let raised =
    try
      R.start rt;
      false
    with
    | Invalid_argument _ -> true
  in
  Alcotest.(check bool) "start after start raises Invalid_argument" true raised

let test_shutdown_before_start_raises () =
  let rt = R.create () in
  let raised =
    try
      R.shutdown rt;
      false
    with
    | Invalid_argument _ -> true
  in
  Alcotest.(check bool)
    "shutdown before start raises Invalid_argument" true raised

let test_start_after_shutdown_raises () =
  let rt = R.create () in
  R.start rt;
  R.shutdown rt;
  let raised =
    try
      R.start rt;
      false
    with
    | Invalid_argument _ -> true
  in
  Alcotest.(check bool)
    "start after shutdown raises Invalid_argument" true raised

let () =
  Alcotest.run "nopal_runtime"
    [
      ( "Sub_manager",
        [
          Alcotest.test_case "start and stop" `Quick
            test_subscription_start_stop;
          Alcotest.test_case "stability" `Quick test_subscription_stability;
          Alcotest.test_case "key replacement" `Quick
            test_subscription_key_replacement;
        ] );
      ( "Runtime",
        [
          Alcotest.test_case "init sets model and view" `Quick
            test_init_sets_model_and_view;
          Alcotest.test_case "dispatch updates model" `Quick
            test_dispatch_updates_model;
          Alcotest.test_case "queued dispatch no recursion" `Quick
            test_queued_dispatch_no_recursion;
          Alcotest.test_case "view not called during update" `Quick
            test_view_not_called_during_update;
          Alcotest.test_case "view equals all element variants" `Quick
            test_view_equals_all_element_variants;
        ] );
      ( "Cmd",
        [
          Alcotest.test_case "perform and task" `Quick test_cmd_perform_and_task;
          Alcotest.test_case "after uses scheduler" `Quick
            test_cmd_after_uses_scheduler;
          Alcotest.test_case "after rejected after shutdown" `Quick
            test_cmd_after_rejected_after_shutdown;
        ] );
      ( "Subscriptions",
        [
          Alcotest.test_case "dispatch during refresh" `Quick
            test_subscription_dispatches_during_refresh;
        ] );
      ("Shutdown", [ Alcotest.test_case "shutdown" `Quick test_shutdown ]);
      ( "Lifecycle",
        [
          Alcotest.test_case "dispatch before start raises" `Quick
            test_dispatch_before_start_raises;
          Alcotest.test_case "start twice raises" `Quick test_start_twice_raises;
          Alcotest.test_case "shutdown before start raises" `Quick
            test_shutdown_before_start_raises;
          Alcotest.test_case "start after shutdown raises" `Quick
            test_start_after_shutdown_raises;
        ] );
    ]

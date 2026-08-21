(* RFC 0118 Task 2 — runtime lifecycle state machine & exception safety
   (REQ-F1, REQ-F2). Each test installs an [on_error] sink and asserts that a
   poisoned callback is reported and swallowed (the dispatch loop survives), or
   that a post-shutdown dispatch is dropped rather than raising. *)

(* Plain accumulating counter, reused where the app body is irrelevant. *)
module Counter : Nopal_mvu.App.S with type model = int and type msg = int =
struct
  type model = int
  type msg = int

  let init () = (0, Nopal_mvu.Cmd.none)
  let update model msg = (model + msg, Nopal_mvu.Cmd.none)
  let view _vp model = Nopal_element.Element.text (string_of_int model)
  let subscriptions _model = Nopal_mvu.Sub.none
end

module R_counter = Nopal_runtime.Runtime.Make (Counter)

(* REQ-F1: [update] raising on one message must not wedge the loop — a later
   message is still processed. *)
let test_update_raises_loop_continues () =
  let module App : Nopal_mvu.App.S with type model = int and type msg = int =
  struct
    type model = int
    type msg = int

    let init () = (0, Nopal_mvu.Cmd.none)

    let update model msg =
      if msg = 99 then failwith "poison update";
      (model + msg, Nopal_mvu.Cmd.none)

    let view _vp model = Nopal_element.Element.text (string_of_int model)
    let subscriptions _model = Nopal_mvu.Sub.none
  end in
  let module R = Nopal_runtime.Runtime.Make (App) in
  let errors = ref [] in
  let rt = R.create ~on_error:(fun e -> errors := e :: !errors) () in
  R.start rt;
  R.dispatch rt 99;
  (* poisoned message — must be swallowed *)
  R.dispatch rt 5;
  (* loop must still be alive *)
  Alcotest.(check int) "only the surviving message applied" 5 (R.model rt);
  Alcotest.(check bool) "the raising update was reported" true (!errors <> [])

(* REQ-F1: [subscriptions] raising during refresh must not wedge the loop. *)
let test_subscriptions_raises_loop_continues () =
  let module App : Nopal_mvu.App.S with type model = int and type msg = int =
  struct
    type model = int
    type msg = int

    let init () = (0, Nopal_mvu.Cmd.none)
    let update model msg = (model + msg, Nopal_mvu.Cmd.none)
    let view _vp model = Nopal_element.Element.text (string_of_int model)

    (* Raises once the model has advanced — keeps [start] (model 0) clean so the
       failure surfaces inside the dispatch loop's refresh, not at construction. *)
    let subscriptions model =
      if model > 0 then failwith "poison subscriptions" else Nopal_mvu.Sub.none
  end in
  let module R = Nopal_runtime.Runtime.Make (App) in
  let errors = ref [] in
  let rt = R.create ~on_error:(fun e -> errors := e :: !errors) () in
  R.start rt;
  R.dispatch rt 1;
  R.dispatch rt 1;
  Alcotest.(check int)
    "both messages applied despite raising subs" 2 (R.model rt);
  Alcotest.(check bool)
    "the subscription failure was reported" true (!errors <> [])

(* REQ-F1: a telemetry serializer raising must not block the message — the model
   transition still applies; only the recording of that event is lost. *)
let test_telemetry_serializer_raises_message_still_applied () =
  let errors = ref [] in
  let rt, _handle =
    R_counter.create_with_telemetry
      ~on_error:(fun e -> errors := e :: !errors)
      ~serialize_msg:(fun _msg -> failwith "poison serializer")
      ()
  in
  R_counter.start rt;
  R_counter.dispatch rt 7;
  Alcotest.(check int)
    "message applied despite serializer raising" 7 (R_counter.model rt);
  Alcotest.(check bool)
    "the serializer failure was reported" true (!errors <> [])

(* REQ-F1: a raising update is reported via [on_error] with a description. *)
let test_raising_update_reports_via_on_error () =
  let module App : Nopal_mvu.App.S with type model = int and type msg = int =
  struct
    type model = int
    type msg = int

    let init () = (0, Nopal_mvu.Cmd.none)
    let update _model _msg = failwith "kaboom"
    let view _vp model = Nopal_element.Element.text (string_of_int model)
    let subscriptions _model = Nopal_mvu.Sub.none
  end in
  let module R = Nopal_runtime.Runtime.Make (App) in
  let errors = ref [] in
  let rt = R.create ~on_error:(fun e -> errors := e :: !errors) () in
  R.start rt;
  R.dispatch rt 1;
  match !errors with
  | [ description ] ->
      Alcotest.(check bool)
        "report carries a non-empty description" true
        (String.length description > 0)
  | _ ->
      Alcotest.fail "expected exactly one on_error report from raising update"

(* REQ-F2: dispatch after shutdown drops the message and reports it — it does
   not raise (the historical behaviour). *)
let test_dispatch_after_shutdown_dropped_not_raised () =
  let errors = ref [] in
  let rt = R_counter.create ~on_error:(fun e -> errors := e :: !errors) () in
  R_counter.start rt;
  R_counter.shutdown rt;
  let raised =
    try
      R_counter.dispatch rt 5;
      false
    with
    | Invalid_argument _ -> true
  in
  Alcotest.(check bool) "dispatch after shutdown does not raise" false raised;
  Alcotest.(check int)
    "model unchanged by dropped dispatch" 0 (R_counter.model rt);
  Alcotest.(check bool) "the dropped dispatch was reported" true (!errors <> [])

(* REQ-F2: a Task that resolves after shutdown dispatches into a dead runtime —
   that late completion must drop, not raise. *)
let test_task_completion_after_shutdown_dropped_not_raised () =
  let pending_resolve = ref (fun (_ : int) -> ()) in
  let module App : Nopal_mvu.App.S with type model = int and type msg = int =
  struct
    type model = int
    type msg = int

    (* Capture the task's resolve callback (the runtime's dispatch) without
       firing it, so the test can complete the task after shutdown. *)
    let init () =
      ( 0,
        Nopal_mvu.Cmd.task
          (Nopal_mvu.Task.from_callback (fun resolve ->
               pending_resolve := resolve)) )

    let update model msg = (model + msg, Nopal_mvu.Cmd.none)
    let view _vp model = Nopal_element.Element.text (string_of_int model)
    let subscriptions _model = Nopal_mvu.Sub.none
  end in
  let module R = Nopal_runtime.Runtime.Make (App) in
  let errors = ref [] in
  let rt = R.create ~on_error:(fun e -> errors := e :: !errors) () in
  R.start rt;
  R.shutdown rt;
  let raised =
    try
      !pending_resolve 42;
      false
    with
    | Invalid_argument _ -> true
  in
  Alcotest.(check bool) "late task completion does not raise" false raised;
  Alcotest.(check int)
    "model unchanged by post-shutdown completion" 0 (R.model rt);
  Alcotest.(check bool) "the late completion was reported" true (!errors <> [])

(* ------------------------------------------------------------------ *)
(* The relative-scroll platform callback                                *)
(* ------------------------------------------------------------------ *)

(* One container id and one delta, shared by every case below so a mismatch is
   always about routing rather than about which fixture was used. *)
let pane_id = "reading-pane"
let requested = Nopal_element.Scroll_delta.viewports 0.5

(* The message whose update issues the request. Every other message is an
   ordinary model change, so the model reading is an independent witness that
   the dispatch happened at all. *)
let scroll_msg = 1

(* App whose update turns [scroll_msg] into a relative-scroll request. The
   request carries no message, so the only place it can become observable is a
   platform callback — which is precisely what these cases are about. *)
module Scroller : Nopal_mvu.App.S with type model = int and type msg = int =
struct
  type model = int
  type msg = int

  let init () = (0, Nopal_mvu.Cmd.none)

  let update model msg =
    let cmd =
      if msg = scroll_msg then Nopal_mvu.Cmd.scroll_by pane_id requested
      else Nopal_mvu.Cmd.none
    in
    (model + msg, cmd)

  let view _vp model = Nopal_element.Element.text (string_of_int model)
  let subscriptions _model = Nopal_mvu.Sub.none
end

module R_scroller = Nopal_runtime.Runtime.Make (Scroller)

(* Run one scrolling message through a runtime built with (or without) a
   platform callback, and hand back the model it reached and everything it
   reported. Reaching the caller at all is the no-raise witness: an exception
   escaping [start] or [dispatch] would fail the case before any assertion. *)
let drive ?scroll_by () =
  let errors = ref [] in
  let rt =
    R_scroller.create ?scroll_by ~on_error:(fun e -> errors := e :: !errors) ()
  in
  R_scroller.start rt;
  R_scroller.dispatch rt scroll_msg;
  (R_scroller.model rt, List.rev !errors)

let append sink id delta = sink := !sink @ [ (id, delta) ]

(* The constructor's default and an interpreter that quietly drops the request
   are indistinguishable from a single sink, because both produce nothing. Two
   runtimes with two sinks is what tells them apart: each request must land in
   the sink its own constructor was handed, and nowhere else. *)
let test_scroll_by_reaches_the_platform_callback () =
  let first = ref [] in
  let second = ref [] in
  let model_first, errors_first = drive ~scroll_by:(append first) () in
  Alcotest.check Scroll_request.requests
    "the request the update issued reached this runtime's own callback"
    [ (pane_id, requested) ]
    !first;
  Alcotest.(check (list string))
    "an honoured request reports nothing" [] errors_first;
  Alcotest.(check int)
    "the model advanced, so the dispatch really happened" scroll_msg model_first;
  let model_second, errors_second = drive ~scroll_by:(append second) () in
  Alcotest.check Scroll_request.requests
    "a second runtime routes to the callback it was given"
    [ (pane_id, requested) ]
    !second;
  Alcotest.check Scroll_request.requests
    "and not to the first runtime's, which saw nothing further"
    [ (pane_id, requested) ]
    !first;
  Alcotest.(check (list string))
    "the second runtime reported nothing either" [] errors_second;
  Alcotest.(check int) "and reached the same model" scroll_msg model_second

(* Absence arm plus its affirmative arm on the same app and the same message: a
   runtime given no callback has nowhere to route the request, which is inert
   rather than an error. The affirmative arm is what stops that silence from
   being caused by an update that issued nothing at all. *)
let test_absent_callback_is_a_no_op () =
  let model_absent, errors_absent = drive () in
  Alcotest.(check (list string))
    "an unroutable request is inert, not reported" [] errors_absent;
  Alcotest.(check int)
    "the model advanced despite there being nowhere to route the request"
    scroll_msg model_absent;
  let seen = ref [] in
  let model_present, errors_present = drive ~scroll_by:(append seen) () in
  Alcotest.check Scroll_request.requests
    "the very same dispatch does produce a request once a callback exists"
    [ (pane_id, requested) ]
    !seen;
  Alcotest.(check (list string)) "and still reports nothing" [] errors_present;
  Alcotest.(check int)
    "the model is identical whether or not the callback is there" model_present
    model_absent

let () =
  Alcotest.run "nopal_runtime_lifecycle"
    [
      ( "Exception safety",
        [
          Alcotest.test_case "update raises, loop continues" `Quick
            test_update_raises_loop_continues;
          Alcotest.test_case "subscriptions raises, loop continues" `Quick
            test_subscriptions_raises_loop_continues;
          Alcotest.test_case "telemetry serializer raises, message applied"
            `Quick test_telemetry_serializer_raises_message_still_applied;
          Alcotest.test_case "raising update reports via on_error" `Quick
            test_raising_update_reports_via_on_error;
        ] );
      ( "Shutdown-safe dispatch",
        [
          Alcotest.test_case "dispatch after shutdown dropped, not raised"
            `Quick test_dispatch_after_shutdown_dropped_not_raised;
          Alcotest.test_case
            "task completion after shutdown dropped, not raised" `Quick
            test_task_completion_after_shutdown_dropped_not_raised;
        ] );
      ( "Relative-scroll platform callback",
        [
          Alcotest.test_case "scroll_by reaches the platform callback" `Quick
            test_scroll_by_reaches_the_platform_callback;
          Alcotest.test_case "absent callback is a no-op" `Quick
            test_absent_callback_is_a_no_op;
        ] );
    ]

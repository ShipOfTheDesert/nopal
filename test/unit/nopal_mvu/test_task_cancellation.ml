open Nopal_mvu.Task

let result_testable = Alcotest.result Alcotest.int Alcotest.string

let test_cancel_before_resolve () =
  let resolver = ref (fun _ -> ()) in
  let task = from_callback (fun resolve -> resolver := resolve) in
  let token, cancellable_task = cancellable (fun _token -> task) in
  let result = ref None in
  run cancellable_task (fun x -> result := Some x);
  cancel token;
  !resolver 42;
  match !result with
  | Some v -> Alcotest.(check result_testable) "cancelled" (Error "cancelled") v
  | None -> Alcotest.fail "task did not resolve"

let test_cancel_after_resolve () =
  let resolver = ref (fun _ -> ()) in
  let task = from_callback (fun resolve -> resolver := resolve) in
  let token, cancellable_task = cancellable (fun _token -> task) in
  let result = ref None in
  run cancellable_task (fun x -> result := Some x);
  !resolver 42;
  cancel token;
  match !result with
  | Some v -> Alcotest.(check result_testable) "ok preserved" (Ok 42) v
  | None -> Alcotest.fail "task did not resolve"

let test_double_cancel () =
  let resolver = ref (fun _ -> ()) in
  let task = from_callback (fun resolve -> resolver := resolve) in
  let token, cancellable_task = cancellable (fun _token -> task) in
  let call_count = ref 0 in
  run cancellable_task (fun _x -> incr call_count);
  cancel token;
  cancel token;
  !resolver 42;
  Alcotest.(check int) "resolved exactly once" 1 !call_count

let test_no_cancel_succeeds () =
  let resolver = ref (fun _ -> ()) in
  let task = from_callback (fun resolve -> resolver := resolve) in
  let _token, cancellable_task = cancellable (fun _token -> task) in
  let result = ref None in
  run cancellable_task (fun x -> result := Some x);
  !resolver 42;
  match !result with
  | Some v -> Alcotest.(check result_testable) "ok" (Ok 42) v
  | None -> Alcotest.fail "task did not resolve"

let test_cancel_composed_task () =
  let resolver = ref (fun _ -> ()) in
  let task = from_callback (fun resolve -> resolver := resolve) in
  let mapped_task = map (fun x -> x * 2) task in
  let token, cancellable_task = cancellable (fun _token -> mapped_task) in
  let result = ref None in
  run cancellable_task (fun x -> result := Some x);
  cancel token;
  !resolver 42;
  match !result with
  | Some v -> Alcotest.(check result_testable) "cancelled" (Error "cancelled") v
  | None -> Alcotest.fail "task did not resolve"

let test_on_cancel_called () =
  let hook_called = ref false in
  let token, _cancellable_task =
    cancellable (fun token ->
        set_on_cancel token (fun () -> hook_called := true);
        from_callback (fun _resolve -> ()))
  in
  cancel token;
  Alcotest.(check bool) "hook called" true !hook_called

let test_on_cancel_not_called_without_cancel () =
  let resolver = ref (fun _ -> ()) in
  let hook_called = ref false in
  let _token, cancellable_task =
    cancellable (fun token ->
        set_on_cancel token (fun () -> hook_called := true);
        from_callback (fun resolve -> resolver := resolve))
  in
  let result = ref None in
  run cancellable_task (fun x -> result := Some x);
  !resolver 42;
  Alcotest.(check bool) "hook not called" false !hook_called;
  match !result with
  | Some v -> Alcotest.(check result_testable) "ok" (Ok 42) v
  | None -> Alcotest.fail "task did not resolve"

let test_on_cancel_fires_immediately_if_already_cancelled () =
  let hook_called = ref false in
  let token, _cancellable_task =
    cancellable (fun _token -> from_callback (fun _resolve -> ()))
  in
  cancel token;
  set_on_cancel token (fun () -> hook_called := true);
  Alcotest.(check bool) "hook called immediately" true !hook_called

let test_double_cancel_calls_hook_once () =
  let call_count = ref 0 in
  let token, _cancellable_task =
    cancellable (fun token ->
        set_on_cancel token (fun () -> incr call_count);
        from_callback (fun _resolve -> ()))
  in
  cancel token;
  cancel token;
  Alcotest.(check int) "hook called once" 1 !call_count

let test_cancel_before_run () =
  let resolver = ref (fun _ -> ()) in
  let task = from_callback (fun resolve -> resolver := resolve) in
  let token, cancellable_task = cancellable (fun _token -> task) in
  cancel token;
  let result = ref None in
  run cancellable_task (fun x -> result := Some x);
  !resolver 42;
  match !result with
  | Some v -> Alcotest.(check result_testable) "cancelled" (Error "cancelled") v
  | None -> Alcotest.fail "task did not resolve"

let () =
  Alcotest.run "Task cancellation"
    [
      ( "cancellation",
        [
          Alcotest.test_case "cancel before resolve" `Quick
            test_cancel_before_resolve;
          Alcotest.test_case "cancel after resolve" `Quick
            test_cancel_after_resolve;
          Alcotest.test_case "double cancel" `Quick test_double_cancel;
          Alcotest.test_case "no cancel succeeds" `Quick test_no_cancel_succeeds;
          Alcotest.test_case "cancel composed task" `Quick
            test_cancel_composed_task;
          Alcotest.test_case "cancel before run" `Quick test_cancel_before_run;
          Alcotest.test_case "on_cancel called on cancel" `Quick
            test_on_cancel_called;
          Alcotest.test_case "on_cancel not called without cancel" `Quick
            test_on_cancel_not_called_without_cancel;
          Alcotest.test_case
            "set_on_cancel fires immediately if already cancelled" `Quick
            test_on_cancel_fires_immediately_if_already_cancelled;
          Alcotest.test_case "double cancel calls hook once" `Quick
            test_double_cancel_calls_hook_once;
        ] );
    ]

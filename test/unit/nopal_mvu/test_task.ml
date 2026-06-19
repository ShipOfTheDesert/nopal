open Nopal_mvu.Task

let run_capture task =
  let result = ref None in
  run task (fun x -> result := Some x);
  match !result with
  | Some v -> v
  | None -> Alcotest.fail "task did not resolve"

let test_left_identity () =
  let f n = return (n * 2) in
  let x = 21 in
  let lhs = run_capture (bind f (return x)) in
  let rhs = run_capture (f x) in
  Alcotest.(check int) "left identity" lhs rhs

let test_right_identity () =
  let t = return 7 in
  let lhs = run_capture (bind return t) in
  let rhs = run_capture t in
  Alcotest.(check int) "right identity" lhs rhs

let test_associativity () =
  let t = return 2 in
  let f n = return (n + 10) in
  let g n = return (n * 3) in
  let lhs = run_capture (bind g (bind f t)) in
  let rhs = run_capture (bind (fun x -> bind g (f x)) t) in
  Alcotest.(check int) "associativity" lhs rhs

let test_from_callback_resolves () =
  let t = from_callback (fun resolve -> resolve 99) in
  let result = run_capture t in
  Alcotest.(check int) "from_callback resolves" 99 result

let test_from_callback_does_not_execute_until_run () =
  let executed = ref false in
  let _t =
    from_callback (fun resolve ->
        executed := true;
        resolve 42)
  in
  Alcotest.(check bool) "not executed before run" false !executed

let test_from_callback_bind_chain () =
  let t = from_callback (fun resolve -> resolve 10) in
  let chained = bind (fun n -> return (n + 5)) t in
  let result = run_capture chained in
  Alcotest.(check int) "from_callback bind chain" 15 result

let test_map_transforms_result () =
  let t = map (fun s -> String.length s) (return "hello") in
  let result = run_capture t in
  Alcotest.(check int) "map transforms result" 5 result

let test_syntax_let_star () =
  let open Syntax in
  let t =
    let* x = return 3 in
    let* y = return 4 in
    return (x + y)
  in
  let result = run_capture t in
  Alcotest.(check int) "let* sequences" 7 result

let test_guard_catches_synchronous_exception () =
  let t = guard ~on_exn:(fun _ -> "caught") (fun _resolve -> failwith "boom") in
  Alcotest.(check (result int string))
    "synchronous raise becomes Error" (Error "caught") (run_capture t)

let test_guard_maps_the_raised_exception () =
  let t =
    guard
      ~on_exn:(function
        | Failure m -> m
        | _ -> "other")
      (fun _resolve -> failwith "kaboom")
  in
  Alcotest.(check (result int string))
    "on_exn receives the raised exception" (Error "kaboom") (run_capture t)

let test_guard_passes_through_ok () =
  let t = guard ~on_exn:(fun _ -> "x") (fun resolve -> resolve (Ok 42)) in
  Alcotest.(check (result int string))
    "a normally-resolved Ok is untouched" (Ok 42) (run_capture t)

let test_guard_passes_through_error () =
  let t =
    guard
      ~on_exn:(fun _ -> "mapped")
      (fun resolve -> resolve (Error "original"))
  in
  Alcotest.(check (result int string))
    "an explicitly-resolved Error is untouched" (Error "original")
    (run_capture t)

let test_cancel_before_completion_delivers_cancelled_once () =
  (* Inner task never resolves; cancel must still deliver exactly one Cancelled,
     not depend on the aborted work ever completing. *)
  let token, wrapped =
    cancellable (fun _token -> (from_callback (fun _resolve -> ()) : int t))
  in
  let outcomes = ref [] in
  run wrapped (fun o -> outcomes := o :: !outcomes);
  cancel token;
  match !outcomes with
  | [ Cancelled ] -> ()
  | [] -> Alcotest.fail "cancel delivered no outcome"
  | _ -> Alcotest.fail "expected exactly one Cancelled outcome"

let test_cancel_then_late_inner_completion_is_dropped () =
  let saved = ref None in
  let token, wrapped =
    cancellable (fun _token ->
        from_callback (fun resolve -> saved := Some resolve))
  in
  let outcomes = ref [] in
  run wrapped (fun o -> outcomes := o :: !outcomes);
  cancel token;
  (match !saved with
  | Some resolve -> resolve 42
  | None -> Alcotest.fail "inner resolver was not captured");
  match !outcomes with
  | [ Cancelled ] -> ()
  | _ -> Alcotest.fail "late inner completion after cancel must be dropped"

let test_completion_then_cancel_delivers_only_completed () =
  let token, wrapped = cancellable (fun _token -> return 7) in
  let outcomes = ref [] in
  run wrapped (fun o -> outcomes := o :: !outcomes);
  cancel token;
  match !outcomes with
  | [ Completed 7 ] -> ()
  | _ -> Alcotest.fail "expected exactly one Completed 7"

let test_syntax_let_plus () =
  let open Syntax in
  let t =
    let+ x = return 10 in
    x * 2
  in
  let result = run_capture t in
  Alcotest.(check int) "let+ maps" 20 result

let () =
  Alcotest.run "Task"
    [
      ( "monad laws",
        [
          Alcotest.test_case "left identity" `Quick test_left_identity;
          Alcotest.test_case "right identity" `Quick test_right_identity;
          Alcotest.test_case "associativity" `Quick test_associativity;
        ] );
      ( "from_callback",
        [
          Alcotest.test_case "resolves" `Quick test_from_callback_resolves;
          Alcotest.test_case "lazy until run" `Quick
            test_from_callback_does_not_execute_until_run;
          Alcotest.test_case "bind chain" `Quick test_from_callback_bind_chain;
        ] );
      ( "combinators",
        [
          Alcotest.test_case "map transforms" `Quick test_map_transforms_result;
        ] );
      ( "guard",
        [
          Alcotest.test_case "catches synchronous exception" `Quick
            test_guard_catches_synchronous_exception;
          Alcotest.test_case "maps the raised exception" `Quick
            test_guard_maps_the_raised_exception;
          Alcotest.test_case "passes through Ok" `Quick
            test_guard_passes_through_ok;
          Alcotest.test_case "passes through Error" `Quick
            test_guard_passes_through_error;
        ] );
      ( "syntax",
        [
          Alcotest.test_case "let*" `Quick test_syntax_let_star;
          Alcotest.test_case "let+" `Quick test_syntax_let_plus;
        ] );
      ( "cancellation outcome",
        [
          Alcotest.test_case "cancel before completion delivers Cancelled once"
            `Quick test_cancel_before_completion_delivers_cancelled_once;
          Alcotest.test_case "cancel then late inner completion is dropped"
            `Quick test_cancel_then_late_inner_completion_is_dropped;
          Alcotest.test_case "completion then cancel delivers only Completed"
            `Quick test_completion_then_cancel_delivers_only_completed;
        ] );
    ]

(* Behavioural tests for [Task.guard_once].

   [Task.guard] is [try f resolve with e -> resolve (Error (on_exn e))], and the
   [resolve] its handler reaches is the one the task was run with. A body that
   latches its own resolver therefore latches only the deliveries it makes
   itself: the guard's handler still holds the unlatched one, so a body that
   delivers and then raises delivers twice. Every case below states the
   difference from the outside, through the number of outcomes a caller
   received, so nothing here depends on where the latch is written. *)

open Nopal_mvu.Task

(* Every outcome a task delivered, oldest first. A list rather than an option so
   two deliveries read differently from one, and none reads differently from
   both - which is the whole subject of this suite. *)
let deliveries task =
  let outcomes = ref [] in
  run task (fun outcome -> outcomes := outcome :: !outcomes);
  List.rev !outcomes

let outcome = Alcotest.(result int string)

exception Refused

(* The case [guard] fails. The body delivers, then raises; the guard catches the
   raise and would answer it with a second outcome, inventing a failure out of
   what the body already reported. *)
let test_resolve_then_raise_delivers_once () =
  let task =
    guard_once
      ~on_exn:(fun _ -> "the guard answered a raise")
      (fun resolve ->
        resolve (Ok 42);
        raise Refused)
  in
  Alcotest.(check (list outcome))
    "a body that delivers and then raises delivers only what it delivered"
    [ Ok 42 ] (deliveries task)

(* Delivering an outcome runs an application's update, which is arbitrary code.
   A raise from it must not become a second outcome, and must not escape the
   task either: an escaped exception leaves the caller with no way to tell the
   task ever ran. *)
let test_raising_delivery_is_absorbed () =
  let task =
    guard_once
      ~on_exn:(fun _ -> "the guard answered a raise")
      (fun resolve -> resolve (Ok 7))
  in
  let count = ref 0 in
  let escaped =
    match
      run task (fun _outcome ->
          incr count;
          raise Refused)
    with
    | () -> None
    | exception escaped -> Some escaped
  in
  Alcotest.(check int) "the outcome reached the caller exactly once" 1 !count;
  match escaped with
  | None -> ()
  | Some escaped ->
      Alcotest.failf "a raising delivery escaped the task: %s"
        (Printexc.to_string escaped)

(* A body with two delivery points that both fire - the shape a platform
   backend reaches when a continuation runs after its region already
   answered. *)
let test_second_explicit_resolve_is_dropped () =
  let task =
    guard_once
      ~on_exn:(fun _ -> "unused")
      (fun resolve ->
        resolve (Ok 1);
        resolve (Error "second"))
  in
  Alcotest.(check (list outcome))
    "the first outcome is the only one" [ Ok 1 ] (deliveries task)

(* A continuation that fires after the body returned, which is where every real
   asynchronous stage delivers from. The latch has to outlive the body for this
   to be dropped, not just outlive the guard. *)
let test_late_resolve_after_delivery_is_dropped () =
  let saved = ref None in
  let task =
    guard_once
      ~on_exn:(fun _ -> "unused")
      (fun resolve ->
        saved := Some resolve;
        resolve (Ok 5))
  in
  let outcomes = ref [] in
  run task (fun outcome -> outcomes := outcome :: !outcomes);
  (match !saved with
  | Some resolve -> resolve (Error "late")
  | None -> Alcotest.fail "the body's resolver was not captured");
  Alcotest.(check (list outcome))
    "a continuation firing after the first outcome delivers nothing" [ Ok 5 ]
    (List.rev !outcomes)

(* A body that never delivered still gets its raise turned into an outcome:
   the latch must not consume the guard's answer, only a redundant one. *)
let test_raise_before_any_delivery_is_reported () =
  let task =
    guard_once ~on_exn:(fun _ -> "caught") (fun _resolve -> raise Refused)
  in
  Alcotest.(check (list outcome))
    "a raise with nothing delivered yet is the outcome" [ Error "caught" ]
    (deliveries task)

let test_on_exn_receives_the_raised_exception () =
  let task =
    guard_once
      ~on_exn:(function
        | Failure m -> m
        | _ -> "other")
      (fun _resolve -> failwith "kaboom")
  in
  Alcotest.(check (list outcome))
    "on_exn sees the exception that was raised" [ Error "kaboom" ]
    (deliveries task)

let test_passes_through_ok () =
  let task =
    guard_once ~on_exn:(fun _ -> "x") (fun resolve -> resolve (Ok 42))
  in
  Alcotest.(check (list outcome))
    "a normally-delivered Ok is untouched" [ Ok 42 ] (deliveries task)

let test_passes_through_error () =
  let task =
    guard_once
      ~on_exn:(fun _ -> "mapped")
      (fun resolve -> resolve (Error "original"))
  in
  Alcotest.(check (list outcome))
    "an explicitly-delivered Error is untouched" [ Error "original" ]
    (deliveries task)

(* Nothing runs until the task is run, as for every other task constructor. *)
let test_body_is_lazy_until_run () =
  let entered = ref false in
  let _task =
    guard_once
      ~on_exn:(fun _ -> "unused")
      (fun resolve ->
        entered := true;
        resolve (Ok 0))
  in
  Alcotest.(check bool)
    "the body did not run when the task was built" false !entered

(* Two runs of the same task are two independent operations, so a latch shared
   between them would silence the second. *)
let test_each_run_has_its_own_latch () =
  let task =
    guard_once ~on_exn:(fun _ -> "x") (fun resolve -> resolve (Ok 3))
  in
  Alcotest.(check (list outcome))
    "the first run delivers" [ Ok 3 ] (deliveries task);
  Alcotest.(check (list outcome))
    "a second run of the same task delivers too" [ Ok 3 ] (deliveries task)

let () =
  Alcotest.run "Task.guard_once"
    [
      ( "delivers at most once",
        [
          Alcotest.test_case "a body that delivers then raises delivers once"
            `Quick test_resolve_then_raise_delivers_once;
          Alcotest.test_case "a raising delivery is absorbed" `Quick
            test_raising_delivery_is_absorbed;
          Alcotest.test_case "a second explicit delivery is dropped" `Quick
            test_second_explicit_resolve_is_dropped;
          Alcotest.test_case "a late delivery is dropped" `Quick
            test_late_resolve_after_delivery_is_dropped;
        ] );
      ( "guard behaviour is preserved",
        [
          Alcotest.test_case "a raise with nothing delivered is reported" `Quick
            test_raise_before_any_delivery_is_reported;
          Alcotest.test_case "on_exn receives the raised exception" `Quick
            test_on_exn_receives_the_raised_exception;
          Alcotest.test_case "passes through Ok" `Quick test_passes_through_ok;
          Alcotest.test_case "passes through Error" `Quick
            test_passes_through_error;
          Alcotest.test_case "the body is lazy until run" `Quick
            test_body_is_lazy_until_run;
          Alcotest.test_case "each run has its own latch" `Quick
            test_each_run_has_its_own_latch;
        ] );
    ]

(* Behavioural tests for the one-shot wrapper the pipeline frees its decoded
   image through.

   The pipeline reaches that action from two places - the successful exit and
   the failure exit of the region surrounding it - and both fire when a delivery
   raises. What is under test is that the second arrival changes nothing, and
   that the first still happens in full. *)

module Once = Nopal_image_web_internal.Once

let test_runs_the_first_call () =
  let seen = ref [] in
  let record = Once.wrap (fun value -> seen := value :: !seen) in
  record "first";
  Alcotest.(check (list string))
    "the first call reaches the wrapped action" [ "first" ] !seen

let test_drops_every_later_call () =
  let seen = ref [] in
  let record = Once.wrap (fun value -> seen := value :: !seen) in
  record "first";
  record "second";
  record "third";
  Alcotest.(check (list string))
    "only the first argument reached the wrapped action" [ "first" ] !seen

(* The pipeline's action releases a decoded image and then delivers an outcome,
   and delivering runs arbitrary application code. If that raises after the
   release, the surrounding region calls the action again with a failure - and
   a wrapper that only marked itself afterwards would release a second time. *)
let test_marks_before_running_so_a_raise_does_not_rearm () =
  let runs = ref 0 in
  let action =
    Once.wrap (fun () ->
        incr runs;
        failwith "the wrapped action raised")
  in
  (match action () with
  | () -> Alcotest.fail "expected the wrapped action's raise to propagate"
  | exception Failure _ -> ());
  action ();
  Alcotest.(check int) "the raising action ran exactly once" 1 !runs

(* Two wrapped actions are two independent latches: one pipeline run finishing
   must not silence the next. *)
let test_each_wrap_has_its_own_latch () =
  let runs = ref 0 in
  let first = Once.wrap (fun () -> incr runs) in
  let second = Once.wrap (fun () -> incr runs) in
  first ();
  first ();
  second ();
  second ();
  Alcotest.(check int) "each wrapper ran its action once" 2 !runs

let tests =
  [
    Alcotest.test_case "the first call runs" `Quick test_runs_the_first_call;
    Alcotest.test_case "later calls are dropped" `Quick
      test_drops_every_later_call;
    Alcotest.test_case "a raising action does not rearm" `Quick
      test_marks_before_running_so_a_raise_does_not_rearm;
    Alcotest.test_case "each wrapper latches independently" `Quick
      test_each_wrap_has_its_own_latch;
  ]

let () = Alcotest.run "Once" [ ("Once", tests) ]

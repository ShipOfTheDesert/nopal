let test_cmd_none_is_unit () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  Nopal_mvu.Cmd.execute dispatch Nopal_mvu.Cmd.none;
  Alcotest.(check (list int)) "none dispatches nothing" [] !results

let test_cmd_batch_flattens () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  let a = Nopal_mvu.Cmd.perform (fun d -> d 1) in
  let b = Nopal_mvu.Cmd.perform (fun d -> d 2) in
  let c = Nopal_mvu.Cmd.perform (fun d -> d 3) in
  let cmd = Nopal_mvu.Cmd.batch [ Nopal_mvu.Cmd.batch [ a; b ]; c ] in
  Nopal_mvu.Cmd.execute dispatch cmd;
  Alcotest.(check (list int)) "batch flattens" [ 3; 2; 1 ] !results

let test_cmd_batch_empty () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  Nopal_mvu.Cmd.execute dispatch (Nopal_mvu.Cmd.batch []);
  Alcotest.(check (list int)) "batch [] like none" [] !results

let test_cmd_perform_dispatches () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  let cmd = Nopal_mvu.Cmd.perform (fun d -> d 42) in
  Nopal_mvu.Cmd.execute dispatch cmd;
  Alcotest.(check (list int)) "perform dispatches" [ 42 ] !results

let test_cmd_task_dispatches () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  let cmd = Nopal_mvu.Cmd.task (Nopal_mvu.Task.return 99) in
  Nopal_mvu.Cmd.execute dispatch cmd;
  Alcotest.(check (list int)) "task dispatches" [ 99 ] !results

let test_cmd_after_records_delay () =
  match Nopal_mvu.Cmd.extract_after (Nopal_mvu.Cmd.after 100 "tick") with
  | Some (ms, msg) ->
      Alcotest.(check int) "delay is 100" 100 ms;
      Alcotest.(check string) "msg is tick" "tick" msg
  | None -> Alcotest.fail "expected Some from extract_after"

let test_cmd_map_transforms () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  let cmd = Nopal_mvu.Cmd.perform (fun d -> d 10) in
  let mapped = Nopal_mvu.Cmd.map (fun n -> n * 2) cmd in
  Nopal_mvu.Cmd.execute dispatch mapped;
  Alcotest.(check (list int)) "map transforms" [ 20 ] !results

let test_cmd_after_returns_none_for_non_after () =
  Alcotest.(check bool)
    "extract_after on none returns None" true
    (Option.is_none (Nopal_mvu.Cmd.extract_after Nopal_mvu.Cmd.none))

let test_cmd_map_task () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  let cmd = Nopal_mvu.Cmd.task (Nopal_mvu.Task.return 5) in
  let mapped = Nopal_mvu.Cmd.map (fun n -> n + 100) cmd in
  Nopal_mvu.Cmd.execute dispatch mapped;
  Alcotest.(check (list int)) "map transforms task" [ 105 ] !results

let test_cmd_map_after () =
  match
    Nopal_mvu.Cmd.extract_after
      (Nopal_mvu.Cmd.map (fun n -> n * 3) (Nopal_mvu.Cmd.after 200 7))
  with
  | Some (ms, msg) ->
      Alcotest.(check int) "delay preserved" 200 ms;
      Alcotest.(check int) "msg mapped" 21 msg
  | None -> Alcotest.fail "expected Some from extract_after on mapped after"

let test_cmd_map_batch () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  let cmd =
    Nopal_mvu.Cmd.batch
      [
        Nopal_mvu.Cmd.perform (fun d -> d 1);
        Nopal_mvu.Cmd.perform (fun d -> d 2);
      ]
  in
  let mapped = Nopal_mvu.Cmd.map (fun n -> n * 10) cmd in
  Nopal_mvu.Cmd.execute dispatch mapped;
  Alcotest.(check (list int)) "map transforms batch" [ 20; 10 ] !results

let test_cmd_execute_after_is_noop () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  Nopal_mvu.Cmd.execute dispatch (Nopal_mvu.Cmd.after 100 "tick");
  Alcotest.(check (list string)) "execute on after is no-op" [] !results

(* cmd_is_opaque: REQ-F16 is enforced at compile time by cmd.mli.
   User code cannot pattern-match on Cmd.t because the type is abstract. *)

let test_cmd_map_none () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  let mapped = Nopal_mvu.Cmd.map (fun n -> n * 2) Nopal_mvu.Cmd.none in
  Nopal_mvu.Cmd.execute dispatch mapped;
  Alcotest.(check (list int)) "map none dispatches nothing" [] !results

let test_cmd_interpret_single_pass () =
  let dispatched = ref [] in
  let scheduled = ref [] in
  let cmd =
    Nopal_mvu.Cmd.batch
      [
        Nopal_mvu.Cmd.perform (fun d -> d "hello");
        Nopal_mvu.Cmd.after 300 "delayed";
        Nopal_mvu.Cmd.task (Nopal_mvu.Task.return "async");
        Nopal_mvu.Cmd.none;
      ]
  in
  Nopal_mvu.Cmd.interpret
    ~dispatch:(fun msg -> dispatched := msg :: !dispatched)
    ~schedule_after:(fun ms msg -> scheduled := (ms, msg) :: !scheduled)
    cmd;
  Alcotest.(check (list string))
    "dispatched perform and task" [ "async"; "hello" ] !dispatched;
  Alcotest.(check (list (pair int string)))
    "scheduled after"
    [ (300, "delayed") ]
    !scheduled

let test_cmd_batch_deep_nesting () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  let a = Nopal_mvu.Cmd.perform (fun d -> d 1) in
  let cmd =
    Nopal_mvu.Cmd.batch [ Nopal_mvu.Cmd.batch [ Nopal_mvu.Cmd.batch [ a ] ] ]
  in
  Nopal_mvu.Cmd.execute dispatch cmd;
  Alcotest.(check (list int)) "deep nesting executes" [ 1 ] !results

let test_cmd_map_transforms_task () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  let cmd = Nopal_mvu.Cmd.task (Nopal_mvu.Task.return 10) in
  let mapped = Nopal_mvu.Cmd.map (fun n -> n * 2) cmd in
  Nopal_mvu.Cmd.execute dispatch mapped;
  Alcotest.(check (list int)) "map transforms task" [ 20 ] !results

let () =
  Alcotest.run "nopal_mvu_cmd"
    [
      ( "Cmd",
        [
          Alcotest.test_case "none is unit" `Quick test_cmd_none_is_unit;
          Alcotest.test_case "batch flattens" `Quick test_cmd_batch_flattens;
          Alcotest.test_case "batch empty" `Quick test_cmd_batch_empty;
          Alcotest.test_case "perform dispatches" `Quick
            test_cmd_perform_dispatches;
          Alcotest.test_case "task dispatches" `Quick test_cmd_task_dispatches;
          Alcotest.test_case "after records delay" `Quick
            test_cmd_after_records_delay;
          Alcotest.test_case "after returns none for non-after" `Quick
            test_cmd_after_returns_none_for_non_after;
          Alcotest.test_case "map transforms" `Quick test_cmd_map_transforms;
          Alcotest.test_case "map task" `Quick test_cmd_map_task;
          Alcotest.test_case "map after" `Quick test_cmd_map_after;
          Alcotest.test_case "map batch" `Quick test_cmd_map_batch;
          Alcotest.test_case "execute after is no-op" `Quick
            test_cmd_execute_after_is_noop;
          Alcotest.test_case "map none" `Quick test_cmd_map_none;
          Alcotest.test_case "batch deep nesting" `Quick
            test_cmd_batch_deep_nesting;
          Alcotest.test_case "interpret single pass" `Quick
            test_cmd_interpret_single_pass;
          Alcotest.test_case "map transforms task" `Quick
            test_cmd_map_transforms_task;
        ] );
    ]

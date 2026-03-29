let test_focus_extract () =
  let cmd = Nopal_mvu.Cmd.focus "x" in
  Alcotest.(check (option string))
    "extracts id" (Some "x")
    (Nopal_mvu.Cmd.extract_focus cmd)

let test_focus_extract_from_batch () =
  let cmd =
    Nopal_mvu.Cmd.batch
      [ Nopal_mvu.Cmd.focus "a"; Nopal_mvu.Cmd.none; Nopal_mvu.Cmd.focus "b" ]
  in
  Alcotest.(check (list string))
    "extracts all focus ids" [ "a"; "b" ]
    (Nopal_mvu.Cmd.extract_focuses cmd)

let test_focus_map_preserves_id () =
  let cmd = Nopal_mvu.Cmd.map (fun _ -> 42) (Nopal_mvu.Cmd.focus "x") in
  Alcotest.(check (option string))
    "map preserves focus id" (Some "x")
    (Nopal_mvu.Cmd.extract_focus cmd)

let test_focus_interpret_calls_callback () =
  let recorded = ref [] in
  Nopal_mvu.Cmd.interpret
    ~focus:(fun id -> recorded := id :: !recorded)
    ~dispatch:ignore
    ~schedule_after:(fun _ _ -> ())
    (Nopal_mvu.Cmd.focus "target");
  Alcotest.(check (list string))
    "interpret calls focus callback" [ "target" ] !recorded

let test_focus_execute_ignores () =
  Nopal_mvu.Cmd.execute ignore (Nopal_mvu.Cmd.focus "x");
  Alcotest.(check unit) "execute does not raise" () ()

let () =
  Alcotest.run "cmd_focus"
    [
      ( "Cmd.focus",
        [
          Alcotest.test_case "extract" `Quick test_focus_extract;
          Alcotest.test_case "extract from batch" `Quick
            test_focus_extract_from_batch;
          Alcotest.test_case "map preserves id" `Quick
            test_focus_map_preserves_id;
          Alcotest.test_case "interpret calls callback" `Quick
            test_focus_interpret_calls_callback;
          Alcotest.test_case "execute ignores" `Quick test_focus_execute_ignores;
        ] );
    ]

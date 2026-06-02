open Nopal_mvu

let cmds_with_labels =
  [
    (Cmd.none, "none");
    (Cmd.batch [], "batch");
    (Cmd.perform (fun _dispatch -> ()), "perform");
    (Cmd.task (Task.return 0), "task");
    (Cmd.after 100 0, "after");
    (Cmd.focus "id", "focus");
  ]

let test_cmd_describe_labels () =
  List.iter
    (fun (cmd, expected) ->
      Alcotest.(check string)
        (Printf.sprintf "describe = %s" expected)
        expected (Cmd.describe cmd))
    cmds_with_labels

let test_cmd_describe_labels_distinct () =
  let labels = List.map snd cmds_with_labels in
  let unique = List.sort_uniq String.compare labels in
  Alcotest.(check int)
    "every constructor has a distinct label" (List.length labels)
    (List.length unique)

let () =
  Alcotest.run "cmd_describe"
    [
      ( "describe",
        [
          Alcotest.test_case "labels per constructor" `Quick
            test_cmd_describe_labels;
          Alcotest.test_case "labels distinct" `Quick
            test_cmd_describe_labels_distinct;
        ] );
    ]

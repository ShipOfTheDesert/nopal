open Nopal_mvu

let cmds_with_labels =
  [
    (Cmd.none, "none");
    (Cmd.batch [], "batch");
    (Cmd.perform (fun _dispatch -> ()), "perform");
    (Cmd.task (Task.return 0), "task");
    (Cmd.after 100 0, "after");
    (Cmd.focus "id", "focus");
    (Cmd.scroll_by "id" (Nopal_element.Scroll_delta.viewports 0.5), "scroll_by");
  ]

(* The label is the only name the telemetry mirror — and therefore the browser
   suites reading it — sees for this command, so a rename here is a wire break
   and gets an assertion of its own rather than only a row in the table above. *)
let test_cmd_describe_labels_scroll_by () =
  Alcotest.(check string)
    "relative-scroll requests describe as scroll_by" "scroll_by"
    (Cmd.describe
       (Cmd.scroll_by "pane" (Nopal_element.Scroll_delta.viewports (-0.5))))

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
          Alcotest.test_case "labels scroll_by" `Quick
            test_cmd_describe_labels_scroll_by;
        ] );
    ]

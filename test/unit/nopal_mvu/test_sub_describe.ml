open Nopal_mvu

let subs_with_labels =
  [
    (Sub.none, "none");
    (Sub.batch [], "batch");
    (Sub.every "k" 100 (fun () -> 0), "every");
    (Sub.on_keydown "k" (fun _key -> 0), "on_keydown");
    (Sub.on_keyup "k" (fun _key -> 0), "on_keyup");
    (Sub.on_resize "k" (fun _w _h -> 0), "on_resize");
    (Sub.on_visibility_change "k" (fun _visible -> 0), "on_visibility_change");
    (Sub.on_viewport_change "k" (fun _vp -> 0), "on_viewport_change");
    ( Sub.on_keydown_prevent "k" (fun _key -> Some (0, true)),
      "on_keydown_prevent" );
    (Sub.custom "k" (fun _dispatch -> fun () -> ()), "custom");
  ]

let test_sub_describe_labels () =
  List.iter
    (fun (sub, expected) ->
      Alcotest.(check string)
        (Printf.sprintf "describe = %s" expected)
        expected (Sub.describe sub))
    subs_with_labels

let test_sub_describe_labels_distinct () =
  let labels = List.map snd subs_with_labels in
  let unique = List.sort_uniq String.compare labels in
  Alcotest.(check int)
    "every constructor has a distinct label" (List.length labels)
    (List.length unique)

let () =
  Alcotest.run "sub_describe"
    [
      ( "describe",
        [
          Alcotest.test_case "labels per constructor" `Quick
            test_sub_describe_labels;
          Alcotest.test_case "labels distinct" `Quick
            test_sub_describe_labels_distinct;
        ] );
    ]

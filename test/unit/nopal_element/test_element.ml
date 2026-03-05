let test_element_empty_constructs () =
  let el = Nopal_element.Element.Empty in
  Alcotest.(check bool)
    "Empty constructs" true
    (match el with
    | Nopal_element.Element.Empty -> true
    | Nopal_element.Element.Text _ -> false)

let test_element_text_constructs () =
  let el = Nopal_element.Element.Text "hello" in
  Alcotest.(check string)
    "Text holds value" "hello"
    (match el with
    | Nopal_element.Element.Text s -> s
    | Nopal_element.Element.Empty -> "")

let () =
  Alcotest.run "nopal_element"
    [
      ( "Element",
        [
          Alcotest.test_case "empty constructs" `Quick
            test_element_empty_constructs;
          Alcotest.test_case "text constructs" `Quick
            test_element_text_constructs;
        ] );
    ]

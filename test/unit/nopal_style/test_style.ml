let test_style_empty_equal () =
  Alcotest.(check bool)
    "two empty styles are equal" true
    (Nopal_style.Style.equal Nopal_style.Style.empty Nopal_style.Style.empty)

let () =
  Alcotest.run "nopal_style"
    [
      ( "Style",
        [ Alcotest.test_case "empty equal" `Quick test_style_empty_equal ] );
    ]

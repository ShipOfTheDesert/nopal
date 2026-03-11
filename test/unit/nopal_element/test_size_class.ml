let test_compact_below_600 () =
  let open Nopal_element.Size_class in
  Alcotest.(check bool) "0 is Compact" true (equal (of_width 0) Compact);
  Alcotest.(check bool) "375 is Compact" true (equal (of_width 375) Compact);
  Alcotest.(check bool) "599 is Compact" true (equal (of_width 599) Compact)

let test_medium_600_to_839 () =
  let open Nopal_element.Size_class in
  Alcotest.(check bool) "600 is Medium" true (equal (of_width 600) Medium);
  Alcotest.(check bool) "768 is Medium" true (equal (of_width 768) Medium);
  Alcotest.(check bool) "839 is Medium" true (equal (of_width 839) Medium)

let test_expanded_840_and_above () =
  let open Nopal_element.Size_class in
  Alcotest.(check bool) "840 is Expanded" true (equal (of_width 840) Expanded);
  Alcotest.(check bool) "1440 is Expanded" true (equal (of_width 1440) Expanded);
  Alcotest.(check bool) "2560 is Expanded" true (equal (of_width 2560) Expanded)

let test_equal_same () =
  let open Nopal_element.Size_class in
  Alcotest.(check bool) "Compact = Compact" true (equal Compact Compact);
  Alcotest.(check bool) "Medium = Medium" true (equal Medium Medium);
  Alcotest.(check bool) "Expanded = Expanded" true (equal Expanded Expanded)

let test_equal_different () =
  let open Nopal_element.Size_class in
  Alcotest.(check bool) "Compact <> Medium" false (equal Compact Medium);
  Alcotest.(check bool) "Medium <> Expanded" false (equal Medium Expanded);
  Alcotest.(check bool) "Compact <> Expanded" false (equal Compact Expanded)

let () =
  Alcotest.run "Size_class"
    [
      ( "of_width",
        [
          Alcotest.test_case "compact below 600" `Quick test_compact_below_600;
          Alcotest.test_case "medium 600 to 839" `Quick test_medium_600_to_839;
          Alcotest.test_case "expanded 840 and above" `Quick
            test_expanded_840_and_above;
        ] );
      ( "equal",
        [
          Alcotest.test_case "same" `Quick test_equal_same;
          Alcotest.test_case "different" `Quick test_equal_different;
        ] );
    ]

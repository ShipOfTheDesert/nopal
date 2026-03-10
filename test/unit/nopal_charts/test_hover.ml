open Nopal_charts

let test_equal_same () =
  let h = { Hover.index = 0; series = 0; cursor_x = 10.0; cursor_y = 20.0 } in
  Alcotest.(check bool) "same hover is equal" true (Hover.equal h h)

let test_equal_different_index () =
  let a = { Hover.index = 0; series = 0; cursor_x = 10.0; cursor_y = 20.0 } in
  let b = { Hover.index = 1; series = 0; cursor_x = 10.0; cursor_y = 20.0 } in
  Alcotest.(check bool) "different index not equal" false (Hover.equal a b)

let test_equal_different_series () =
  let a = { Hover.index = 0; series = 0; cursor_x = 10.0; cursor_y = 20.0 } in
  let b = { Hover.index = 0; series = 1; cursor_x = 10.0; cursor_y = 20.0 } in
  Alcotest.(check bool) "different series not equal" false (Hover.equal a b)

let test_equal_different_cursor () =
  let a = { Hover.index = 0; series = 0; cursor_x = 10.0; cursor_y = 20.0 } in
  let b = { Hover.index = 0; series = 0; cursor_x = 30.0; cursor_y = 40.0 } in
  Alcotest.(check bool) "different cursor not equal" false (Hover.equal a b)

let () =
  Alcotest.run "Hover"
    [
      ( "hover",
        [
          Alcotest.test_case "equal same" `Quick test_equal_same;
          Alcotest.test_case "equal different index" `Quick
            test_equal_different_index;
          Alcotest.test_case "equal different series" `Quick
            test_equal_different_series;
          Alcotest.test_case "equal different cursor" `Quick
            test_equal_different_cursor;
        ] );
    ]

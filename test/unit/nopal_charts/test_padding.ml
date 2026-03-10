open Nopal_charts

let test_default_values () =
  let d = Padding.default in
  Alcotest.(check (float 0.001)) "top is 40" 40.0 d.Padding.top;
  Alcotest.(check (float 0.001)) "right is 20" 20.0 d.Padding.right;
  Alcotest.(check (float 0.001)) "bottom is 40" 40.0 d.Padding.bottom;
  Alcotest.(check (float 0.001)) "left is 50" 50.0 d.Padding.left

let test_equal_same () =
  let p = Padding.default in
  Alcotest.(check bool) "same padding is equal" true (Padding.equal p p)

let test_equal_different () =
  let a = Padding.default in
  let b = { Padding.top = 10.0; right = 10.0; bottom = 10.0; left = 10.0 } in
  Alcotest.(check bool) "different padding not equal" false (Padding.equal a b)

let () =
  Alcotest.run "Padding"
    [
      ( "padding",
        [
          Alcotest.test_case "default values" `Quick test_default_values;
          Alcotest.test_case "equal same" `Quick test_equal_same;
          Alcotest.test_case "equal different" `Quick test_equal_different;
        ] );
    ]

open Nopal_draw

let test_apply_min () =
  let s = Scale.create ~domain:(0.0, 100.0) ~range:(0.0, 500.0) in
  Alcotest.(check (float 0.001))
    "domain_min -> range_min" 0.0 (Scale.apply s 0.0)

let test_apply_max () =
  let s = Scale.create ~domain:(0.0, 100.0) ~range:(0.0, 500.0) in
  Alcotest.(check (float 0.001))
    "domain_max -> range_max" 500.0 (Scale.apply s 100.0)

let test_apply_mid () =
  let s = Scale.create ~domain:(0.0, 100.0) ~range:(0.0, 500.0) in
  Alcotest.(check (float 0.001)) "midpoint" 250.0 (Scale.apply s 50.0)

let test_invert () =
  let s = Scale.create ~domain:(0.0, 100.0) ~range:(0.0, 500.0) in
  Alcotest.(check (float 0.001)) "invert range_min" 0.0 (Scale.invert s 0.0);
  Alcotest.(check (float 0.001)) "invert range_max" 100.0 (Scale.invert s 500.0)

let test_invert_roundtrip () =
  let s = Scale.create ~domain:(10.0, 90.0) ~range:(100.0, 900.0) in
  let v = 42.0 in
  Alcotest.(check (float 0.001))
    "roundtrip" v
    (Scale.invert s (Scale.apply s v))

let test_equal () =
  let a = Scale.create ~domain:(0.0, 1.0) ~range:(0.0, 100.0) in
  let b = Scale.create ~domain:(0.0, 1.0) ~range:(0.0, 100.0) in
  let c = Scale.create ~domain:(0.0, 2.0) ~range:(0.0, 100.0) in
  Alcotest.(check bool) "same" true (Scale.equal a b);
  Alcotest.(check bool) "different" false (Scale.equal a c)

let () =
  Alcotest.run "Scale"
    [
      ( "scale",
        [
          Alcotest.test_case "apply min" `Quick test_apply_min;
          Alcotest.test_case "apply max" `Quick test_apply_max;
          Alcotest.test_case "apply mid" `Quick test_apply_mid;
          Alcotest.test_case "invert" `Quick test_invert;
          Alcotest.test_case "invert roundtrip" `Quick test_invert_roundtrip;
          Alcotest.test_case "equal" `Quick test_equal;
        ] );
    ]

open Nopal_scene

let test_translate () =
  match Transform.translate ~dx:10.0 ~dy:20.0 with
  | Transform.Translate { dx; dy } ->
      Alcotest.(check (float 0.001)) "dx" 10.0 dx;
      Alcotest.(check (float 0.001)) "dy" 20.0 dy
  | _ -> Alcotest.fail "expected Translate"

let test_scale () =
  match Transform.scale ~sx:2.0 ~sy:3.0 with
  | Transform.Scale { sx; sy } ->
      Alcotest.(check (float 0.001)) "sx" 2.0 sx;
      Alcotest.(check (float 0.001)) "sy" 3.0 sy
  | _ -> Alcotest.fail "expected Scale"

let test_rotate () =
  match Transform.rotate 1.57 with
  | Transform.Rotate a -> Alcotest.(check (float 0.001)) "angle" 1.57 a
  | _ -> Alcotest.fail "expected Rotate"

let test_equal () =
  let a = Transform.translate ~dx:1.0 ~dy:2.0 in
  let b = Transform.translate ~dx:1.0 ~dy:2.0 in
  let c = Transform.scale ~sx:1.0 ~sy:2.0 in
  Alcotest.(check bool) "same" true (Transform.equal a b);
  Alcotest.(check bool) "diff" false (Transform.equal a c)

let () =
  Alcotest.run "Nopal_scene.Transform"
    [
      ( "transform",
        [
          Alcotest.test_case "translate" `Quick test_translate;
          Alcotest.test_case "scale" `Quick test_scale;
          Alcotest.test_case "rotate" `Quick test_rotate;
          Alcotest.test_case "equal" `Quick test_equal;
        ] );
    ]

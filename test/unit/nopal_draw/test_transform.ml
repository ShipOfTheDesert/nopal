open Nopal_draw

let test_translate () =
  let t = Transform.translate ~dx:10.0 ~dy:20.0 in
  match t with
  | Transform.Translate { dx; dy } ->
      Alcotest.(check (float 0.001)) "dx" 10.0 dx;
      Alcotest.(check (float 0.001)) "dy" 20.0 dy
  | _ -> Alcotest.fail "expected Translate"

let test_scale () =
  let t = Transform.scale ~sx:2.0 ~sy:3.0 in
  match t with
  | Transform.Scale { sx; sy } ->
      Alcotest.(check (float 0.001)) "sx" 2.0 sx;
      Alcotest.(check (float 0.001)) "sy" 3.0 sy
  | _ -> Alcotest.fail "expected Scale"

let test_rotate () =
  let t = Transform.rotate 1.57 in
  match t with
  | Transform.Rotate angle -> Alcotest.(check (float 0.001)) "angle" 1.57 angle
  | _ -> Alcotest.fail "expected Rotate"

let test_rotate_around () =
  let t = Transform.rotate_around ~angle:0.5 ~cx:100.0 ~cy:200.0 in
  match t with
  | Transform.Rotate_around { angle; cx; cy } ->
      Alcotest.(check (float 0.001)) "angle" 0.5 angle;
      Alcotest.(check (float 0.001)) "cx" 100.0 cx;
      Alcotest.(check (float 0.001)) "cy" 200.0 cy
  | _ -> Alcotest.fail "expected Rotate_around"

let test_skew () =
  let t = Transform.skew ~sx:0.3 ~sy:0.4 in
  match t with
  | Transform.Skew { sx; sy } ->
      Alcotest.(check (float 0.001)) "sx" 0.3 sx;
      Alcotest.(check (float 0.001)) "sy" 0.4 sy
  | _ -> Alcotest.fail "expected Skew"

let test_matrix () =
  let t = Transform.matrix ~a:1.0 ~b:2.0 ~c:3.0 ~d:4.0 ~e:5.0 ~f:6.0 in
  match t with
  | Transform.Matrix { a; b; c; d; e; f } ->
      Alcotest.(check (float 0.001)) "a" 1.0 a;
      Alcotest.(check (float 0.001)) "b" 2.0 b;
      Alcotest.(check (float 0.001)) "c" 3.0 c;
      Alcotest.(check (float 0.001)) "d" 4.0 d;
      Alcotest.(check (float 0.001)) "e" 5.0 e;
      Alcotest.(check (float 0.001)) "f" 6.0 f
  | _ -> Alcotest.fail "expected Matrix"

let test_equal_same () =
  let a = Transform.translate ~dx:1.0 ~dy:2.0 in
  let b = Transform.translate ~dx:1.0 ~dy:2.0 in
  Alcotest.(check bool) "same" true (Transform.equal a b)

let test_equal_different () =
  let a = Transform.translate ~dx:1.0 ~dy:2.0 in
  let b = Transform.scale ~sx:1.0 ~sy:2.0 in
  let c = Transform.translate ~dx:3.0 ~dy:2.0 in
  Alcotest.(check bool) "different variant" false (Transform.equal a b);
  Alcotest.(check bool) "different values" false (Transform.equal a c)

let () =
  Alcotest.run "Transform"
    [
      ( "transform",
        [
          Alcotest.test_case "translate" `Quick test_translate;
          Alcotest.test_case "scale" `Quick test_scale;
          Alcotest.test_case "rotate" `Quick test_rotate;
          Alcotest.test_case "rotate around" `Quick test_rotate_around;
          Alcotest.test_case "skew" `Quick test_skew;
          Alcotest.test_case "matrix" `Quick test_matrix;
          Alcotest.test_case "equal same" `Quick test_equal_same;
          Alcotest.test_case "equal different" `Quick test_equal_different;
        ] );
    ]

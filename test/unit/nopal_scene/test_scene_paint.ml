open Nopal_scene

let test_solid () =
  let p = Paint.solid Color.red in
  match p with
  | Paint.Solid c ->
      Alcotest.(check bool) "is red" true (Color.equal c Color.red)
  | _ -> Alcotest.fail "expected Solid"

let test_no_paint () =
  Alcotest.(check bool) "equal" true (Paint.equal Paint.no_paint Paint.no_paint)

let test_linear_gradient () =
  let stops =
    [
      { Paint.offset = 0.0; color = Color.red };
      { offset = 1.0; color = Color.blue };
    ]
  in
  match Paint.linear_gradient ~x0:0.0 ~y0:0.0 ~x1:100.0 ~y1:0.0 ~stops with
  | Ok (Paint.Linear_gradient _) -> ()
  | Ok _ -> Alcotest.fail "expected Linear_gradient"
  | Error e -> Alcotest.fail e

let test_radial_gradient () =
  let stops = [ { Paint.offset = 0.5; color = Color.green } ] in
  match Paint.radial_gradient ~cx:50.0 ~cy:50.0 ~r:25.0 ~stops with
  | Ok (Paint.Radial_gradient _) -> ()
  | Ok _ -> Alcotest.fail "expected Radial_gradient"
  | Error e -> Alcotest.fail e

let test_stroke () =
  let s = Paint.stroke (Paint.solid Color.black) in
  Alcotest.(check (float 0.001)) "default width" 1.0 s.width

let test_equal () =
  Alcotest.(check bool)
    "same" true
    (Paint.equal (Paint.solid Color.red) (Paint.solid Color.red));
  Alcotest.(check bool)
    "diff" false
    (Paint.equal (Paint.solid Color.red) (Paint.solid Color.blue))

let () =
  Alcotest.run "Nopal_scene.Paint"
    [
      ( "paint",
        [
          Alcotest.test_case "solid" `Quick test_solid;
          Alcotest.test_case "no_paint" `Quick test_no_paint;
          Alcotest.test_case "linear_gradient" `Quick test_linear_gradient;
          Alcotest.test_case "radial_gradient" `Quick test_radial_gradient;
          Alcotest.test_case "stroke" `Quick test_stroke;
          Alcotest.test_case "equal" `Quick test_equal;
        ] );
    ]

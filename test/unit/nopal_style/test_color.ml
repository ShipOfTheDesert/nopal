open Nopal_style.Color

(* --- Constructor tests --- *)

let test_constructors () =
  (match rgba 255 0 0 1.0 with
  | Rgba { r; g; b; a } ->
      Alcotest.(check int) "r" 255 r;
      Alcotest.(check int) "g" 0 g;
      Alcotest.(check int) "b" 0 b;
      Alcotest.(check (float 0.001)) "a" 1.0 a
  | Hex _
  | Named _
  | Transparent ->
      Alcotest.fail "expected Rgba");
  (match hex "#ff0000" with
  | Hex s -> Alcotest.(check string) "hex value" "#ff0000" s
  | Rgba _
  | Named _
  | Transparent ->
      Alcotest.fail "expected Hex");
  (match named "red" with
  | Named s -> Alcotest.(check string) "named value" "red" s
  | Rgba _
  | Hex _
  | Transparent ->
      Alcotest.fail "expected Named");
  match transparent with
  | Transparent -> ()
  | Rgba _
  | Hex _
  | Named _ ->
      Alcotest.fail "expected Transparent"

(* --- Equality tests --- *)

let test_equal_same_alpha () =
  Alcotest.(check bool)
    "same alpha" true
    (equal (rgba 12 34 56 0.5) (rgba 12 34 56 0.5));
  Alcotest.(check bool)
    "alpha differs" false
    (equal (rgba 12 34 56 0.5) (rgba 12 34 56 1.0))

let test_equal_across_arms () =
  Alcotest.(check bool)
    "rgba vs hex" false
    (equal (rgba 255 0 0 1.0) (hex "#ff0000"));
  Alcotest.(check bool)
    "hex vs named" false
    (equal (hex "#ff0000") (named "red"));
  Alcotest.(check bool)
    "named vs transparent" false
    (equal (named "red") transparent);
  Alcotest.(check bool)
    "transparent vs rgba" false
    (equal transparent (rgba 0 0 0 0.0));
  Alcotest.(check bool) "transparent alike" true (equal transparent transparent);
  Alcotest.(check bool) "hex alike" true (equal (hex "#abc") (hex "#abc"));
  Alcotest.(check bool) "hex differs" false (equal (hex "#abc") (hex "#abd"));
  Alcotest.(check bool) "named alike" true (equal (named "red") (named "red"));
  Alcotest.(check bool)
    "named differs" false
    (equal (named "red") (named "blue"))

(* --- Test runner --- *)

let () =
  Alcotest.run "nopal_style_color"
    [
      ( "Color",
        [
          Alcotest.test_case "constructors" `Quick test_constructors;
          Alcotest.test_case "equal_same_alpha" `Quick test_equal_same_alpha;
          Alcotest.test_case "equal_across_arms" `Quick test_equal_across_arms;
        ] );
    ]

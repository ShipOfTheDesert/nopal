open Nopal_style.Font

let test_family_sans_serif () =
  match Sans_serif with
  | Sans_serif -> ()
  | Serif
  | Monospace
  | Custom _ ->
      Alcotest.fail "expected Sans_serif"

let test_family_custom () =
  match Custom "Inter" with
  | Custom s -> Alcotest.(check string) "custom family" "Inter" s
  | Sans_serif
  | Serif
  | Monospace ->
      Alcotest.fail "expected Custom"

let test_weight_normal_bold () =
  Alcotest.(check bool) "Normal = Normal" true (equal_weight Normal Normal);
  Alcotest.(check bool) "Bold = Bold" true (equal_weight Bold Bold);
  Alcotest.(check bool) "Normal <> Bold" false (equal_weight Normal Bold)

let test_family_to_css () =
  Alcotest.(check string)
    "sans-serif css" "sans-serif"
    (family_to_css_string Sans_serif);
  Alcotest.(check string) "serif css" "serif" (family_to_css_string Serif);
  Alcotest.(check string)
    "monospace css" "monospace"
    (family_to_css_string Monospace);
  Alcotest.(check string)
    "custom css" "\"Inter\""
    (family_to_css_string (Custom "Inter"))

let test_weight_to_css () =
  Alcotest.(check string) "normal css" "normal" (weight_to_css_string Normal);
  Alcotest.(check string) "bold css" "bold" (weight_to_css_string Bold)

let () =
  Alcotest.run "nopal_style_font"
    [
      ( "Font",
        [
          Alcotest.test_case "family_sans_serif" `Quick test_family_sans_serif;
          Alcotest.test_case "family_custom" `Quick test_family_custom;
          Alcotest.test_case "weight_normal_bold" `Quick test_weight_normal_bold;
          Alcotest.test_case "family_to_css" `Quick test_family_to_css;
          Alcotest.test_case "weight_to_css" `Quick test_weight_to_css;
        ] );
    ]

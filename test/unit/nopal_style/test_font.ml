open Nopal_style.Font

let test_family_sans_serif () =
  match Sans_serif with
  | Sans_serif -> ()
  | System_ui
  | Serif
  | Monospace
  | Custom _ ->
      Alcotest.fail "expected Sans_serif"

let test_family_custom () =
  match Custom "Inter" with
  | Custom s -> Alcotest.(check string) "custom family" "Inter" s
  | System_ui
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
  Alcotest.(check string) "normal css" "400" (weight_to_css_string Normal);
  Alcotest.(check string) "bold css" "700" (weight_to_css_string Bold)

let test_weight_thin_to_css () =
  Alcotest.(check string) "thin css" "100" (weight_to_css_string Thin)

let test_weight_extra_light_to_css () =
  Alcotest.(check string)
    "extra_light css" "200"
    (weight_to_css_string Extra_light)

let test_weight_light_to_css () =
  Alcotest.(check string) "light css" "300" (weight_to_css_string Light)

let test_weight_medium_to_css () =
  Alcotest.(check string) "medium css" "500" (weight_to_css_string Medium)

let test_weight_semi_bold_to_css () =
  Alcotest.(check string) "semi_bold css" "600" (weight_to_css_string Semi_bold)

let test_weight_extra_bold_to_css () =
  Alcotest.(check string)
    "extra_bold css" "800"
    (weight_to_css_string Extra_bold)

let test_weight_black_to_css () =
  Alcotest.(check string) "black css" "900" (weight_to_css_string Black)

let test_weight_to_int_all () =
  Alcotest.(check int) "Thin" 100 (weight_to_int Thin);
  Alcotest.(check int) "Extra_light" 200 (weight_to_int Extra_light);
  Alcotest.(check int) "Light" 300 (weight_to_int Light);
  Alcotest.(check int) "Normal" 400 (weight_to_int Normal);
  Alcotest.(check int) "Medium" 500 (weight_to_int Medium);
  Alcotest.(check int) "Semi_bold" 600 (weight_to_int Semi_bold);
  Alcotest.(check int) "Bold" 700 (weight_to_int Bold);
  Alcotest.(check int) "Extra_bold" 800 (weight_to_int Extra_bold);
  Alcotest.(check int) "Black" 900 (weight_to_int Black)

let test_family_system_ui_to_css () =
  Alcotest.(check string)
    "system-ui css" "system-ui"
    (family_to_css_string System_ui)

let test_equal_weight_all_nine () =
  let weights =
    [
      Thin;
      Extra_light;
      Light;
      Normal;
      Medium;
      Semi_bold;
      Bold;
      Extra_bold;
      Black;
    ]
  in
  List.iteri
    (fun i a ->
      List.iteri
        (fun j b ->
          let expected = i = j in
          Alcotest.(check bool)
            (Printf.sprintf "weight %d vs %d" i j)
            expected (equal_weight a b))
        weights)
    weights

let test_equal_family_system_ui () =
  Alcotest.(check bool)
    "System_ui = System_ui" true
    (equal_family System_ui System_ui);
  Alcotest.(check bool)
    "System_ui <> Sans_serif" false
    (equal_family System_ui Sans_serif);
  Alcotest.(check bool)
    "Sans_serif <> System_ui" false
    (equal_family Sans_serif System_ui)

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
          Alcotest.test_case "weight_thin_to_css" `Quick test_weight_thin_to_css;
          Alcotest.test_case "weight_extra_light_to_css" `Quick
            test_weight_extra_light_to_css;
          Alcotest.test_case "weight_light_to_css" `Quick
            test_weight_light_to_css;
          Alcotest.test_case "weight_medium_to_css" `Quick
            test_weight_medium_to_css;
          Alcotest.test_case "weight_semi_bold_to_css" `Quick
            test_weight_semi_bold_to_css;
          Alcotest.test_case "weight_extra_bold_to_css" `Quick
            test_weight_extra_bold_to_css;
          Alcotest.test_case "weight_black_to_css" `Quick
            test_weight_black_to_css;
          Alcotest.test_case "weight_to_int_all" `Quick test_weight_to_int_all;
          Alcotest.test_case "family_system_ui_to_css" `Quick
            test_family_system_ui_to_css;
          Alcotest.test_case "equal_weight_all_nine" `Quick
            test_equal_weight_all_nine;
          Alcotest.test_case "equal_family_system_ui" `Quick
            test_equal_family_system_ui;
        ] );
    ]

open Nopal_style.Font

let test_family_sans_serif () =
  match Sans_serif with
  | Sans_serif -> ()
  | System_ui
  | Serif
  | Monospace
  | Ui_sans_serif
  | Ui_serif
  | Ui_monospace
  | Ui_rounded
  | Custom _ ->
      Alcotest.fail "expected Sans_serif"

let test_family_custom () =
  match Custom "Inter" with
  | Custom s -> Alcotest.(check string) "custom family" "Inter" s
  | System_ui
  | Sans_serif
  | Serif
  | Monospace
  | Ui_sans_serif
  | Ui_serif
  | Ui_monospace
  | Ui_rounded ->
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

let family =
  Alcotest.testable
    (fun ppf f -> Format.pp_print_string ppf (family_to_css_string f))
    equal_family

let test_stack_css_order () =
  let sans =
    stack [ Custom "Geist"; System_ui ] ~last_resort:Generic.Sans_serif
  in
  let mono =
    stack [ Custom "Geist Mono"; Ui_monospace ] ~last_resort:Generic.Monospace
  in
  Alcotest.(check string)
    "sans stack" {|"Geist", system-ui, sans-serif|} (stack_to_css_string sans);
  Alcotest.(check string)
    "mono stack" {|"Geist Mono", ui-monospace, monospace|}
    (stack_to_css_string mono);
  Alcotest.(check (list family))
    "sans families"
    [ Custom "Geist"; System_ui; Sans_serif ]
    (families sans);
  Alcotest.(check (list family))
    "mono families"
    [ Custom "Geist Mono"; Ui_monospace; Monospace ]
    (families mono)

let test_ui_generics_bare () =
  List.iter
    (fun (f, expected) ->
      Alcotest.(check string) expected expected (family_to_css_string f))
    [
      (Ui_sans_serif, "ui-sans-serif");
      (Ui_serif, "ui-serif");
      (Ui_monospace, "ui-monospace");
      (Ui_rounded, "ui-rounded");
    ]

(* Scans the serialised name as a CSS string token: after the opening quote,
   a backslash consumes the next byte, so only an unescaped quote ends it. *)
let check_no_raw_structure name css =
  let last = String.length css - 1 in
  let escaped = ref false in
  String.iteri
    (fun i c ->
      let code = Char.code c in
      if code < 0x20 || code = 0x7f then
        Alcotest.failf "%S: raw control character at %d in %S" name i css;
      match c with
      | ';'
      | '{'
      | '}' ->
          Alcotest.failf "%S: raw %C in %S" name c css
      | '"' when i = 0 || i = last -> ()
      | '"' when not !escaped ->
          Alcotest.failf "%S: unescaped quote at %d in %S" name i css
      | '\\' when not !escaped -> escaped := true
      | _ -> escaped := false)
    css

let test_custom_name_escaped () =
  List.iter
    (fun (name, expected) ->
      let css = family_to_css_string (Custom name) in
      Alcotest.(check string) (String.escaped name) expected css;
      check_no_raw_structure name css)
    [
      ("Two Words", {|"Two Words"|});
      ({|a"b|}, {|"a\"b"|});
      ({|a\b|}, {|"a\\b"|});
      ("a;b", {|"a\3b b"|});
      ("a{b}c", {|"a\7b b\7d c"|});
      ("a,b", {|"a,b"|});
      ("a&b<c", {|"a&b<c"|});
      ("x\ny\tz", {|"x\a y\9 z"|});
    ]

let test_custom_keyword_stays_quoted () =
  Alcotest.(check string)
    "Custom serif" {|"serif"|}
    (family_to_css_string (Custom "serif"))

let test_existing_generics_unchanged () =
  List.iter
    (fun (f, expected) ->
      Alcotest.(check string) expected expected (family_to_css_string f))
    [
      (System_ui, "system-ui");
      (Sans_serif, "sans-serif");
      (Serif, "serif");
      (Monospace, "monospace");
      (Custom "Inter", {|"Inter"|});
    ]

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
          Alcotest.test_case "stack_css_order" `Quick test_stack_css_order;
          Alcotest.test_case "ui_generics_bare" `Quick test_ui_generics_bare;
          Alcotest.test_case "custom_name_escaped" `Quick
            test_custom_name_escaped;
          Alcotest.test_case "custom_keyword_stays_quoted" `Quick
            test_custom_keyword_stays_quoted;
          Alcotest.test_case "existing_generics_unchanged" `Quick
            test_existing_generics_unchanged;
        ] );
    ]

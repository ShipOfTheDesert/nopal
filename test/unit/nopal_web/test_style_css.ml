open Nopal_style.Style
open Nopal_web.Style_css

let css_prop_to_string { property; value } = property ^ ":" ^ value

let find_prop name props =
  List.find_opt (fun p -> String.equal p.property name) props

let check_has_prop name expected_value props =
  match find_prop name props with
  | None ->
      Alcotest.fail
        (Printf.sprintf "expected property %S but not found in [%s]" name
           (String.concat "; " (List.map css_prop_to_string props)))
  | Some p ->
      Alcotest.(check string)
        (Printf.sprintf "%s value" name)
        expected_value p.value

(* 1 *)
let test_default_style_produces_empty () =
  let props = of_style default in
  Alcotest.(check int) "no properties" 0 (List.length props)

(* 2 *)
let test_background_color_rgba () =
  let style =
    with_paint
      (fun p -> { p with background = Some (rgba 255 0 0 1.0) })
      default
  in
  let props = of_style style in
  check_has_prop "background-color" "rgba(255,0,0,1)" props

(* 3 *)
let test_padding_produces_css () =
  let style =
    with_layout
      (fun l ->
        {
          l with
          padding_top = 10.;
          padding_right = 20.;
          padding_bottom = 30.;
          padding_left = 40.;
        })
      default
  in
  let props = of_style style in
  check_has_prop "padding" "10px 20px 30px 40px" props

(* 4 *)
let test_flex_direction_row () =
  let style = with_layout (fun l -> { l with direction = Row_dir }) default in
  let props = of_style style in
  check_has_prop "flex-direction" "row" props

(* 5 *)
let test_border_produces_css () =
  let style =
    with_paint
      (fun p ->
        {
          p with
          border =
            Some
              { width = 2.; style = Solid; color = rgba 0 0 0 1.0; radius = 4. };
        })
      default
  in
  let props = of_style style in
  check_has_prop "border" "2px solid rgba(0,0,0,1)" props;
  check_has_prop "border-radius" "4px" props

(* 6 *)
let test_to_inline_string_joins () =
  let props =
    [
      { property = "color"; value = "red" };
      { property = "margin"; value = "0" };
    ]
  in
  let result = to_inline_string props in
  Alcotest.(check string) "joined" "color:red;margin:0" result

(* 7 *)
let test_size_fill_produces_100_percent () =
  let style = with_layout (fun l -> { l with width = Fill }) default in
  let props = of_style style in
  check_has_prop "width" "100%" props

(* 8 *)
let test_size_fixed_produces_px () =
  let style = with_layout (fun l -> { l with width = Fixed 200. }) default in
  let props = of_style style in
  check_has_prop "width" "200px" props

(* 9 *)
let test_size_fraction_produces_percent () =
  let style = with_layout (fun l -> { l with width = Fraction 0.5 }) default in
  let props = of_style style in
  check_has_prop "width" "50%" props

(* 10 *)
let test_opacity_produces_css () =
  let style = with_paint (fun p -> { p with opacity = 0.5 }) default in
  let props = of_style style in
  check_has_prop "opacity" "0.5" props

(* 11 *)
let test_overflow_hidden_produces_css () =
  let style = with_paint (fun p -> { p with overflow = Hidden }) default in
  let props = of_style style in
  check_has_prop "overflow" "hidden" props

(* 12 *)
let test_shadow_produces_box_shadow () =
  let style =
    with_paint
      (fun p ->
        {
          p with
          shadow = Some { x = 2.; y = 4.; blur = 6.; color = rgba 0 0 0 0.5 };
        })
      default
  in
  let props = of_style style in
  check_has_prop "box-shadow" "2px 4px 6px rgba(0,0,0,0.5)" props

(* 13 *)
let test_gap_produces_css () =
  let style = with_layout (fun l -> { l with gap = 10. }) default in
  let props = of_style style in
  check_has_prop "gap" "10px" props

(* 14 *)
let test_flex_grow_produces_css () =
  let style = with_layout (fun l -> { l with flex_grow = Some 1. }) default in
  let props = of_style style in
  check_has_prop "flex-grow" "1" props

(* 15 *)
let test_align_center_produces_css () =
  let style = with_layout (fun l -> { l with main_align = Center }) default in
  let props = of_style style in
  check_has_prop "justify-content" "center" props

(* 16 *)
let test_cross_align_stretch_produces_css () =
  let style = with_layout (fun l -> { l with cross_align = Stretch }) default in
  let props = of_style style in
  check_has_prop "align-items" "stretch" props

(* 17 *)
let test_wrap_produces_css () =
  let style = with_layout (fun l -> { l with wrap = true }) default in
  let props = of_style style in
  check_has_prop "flex-wrap" "wrap" props

let test_size_hug_produces_no_property () =
  let style = with_layout (fun l -> { l with width = Hug; gap = 1. }) default in
  let props = of_style style in
  let has_width = find_prop "width" props in
  Alcotest.(check bool) "no width property" true (Option.is_none has_width)

let test_background_color_hex () =
  let style =
    with_paint (fun p -> { p with background = Some (Hex "#ff0000") }) default
  in
  let props = of_style style in
  check_has_prop "background-color" "#ff0000" props

let test_background_color_named () =
  let style =
    with_paint (fun p -> { p with background = Some (Named "red") }) default
  in
  let props = of_style style in
  check_has_prop "background-color" "red" props

let () =
  Alcotest.run "style_css"
    [
      ( "of_style",
        [
          Alcotest.test_case "default produces empty" `Quick
            test_default_style_produces_empty;
          Alcotest.test_case "background color rgba" `Quick
            test_background_color_rgba;
          Alcotest.test_case "padding produces css" `Quick
            test_padding_produces_css;
          Alcotest.test_case "flex direction row" `Quick test_flex_direction_row;
          Alcotest.test_case "border produces css" `Quick
            test_border_produces_css;
          Alcotest.test_case "size fill produces 100%" `Quick
            test_size_fill_produces_100_percent;
          Alcotest.test_case "size fixed produces px" `Quick
            test_size_fixed_produces_px;
          Alcotest.test_case "size fraction produces percent" `Quick
            test_size_fraction_produces_percent;
          Alcotest.test_case "opacity produces css" `Quick
            test_opacity_produces_css;
          Alcotest.test_case "overflow hidden produces css" `Quick
            test_overflow_hidden_produces_css;
          Alcotest.test_case "shadow produces box-shadow" `Quick
            test_shadow_produces_box_shadow;
          Alcotest.test_case "gap produces css" `Quick test_gap_produces_css;
          Alcotest.test_case "flex grow produces css" `Quick
            test_flex_grow_produces_css;
          Alcotest.test_case "align center produces css" `Quick
            test_align_center_produces_css;
          Alcotest.test_case "cross align stretch produces css" `Quick
            test_cross_align_stretch_produces_css;
          Alcotest.test_case "wrap produces css" `Quick test_wrap_produces_css;
        ] );
      ( "to_inline_string",
        [
          Alcotest.test_case "joins properties" `Quick
            test_to_inline_string_joins;
        ] );
      ( "size variants",
        [
          Alcotest.test_case "hug produces no property" `Quick
            test_size_hug_produces_no_property;
        ] );
      ( "color variants",
        [
          Alcotest.test_case "hex color" `Quick test_background_color_hex;
          Alcotest.test_case "named color" `Quick test_background_color_named;
        ] );
    ]

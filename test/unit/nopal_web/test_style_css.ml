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

(* I-5: to_important_rule_body tests *)
let test_important_rule_body_single () =
  let props = [ { property = "color"; value = "red" } ] in
  let result = to_important_rule_body props in
  Alcotest.(check string) "single prop" "color:red !important;" result

let test_important_rule_body_multiple () =
  let props =
    [
      { property = "background-color"; value = "#ff0000" };
      { property = "padding"; value = "8px" };
    ]
  in
  let result = to_important_rule_body props in
  Alcotest.(check string)
    "multiple props"
    "background-color:#ff0000 !important;padding:8px !important;" result

let test_important_rule_body_empty () =
  let result = to_important_rule_body [] in
  Alcotest.(check string) "empty list" "" result

(* Substring search helper — returns position or -1 *)
let find_substring haystack needle =
  let hlen = String.length haystack in
  let nlen = String.length needle in
  if nlen > hlen then -1
  else
    let found = ref (-1) in
    let i = ref 0 in
    while !found = -1 && !i <= hlen - nlen do
      if String.sub haystack !i nlen = needle then found := !i;
      incr i
    done;
    !found

let contains s sub = find_substring s sub >= 0

(* I-6: interaction_rules tests *)
let test_interaction_rules_hover_only () =
  let interaction =
    {
      Nopal_style.Interaction.default with
      hover =
        Some
          (Nopal_style.Style.default
          |> Nopal_style.Style.with_paint (fun p ->
              { p with background = Some (Nopal_style.Style.hex "#ff0000") }));
    }
  in
  let result = interaction_rules ~class_name:"_nopal_ix_0" interaction in
  Alcotest.(check bool)
    "has hover selector" true
    (contains result "._nopal_ix_0:hover{");
  Alcotest.(check bool) "has !important" true (contains result "!important");
  Alcotest.(check bool) "no active rule" true (not (contains result ":active"))

let test_interaction_rules_all_states () =
  let hover_style =
    Nopal_style.Style.default
    |> Nopal_style.Style.with_paint (fun p ->
        { p with background = Some (Nopal_style.Style.hex "#aaa") })
  in
  let pressed_style =
    Nopal_style.Style.default
    |> Nopal_style.Style.with_paint (fun p ->
        { p with background = Some (Nopal_style.Style.hex "#bbb") })
  in
  let focused_style =
    Nopal_style.Style.default
    |> Nopal_style.Style.with_paint (fun p ->
        { p with background = Some (Nopal_style.Style.hex "#ccc") })
  in
  let interaction =
    {
      Nopal_style.Interaction.hover = Some hover_style;
      pressed = Some pressed_style;
      focused = Some focused_style;
    }
  in
  let result = interaction_rules ~class_name:"_nopal_ix_5" interaction in
  Alcotest.(check bool) "has hover" true (contains result "._nopal_ix_5:hover{");
  Alcotest.(check bool)
    "has focus-visible" true
    (contains result "._nopal_ix_5:focus-visible{");
  Alcotest.(check bool)
    "has active" true
    (contains result "._nopal_ix_5:active{");
  (* Verify precedence order: hover before focus-visible before active *)
  let hover_pos = find_substring result ":hover{" in
  let focus_pos = find_substring result ":focus-visible{" in
  let active_pos = find_substring result ":active{" in
  Alcotest.(check bool) "hover before focus-visible" true (hover_pos < focus_pos);
  Alcotest.(check bool)
    "focus-visible before active" true (focus_pos < active_pos)

let test_interaction_rules_default_empty () =
  let result =
    interaction_rules ~class_name:"_nopal_ix_0" Nopal_style.Interaction.default
  in
  Alcotest.(check string) "default produces empty" "" result

let test_interaction_rules_focused_only () =
  let interaction =
    {
      Nopal_style.Interaction.default with
      focused =
        Some
          (Nopal_style.Style.default
          |> Nopal_style.Style.with_paint (fun p ->
              {
                p with
                border =
                  Some
                    {
                      width = 2.0;
                      style = Solid;
                      color = Nopal_style.Style.hex "#0000ff";
                      radius = 4.0;
                    };
              }));
    }
  in
  let result = interaction_rules ~class_name:"_nopal_ix_1" interaction in
  Alcotest.(check bool)
    "has focus-visible selector" true
    (contains result "._nopal_ix_1:focus-visible{");
  Alcotest.(check bool) "no hover rule" true (not (contains result ":hover"));
  Alcotest.(check bool) "no active rule" true (not (contains result ":active"))

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
      ( "to_important_rule_body",
        [
          Alcotest.test_case "single property" `Quick
            test_important_rule_body_single;
          Alcotest.test_case "multiple properties" `Quick
            test_important_rule_body_multiple;
          Alcotest.test_case "empty list" `Quick test_important_rule_body_empty;
        ] );
      ( "interaction_rules",
        [
          Alcotest.test_case "hover only" `Quick
            test_interaction_rules_hover_only;
          Alcotest.test_case "all states with precedence" `Quick
            test_interaction_rules_all_states;
          Alcotest.test_case "default produces empty" `Quick
            test_interaction_rules_default_empty;
          Alcotest.test_case "focused only" `Quick
            test_interaction_rules_focused_only;
        ] );
    ]

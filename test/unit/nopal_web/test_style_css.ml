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

let check_no_prop name props =
  match find_prop name props with
  | None -> ()
  | Some _ ->
      Alcotest.fail
        (Printf.sprintf "expected property %S to be absent but found in [%s]"
           name
           (String.concat "; " (List.map css_prop_to_string props)))

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
          padding_top = Some 10.;
          padding_right = Some 20.;
          padding_bottom = Some 30.;
          padding_left = Some 40.;
        })
      default
  in
  let props = of_style style in
  check_has_prop "padding" "10px 20px 30px 40px" props

(* 4 *)
let test_flex_direction_row () =
  let style =
    with_layout (fun l -> { l with direction = Some Row_dir }) default
  in
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
  let style = with_layout (fun l -> { l with width = Some Fill }) default in
  let props = of_style style in
  check_has_prop "width" "100%" props

(* 8 *)
let test_size_fixed_produces_px () =
  let style =
    with_layout (fun l -> { l with width = Some (Fixed 200.) }) default
  in
  let props = of_style style in
  check_has_prop "width" "200px" props

(* 9 *)
let test_size_fraction_produces_percent () =
  let style =
    with_layout (fun l -> { l with width = Some (Fraction 0.5) }) default
  in
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
  let style = with_layout (fun l -> { l with gap = Some 10. }) default in
  let props = of_style style in
  check_has_prop "gap" "10px" props

(* 14 *)
let test_flex_grow_produces_css () =
  let style = with_layout (fun l -> { l with flex_grow = Some 1. }) default in
  let props = of_style style in
  check_has_prop "flex-grow" "1" props

(* 15 *)
let test_align_center_produces_css () =
  let style =
    with_layout (fun l -> { l with main_align = Some Center }) default
  in
  let props = of_style style in
  check_has_prop "justify-content" "center" props

(* 16 *)
let test_cross_align_stretch_produces_css () =
  let style =
    with_layout (fun l -> { l with cross_align = Some Stretch }) default
  in
  let props = of_style style in
  check_has_prop "align-items" "stretch" props

(* 17 *)
let test_wrap_produces_css () =
  let style = with_layout (fun l -> { l with wrap = Some true }) default in
  let props = of_style style in
  check_has_prop "flex-wrap" "wrap" props

let test_size_hug_produces_no_property () =
  let style =
    with_layout (fun l -> { l with width = Some Hug; gap = Some 1. }) default
  in
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
  Alcotest.(check bool)
    "no !important" true
    (not (contains result "!important"));
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

(* ── Text CSS tests ── *)

let text_props ts = of_text ts

let test_text_none_fields_no_css () =
  let props = text_props Nopal_style.Text.default in
  Alcotest.(check int) "no properties" 0 (List.length props)

let test_text_font_family_sans_serif () =
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.font_family Nopal_style.Font.Sans_serif
  in
  let props = text_props ts in
  check_has_prop "font-family" "sans-serif" props

let test_text_font_family_system_ui () =
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.font_family Nopal_style.Font.System_ui
  in
  let props = text_props ts in
  check_has_prop "font-family" "system-ui" props

let test_text_font_family_custom_quoted () =
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.font_family (Nopal_style.Font.Custom "Inter")
  in
  let props = text_props ts in
  check_has_prop "font-family" "\"Inter\"" props

let test_text_font_size_rem () =
  let ts = Nopal_style.Text.default |> Nopal_style.Text.font_size 1.5 in
  let props = text_props ts in
  check_has_prop "font-size" "1.5rem" props

let test_text_font_weight_thin () =
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.font_weight Nopal_style.Font.Thin
  in
  let props = text_props ts in
  check_has_prop "font-weight" "100" props

let test_text_font_weight_bold () =
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.font_weight Nopal_style.Font.Bold
  in
  let props = text_props ts in
  check_has_prop "font-weight" "700" props

let test_text_italic_true () =
  let ts = Nopal_style.Text.default |> Nopal_style.Text.italic true in
  let props = text_props ts in
  check_has_prop "font-style" "italic" props

let test_text_italic_false () =
  let ts = Nopal_style.Text.default |> Nopal_style.Text.italic false in
  let props = text_props ts in
  check_has_prop "font-style" "normal" props

let test_text_line_height_normal () =
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.line_height Nopal_style.Text.Lh_normal
  in
  let props = text_props ts in
  check_has_prop "line-height" "normal" props

let test_text_line_height_multiplier () =
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.line_height (Nopal_style.Text.Lh_multiplier 1.5)
  in
  let props = text_props ts in
  check_has_prop "line-height" "1.5" props

let test_text_line_height_px () =
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.line_height (Nopal_style.Text.Lh_px 24.)
  in
  let props = text_props ts in
  check_has_prop "line-height" "24px" props

let test_text_letter_spacing_normal () =
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.letter_spacing Nopal_style.Text.Ls_normal
  in
  let props = text_props ts in
  check_has_prop "letter-spacing" "normal" props

let test_text_letter_spacing_em () =
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.letter_spacing (Nopal_style.Text.Ls_em 0.05)
  in
  let props = text_props ts in
  check_has_prop "letter-spacing" "0.05em" props

let test_text_align_center () =
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.text_align Nopal_style.Text.Align_center
  in
  let props = text_props ts in
  check_has_prop "text-align" "center" props

let test_text_decoration_underline () =
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.text_decoration Nopal_style.Text.Underline
  in
  let props = text_props ts in
  check_has_prop "text-decoration" "underline" props

let test_text_transform_uppercase () =
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.text_transform Nopal_style.Text.Uppercase
  in
  let props = text_props ts in
  check_has_prop "text-transform" "uppercase" props

let test_text_overflow_ellipsis () =
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.text_overflow Nopal_style.Text.Ellipsis
  in
  let props = text_props ts in
  check_has_prop "text-overflow" "ellipsis" props;
  check_has_prop "overflow" "hidden" props;
  check_has_prop "white-space" "nowrap" props

let test_text_overflow_clip () =
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.text_overflow Nopal_style.Text.Clip
  in
  let props = text_props ts in
  check_has_prop "text-overflow" "clip" props

let test_text_overflow_wrap () =
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.text_overflow Nopal_style.Text.Wrap
  in
  let props = text_props ts in
  check_has_prop "white-space" "normal" props

let test_text_overflow_no_wrap () =
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.text_overflow Nopal_style.Text.No_wrap
  in
  let props = text_props ts in
  check_has_prop "white-space" "nowrap" props

let test_text_only_some_fields_emit () =
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.font_size 2.0
    |> Nopal_style.Text.font_weight Nopal_style.Font.Bold
  in
  let props = text_props ts in
  Alcotest.(check int) "exactly 2 properties" 2 (List.length props);
  check_has_prop "font-size" "2rem" props;
  check_has_prop "font-weight" "700" props

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

(* ── base_class_rule tests ── *)

let test_base_class_rule_generates_class_selector () =
  let props =
    [
      { property = "background-color"; value = "red" };
      { property = "padding"; value = "10px" };
    ]
  in
  let result = base_class_rule ~class_name:"_nopal_b_0" props in
  Alcotest.(check string)
    "class rule" "._nopal_b_0{background-color:red;padding:10px;}" result

let test_base_class_rule_empty_props () =
  let result = base_class_rule ~class_name:"_nopal_b_0" [] in
  Alcotest.(check string) "empty props" "" result

(* ── split_css_rules tests ── *)

let test_split_css_rules_single () =
  let result = split_css_rules ".a:hover{color:red;}" in
  Alcotest.(check (list string)) "single rule" [ ".a:hover{color:red;}" ] result

let test_split_css_rules_multiple () =
  let css = ".a:hover{color:red;}.a:active{color:blue;}" in
  let result = split_css_rules css in
  Alcotest.(check (list string))
    "two rules"
    [ ".a:hover{color:red;}"; ".a:active{color:blue;}" ]
    result

let test_split_css_rules_empty () =
  let result = split_css_rules "" in
  Alcotest.(check (list string)) "empty string" [] result

let test_split_css_rules_three_rules () =
  let css = ".x:hover{a:1;}.x:focus-visible{b:2;}.x:active{c:3;}" in
  let result = split_css_rules css in
  Alcotest.(check (list string))
    "three rules"
    [ ".x:hover{a:1;}"; ".x:focus-visible{b:2;}"; ".x:active{c:3;}" ]
    result

(* ── normalize_key tests ── *)

let test_normalize_key_replaces_class_name () =
  let css = "._nopal_ix_5:hover{color:red;}" in
  let result = normalize_key css "_nopal_ix_5" in
  Alcotest.(check string)
    "class replaced" ".__NOPAL_IX__:hover{color:red;}" result

let test_normalize_key_replaces_all_occurrences () =
  let css = "._nopal_ix_3:hover{a:1;}._nopal_ix_3:active{b:2;}" in
  let result = normalize_key css "_nopal_ix_3" in
  Alcotest.(check string)
    "all occurrences replaced"
    ".__NOPAL_IX__:hover{a:1;}.__NOPAL_IX__:active{b:2;}" result

let test_normalize_key_empty_css () =
  let result = normalize_key "" "_nopal_ix_0" in
  Alcotest.(check string) "empty css" "" result

let test_normalize_key_same_key_for_identical_styles () =
  let css_a = "._nopal_ix_0:hover{color:red;}" in
  let css_b = "._nopal_ix_7:hover{color:red;}" in
  let key_a = normalize_key css_a "_nopal_ix_0" in
  let key_b = normalize_key css_b "_nopal_ix_7" in
  Alcotest.(check string) "same normalized key" key_a key_b

(* ── Optional layout field CSS emission tests ── *)

let test_css_omits_all_for_default_layout () =
  let style = default in
  let props = of_style style in
  check_no_prop "flex-direction" props;
  check_no_prop "justify-content" props;
  check_no_prop "align-items" props;
  check_no_prop "flex-wrap" props;
  check_no_prop "gap" props;
  check_no_prop "padding" props;
  check_no_prop "width" props;
  check_no_prop "height" props;
  check_no_prop "flex-grow" props

let test_css_emits_direction_when_set () =
  let style =
    with_layout (fun l -> { l with direction = Some Column_dir }) default
  in
  let props = of_style style in
  check_has_prop "flex-direction" "column" props;
  (* Only direction was set — no other layout props should appear *)
  check_no_prop "justify-content" props;
  check_no_prop "align-items" props;
  check_no_prop "flex-wrap" props;
  check_no_prop "gap" props;
  check_no_prop "padding" props;
  check_no_prop "width" props;
  check_no_prop "height" props;
  check_no_prop "flex-grow" props

let test_css_emits_only_set_fields () =
  let style =
    with_layout
      (fun l -> { l with gap = Some 16.; width = Some (Fixed 300.) })
      default
  in
  let props = of_style style in
  check_has_prop "gap" "16px" props;
  check_has_prop "width" "300px" props;
  (* Unset fields should not appear *)
  check_no_prop "flex-direction" props;
  check_no_prop "justify-content" props;
  check_no_prop "align-items" props;
  check_no_prop "flex-wrap" props;
  check_no_prop "padding" props;
  check_no_prop "height" props;
  check_no_prop "flex-grow" props

let test_css_partial_padding_emits_individual () =
  let style =
    with_layout
      (fun l -> { l with padding_top = Some 10.; padding_left = Some 5. })
      default
  in
  let props = of_style style in
  check_has_prop "padding-top" "10px" props;
  check_has_prop "padding-left" "5px" props;
  check_no_prop "padding" props;
  check_no_prop "padding-right" props;
  check_no_prop "padding-bottom" props

let test_css_emits_multiple_set_fields () =
  let style =
    with_layout
      (fun _l ->
        {
          direction = Some Row_dir;
          main_align = Some Center;
          cross_align = Some End_;
          wrap = Some true;
          gap = Some 8.;
          padding_top = Some 4.;
          padding_right = Some 8.;
          padding_bottom = Some 4.;
          padding_left = Some 8.;
          width = Some Fill;
          height = Some (Fixed 100.);
          flex_grow = Some 2.;
        })
      default
  in
  let props = of_style style in
  check_has_prop "flex-direction" "row" props;
  check_has_prop "justify-content" "center" props;
  check_has_prop "align-items" "flex-end" props;
  check_has_prop "flex-wrap" "wrap" props;
  check_has_prop "gap" "8px" props;
  check_has_prop "padding" "4px 8px 4px 8px" props;
  check_has_prop "width" "100%" props;
  check_has_prop "height" "100px" props;
  check_has_prop "flex-grow" "2" props

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
      ( "of_text",
        [
          Alcotest.test_case "none fields no css" `Quick
            test_text_none_fields_no_css;
          Alcotest.test_case "font family sans-serif" `Quick
            test_text_font_family_sans_serif;
          Alcotest.test_case "font family system-ui" `Quick
            test_text_font_family_system_ui;
          Alcotest.test_case "font family custom quoted" `Quick
            test_text_font_family_custom_quoted;
          Alcotest.test_case "font size rem" `Quick test_text_font_size_rem;
          Alcotest.test_case "font weight thin" `Quick
            test_text_font_weight_thin;
          Alcotest.test_case "font weight bold" `Quick
            test_text_font_weight_bold;
          Alcotest.test_case "italic true" `Quick test_text_italic_true;
          Alcotest.test_case "italic false" `Quick test_text_italic_false;
          Alcotest.test_case "line height normal" `Quick
            test_text_line_height_normal;
          Alcotest.test_case "line height multiplier" `Quick
            test_text_line_height_multiplier;
          Alcotest.test_case "line height px" `Quick test_text_line_height_px;
          Alcotest.test_case "letter spacing normal" `Quick
            test_text_letter_spacing_normal;
          Alcotest.test_case "letter spacing em" `Quick
            test_text_letter_spacing_em;
          Alcotest.test_case "text align center" `Quick test_text_align_center;
          Alcotest.test_case "text decoration underline" `Quick
            test_text_decoration_underline;
          Alcotest.test_case "text transform uppercase" `Quick
            test_text_transform_uppercase;
          Alcotest.test_case "text overflow ellipsis" `Quick
            test_text_overflow_ellipsis;
          Alcotest.test_case "text overflow clip" `Quick test_text_overflow_clip;
          Alcotest.test_case "text overflow wrap" `Quick test_text_overflow_wrap;
          Alcotest.test_case "text overflow no wrap" `Quick
            test_text_overflow_no_wrap;
          Alcotest.test_case "only some fields emit" `Quick
            test_text_only_some_fields_emit;
        ] );
      ( "base_class_rule",
        [
          Alcotest.test_case "generates class selector" `Quick
            test_base_class_rule_generates_class_selector;
          Alcotest.test_case "empty props" `Quick
            test_base_class_rule_empty_props;
        ] );
      ( "split_css_rules",
        [
          Alcotest.test_case "single rule" `Quick test_split_css_rules_single;
          Alcotest.test_case "multiple rules" `Quick
            test_split_css_rules_multiple;
          Alcotest.test_case "empty string" `Quick test_split_css_rules_empty;
          Alcotest.test_case "three rules" `Quick
            test_split_css_rules_three_rules;
        ] );
      ( "normalize_key",
        [
          Alcotest.test_case "replaces class name" `Quick
            test_normalize_key_replaces_class_name;
          Alcotest.test_case "replaces all occurrences" `Quick
            test_normalize_key_replaces_all_occurrences;
          Alcotest.test_case "empty css" `Quick test_normalize_key_empty_css;
          Alcotest.test_case "same key for identical styles" `Quick
            test_normalize_key_same_key_for_identical_styles;
        ] );
      ( "optional_layout_css",
        [
          Alcotest.test_case "omits all for default layout" `Quick
            test_css_omits_all_for_default_layout;
          Alcotest.test_case "emits direction when set" `Quick
            test_css_emits_direction_when_set;
          Alcotest.test_case "emits only set fields" `Quick
            test_css_emits_only_set_fields;
          Alcotest.test_case "emits multiple set fields" `Quick
            test_css_emits_multiple_set_fields;
          Alcotest.test_case "partial padding emits individual" `Quick
            test_css_partial_padding_emits_individual;
        ] );
    ]

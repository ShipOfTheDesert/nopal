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

(* find_prop stops at the first match, so check_has_prop passes even when a
   property is declared twice. Counting is the only way to see a duplicate. *)
let count_prop name props =
  List.length (List.filter (fun p -> String.equal p.property name) props)

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
          shadow =
            Some
              { x = 2.; y = 4.; blur = 6.; spread = 0.; color = rgba 0 0 0 0.5 };
        })
      default
  in
  let props = of_style style in
  check_has_prop "box-shadow" "2px 4px 6px rgba(0,0,0,0.5)" props

(* The CSS grammar reads the lengths positionally, so a spread written in any
   slot but the fourth is silently a different declaration: put third, it becomes
   the blur and the authored blur becomes the spread. The whole value is asserted
   as one string rather than by substring presence, because a substring match
   goes green on a declaration carrying the right token in the wrong slot. *)
let test_shadow_spread_emits_fourth_length () =
  let style =
    with_paint
      (fun p ->
        {
          p with
          shadow =
            Some
              { x = 2.; y = 4.; blur = 6.; spread = 8.; color = rgba 0 0 0 0.5 };
        })
      default
  in
  let props = of_style style in
  check_has_prop "box-shadow" "2px 4px 6px 8px rgba(0,0,0,0.5)" props

(* The focus-ring shape, which is the whole reason spread exists: no offset, no
   blur, a ring of uniform thickness around the border box. One builder serves
   every spread the cases below read, so a result there is caused by the value
   passed in rather than by a fixture that differs in some other field. *)
let ring spread =
  with_paint
    (fun p ->
      {
        p with
        shadow =
          Some { x = 0.; y = 0.; blur = 0.; spread; color = rgba 0 0 0 0.5 };
      })
    default

(* The contracting direction, which style_css.mli promises is emitted rather
   than clamped or dropped. It is the arm the sign handling can break on its
   own, so the whole declaration is asserted: a spread that lost its sign is
   still four lengths in grammar order and would pass any weaker check. *)
let test_shadow_negative_spread_emits_fourth_length () =
  check_has_prop "box-shadow" "0px 0px 0px -2px rgba(0,0,0,0.5)"
    (of_style (ring (-2.)))

let test_shadow_zero_spread_omits_fourth_length () =
  check_has_prop "box-shadow" "0px 0px 0px 3px rgba(0,0,0,0.5)"
    (of_style (ring 3.));
  check_has_prop "box-shadow" "0px 0px 0px rgba(0,0,0,0.5)" (of_style (ring 0.))

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

let test_wrap_false_produces_nowrap () =
  let style = with_layout (fun l -> { l with wrap = Some false }) default in
  let props = of_style style in
  check_has_prop "flex-wrap" "nowrap" props

let test_wrap_none_omits_property () =
  let style =
    with_layout (fun l -> { l with gap = Some 1.; wrap = None }) default
  in
  let props = of_style style in
  check_no_prop "flex-wrap" props

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

(* Every field is spelled out rather than taken from Nopal_style.Text.default:
   the four axes under test are set explicitly on every row, and a field added
   to Text.t later has to be named here instead of joining the sweep silently. *)
let text_style_with ~whitespace ~text_overflow ~figure_spacing ~figure_style =
  {
    Nopal_style.Text.font_family = None;
    font_size = None;
    font_weight = None;
    line_height = None;
    letter_spacing = None;
    text_align = None;
    text_decoration = None;
    text_transform = None;
    text_overflow;
    italic = None;
    color = None;
    whitespace;
    figure_spacing;
    figure_style;
  }

let whitespace_row_label whitespace text_overflow =
  let ws =
    match whitespace with
    | None -> "whitespace=None"
    | Some Nopal_style.Text.Collapse -> "whitespace=Collapse"
    | Some Nopal_style.Text.Preserve -> "whitespace=Preserve"
  in
  let ov =
    match text_overflow with
    | None -> "text_overflow=None"
    | Some Nopal_style.Text.Clip -> "text_overflow=Clip"
    | Some Nopal_style.Text.Ellipsis -> "text_overflow=Ellipsis"
    | Some Nopal_style.Text.Wrap -> "text_overflow=Wrap"
    | Some Nopal_style.Text.No_wrap -> "text_overflow=No_wrap"
  in
  ws ^ " " ^ ov

(* Every combination of the two axes and the one white-space value each must
   produce. Fifteen rows rather than one case per axis, so their join is pinned
   and not just each axis on its own. *)
let whitespace_resolution_table =
  let open Nopal_style.Text in
  [
    (None, None, None);
    (None, Some Clip, None);
    (None, Some Wrap, Some "normal");
    (None, Some No_wrap, Some "nowrap");
    (None, Some Ellipsis, Some "nowrap");
    (Some Collapse, None, Some "normal");
    (Some Collapse, Some Clip, Some "normal");
    (Some Collapse, Some Wrap, Some "normal");
    (Some Collapse, Some No_wrap, Some "nowrap");
    (Some Collapse, Some Ellipsis, Some "nowrap");
    (Some Preserve, None, Some "pre-wrap");
    (Some Preserve, Some Clip, Some "pre-wrap");
    (Some Preserve, Some Wrap, Some "pre-wrap");
    (Some Preserve, Some No_wrap, Some "pre");
    (Some Preserve, Some Ellipsis, Some "pre");
  ]

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

let test_text_color_hex () =
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.color (Nopal_style.Color.hex "#ff8800")
  in
  let props = text_props ts in
  check_has_prop "color" "#ff8800" props;
  check_no_prop "background-color" props

let test_text_color_transparent () =
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.color Nopal_style.Color.transparent
  in
  let props = text_props ts in
  check_has_prop "color" "transparent" props

let test_text_color_rgba () =
  let fractional_alpha =
    Nopal_style.Text.default
    |> Nopal_style.Text.color (Nopal_style.Color.rgba 12 34 56 0.5)
  in
  check_has_prop "color" "rgba(12,34,56,0.5)" (text_props fractional_alpha);
  (* Alpha 1.0 must render as "1", never "1." — a trailing dot is not a valid
     CSS alpha and browsers drop the whole declaration silently. *)
  let opaque =
    Nopal_style.Text.default
    |> Nopal_style.Text.color (Nopal_style.Color.rgba 12 34 56 1.0)
  in
  check_has_prop "color" "rgba(12,34,56,1)" (text_props opaque)

let test_style_text_color () =
  let style =
    Nopal_style.Style.default
    |> with_layout (fun l -> { l with direction = Some Row_dir })
    |> with_text
         (Nopal_style.Text.color (Nopal_style.Color.named "rebeccapurple"))
  in
  let props = of_style style in
  check_has_prop "flex-direction" "row" props;
  check_has_prop "color" "rebeccapurple" props

(* of_style gates the whole text block behind [Text.equal … default], so a field
   reached through [Style.with_text] is only emitted if that gate registers the
   change. This is the path the kitchen sink's preserving container takes, and
   the mechanism a preserved-whitespace container depends on; without this case
   it is pinned only in a browser. *)
let test_style_text_whitespace () =
  let style =
    Nopal_style.Style.default
    |> with_layout (fun l -> { l with direction = Some Row_dir })
    |> with_text (Nopal_style.Text.whitespace Nopal_style.Text.Preserve)
  in
  let props = of_style style in
  check_has_prop "flex-direction" "row" props;
  check_has_prop "white-space" "pre-wrap" props

(* The same gate for the other pair of fields. [Style.with_text] is the
   whole-container shape a consumer reaches for when a table's digits have to
   line up, and it is the shape the kitchen sink's inheriting container is
   written in; every other figures fixture in this file calls [of_text]
   directly, which cannot reach this gate at all. Both axes are exercised
   because a gate could register a change on one field and miss the other. *)
let test_style_text_figures () =
  let spacing_only =
    Nopal_style.Style.default
    |> with_layout (fun l -> { l with direction = Some Row_dir })
    |> with_text (Nopal_style.Text.figure_spacing Nopal_style.Text.Tabular)
  in
  let spacing_props = of_style spacing_only in
  (* The layout property comes from a fold this gate cannot suppress, so it
     tells a gate that dropped the text block apart from a fixture that reached
     of_style and produced nothing at all. *)
  check_has_prop "flex-direction" "row" spacing_props;
  check_has_prop "font-variant-numeric" "tabular-nums" spacing_props;
  let style_only =
    Nopal_style.Style.default
    |> with_layout (fun l -> { l with direction = Some Row_dir })
    |> with_text (Nopal_style.Text.figure_style Nopal_style.Text.Oldstyle)
  in
  let style_props = of_style style_only in
  check_has_prop "flex-direction" "row" style_props;
  check_has_prop "font-variant-numeric" "oldstyle-nums" style_props

let test_of_text_preserve_alone_wraps () =
  let props =
    text_props
      (text_style_with ~whitespace:(Some Nopal_style.Text.Preserve)
         ~text_overflow:None ~figure_spacing:None ~figure_style:None)
  in
  (* Declaring the whitespace significant must not also take line breaking
     away: that stays with text_overflow. *)
  check_has_prop "white-space" "pre-wrap" props;
  Alcotest.(check int) "exactly one property" 1 (List.length props)

let test_of_text_preserve_with_no_wrap () =
  (* Written through the public builders because this is the shape a consumer
     writes, and the only place the builders and the emit site meet. *)
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.whitespace Nopal_style.Text.Preserve
    |> Nopal_style.Text.text_overflow Nopal_style.Text.No_wrap
  in
  let props = text_props ts in
  check_has_prop "white-space" "pre" props;
  Alcotest.(check int)
    "one white-space declaration" 1
    (count_prop "white-space" props)

let test_of_text_preserve_with_ellipsis () =
  let props =
    text_props
      (text_style_with ~whitespace:(Some Nopal_style.Text.Preserve)
         ~text_overflow:(Some Nopal_style.Text.Ellipsis) ~figure_spacing:None
         ~figure_style:None)
  in
  check_has_prop "text-overflow" "ellipsis" props;
  check_has_prop "overflow" "hidden" props;
  check_has_prop "white-space" "pre" props;
  Alcotest.(check int)
    "one white-space declaration" 1
    (count_prop "white-space" props)

let test_of_text_collapse_is_expressible () =
  let collapse_alone =
    text_props
      (text_style_with ~whitespace:(Some Nopal_style.Text.Collapse)
         ~text_overflow:None ~figure_spacing:None ~figure_style:None)
  in
  check_has_prop "white-space" "normal" collapse_alone;
  Alcotest.(check int) "exactly one property" 1 (List.length collapse_alone);
  (* Collapse is not the same as leaving the field unset: an unset field emits
     nothing, which cannot override an inherited preserving ancestor. *)
  let unset =
    text_props
      (text_style_with ~whitespace:None ~text_overflow:None ~figure_spacing:None
         ~figure_style:None)
  in
  check_no_prop "white-space" unset;
  let collapse_no_wrap =
    text_props
      (text_style_with ~whitespace:(Some Nopal_style.Text.Collapse)
         ~text_overflow:(Some Nopal_style.Text.No_wrap) ~figure_spacing:None
         ~figure_style:None)
  in
  check_has_prop "white-space" "nowrap" collapse_no_wrap

let test_of_text_emits_whitespace_declaration_at_most_once () =
  List.iter
    (fun (whitespace, text_overflow, expected) ->
      let props =
        text_props
          (text_style_with ~whitespace ~text_overflow ~figure_spacing:None
             ~figure_style:None)
      in
      let label = whitespace_row_label whitespace text_overflow in
      Alcotest.(check int)
        (label ^ " — white-space occurrences")
        (match expected with
        | None -> 0
        | Some _ -> 1)
        (count_prop "white-space" props);
      match expected with
      | None -> ()
      | Some value -> check_has_prop "white-space" value props)
    whitespace_resolution_table

(* ── Numeric figure tests ── *)

(* The two figure axes with no other text field set, so a declaration in the
   result can only have come from the figure fold. Both axes are named at every
   call site; nothing here is inherited from a default. *)
let figures_only ~figure_spacing ~figure_style =
  text_style_with ~whitespace:None ~text_overflow:None ~figure_spacing
    ~figure_style

let figures_row_label figure_spacing figure_style =
  let sp =
    match figure_spacing with
    | None -> "figure_spacing=None"
    | Some Nopal_style.Text.Tabular -> "figure_spacing=Tabular"
    | Some Nopal_style.Text.Proportional -> "figure_spacing=Proportional"
    | Some Nopal_style.Text.Normal_spacing -> "figure_spacing=Normal_spacing"
  in
  let st =
    match figure_style with
    | None -> "figure_style=None"
    | Some Nopal_style.Text.Lining -> "figure_style=Lining"
    | Some Nopal_style.Text.Oldstyle -> "figure_style=Oldstyle"
    | Some Nopal_style.Text.Normal_style -> "figure_style=Normal_style"
  in
  sp ^ " " ^ st

(* Every combination of the two axes and the one declaration each must produce.
   Sixteen rows rather than one case per axis, so their join is pinned and not
   just each axis on its own. The expected values are written from the stated
   resolution rule — each set, non-default axis contributes one keyword, spacing
   before style, and a pair contributing none still emits the reset while both
   unset emits nothing — never read back off the emitter. *)
let figures_resolution_table =
  let open Nopal_style.Text in
  [
    (None, None, None);
    (None, Some Lining, Some "lining-nums");
    (None, Some Oldstyle, Some "oldstyle-nums");
    (None, Some Normal_style, Some "normal");
    (Some Tabular, None, Some "tabular-nums");
    (Some Tabular, Some Lining, Some "tabular-nums lining-nums");
    (Some Tabular, Some Oldstyle, Some "tabular-nums oldstyle-nums");
    (Some Tabular, Some Normal_style, Some "tabular-nums");
    (Some Proportional, None, Some "proportional-nums");
    (Some Proportional, Some Lining, Some "proportional-nums lining-nums");
    (Some Proportional, Some Oldstyle, Some "proportional-nums oldstyle-nums");
    (Some Proportional, Some Normal_style, Some "proportional-nums");
    (Some Normal_spacing, None, Some "normal");
    (Some Normal_spacing, Some Lining, Some "lining-nums");
    (Some Normal_spacing, Some Oldstyle, Some "oldstyle-nums");
    (Some Normal_spacing, Some Normal_style, Some "normal");
  ]

let test_of_text_emits_each_figure_axis () =
  let open Nopal_style.Text in
  List.iter
    (fun (figure_spacing, figure_style, expected) ->
      let props = text_props (figures_only ~figure_spacing ~figure_style) in
      check_has_prop "font-variant-numeric" expected props;
      (* One axis set must reach its own keyword and nothing else: a resolution
         that read the neighbouring field would still produce a declaration. *)
      Alcotest.(check int)
        (figures_row_label figure_spacing figure_style ^ " — one property")
        1 (List.length props))
    [
      (Some Tabular, None, "tabular-nums");
      (Some Proportional, None, "proportional-nums");
      (None, Some Lining, "lining-nums");
      (None, Some Oldstyle, "oldstyle-nums");
    ]

let test_of_text_composes_both_figure_axes () =
  let open Nopal_style.Text in
  let both =
    text_props
      (figures_only ~figure_spacing:(Some Tabular) ~figure_style:(Some Oldstyle))
  in
  (* The whole declaration, not a substring and not a membership check: the
     keyword order is pinned by nothing else, and no single-axis case can pin
     it. A fold that emitted style before spacing passes every other case. *)
  check_has_prop "font-variant-numeric" "tabular-nums oldstyle-nums" both;
  Alcotest.(check int)
    "one figures declaration" 1
    (count_prop "font-variant-numeric" both);
  let other_pair =
    text_props
      (figures_only ~figure_spacing:(Some Proportional)
         ~figure_style:(Some Lining))
  in
  check_has_prop "font-variant-numeric" "proportional-nums lining-nums"
    other_pair;
  (* Written through the public builders because this is the shape a consumer
     writes, and the only place the builders and the emit site meet. The record
     they start from is all-unset, which test_text_none_fields_no_css pins. *)
  let built =
    Nopal_style.Text.default
    |> Nopal_style.Text.figure_spacing Tabular
    |> Nopal_style.Text.figure_style Lining
  in
  check_has_prop "font-variant-numeric" "tabular-nums lining-nums"
    (text_props built)

let test_of_text_emits_figures_at_most_once () =
  List.iter
    (fun (figure_spacing, figure_style, expected) ->
      let props = text_props (figures_only ~figure_spacing ~figure_style) in
      let label = figures_row_label figure_spacing figure_style in
      Alcotest.(check int)
        (label ^ " — font-variant-numeric occurrences")
        (match expected with
        | None -> 0
        | Some _ -> 1)
        (count_prop "font-variant-numeric" props);
      match expected with
      | None -> ()
      | Some value -> check_has_prop "font-variant-numeric" value props)
    figures_resolution_table

let test_of_text_figures_default_emits_reset () =
  let open Nopal_style.Text in
  (* The property inherits, so an element under one that set an axis has no
     other way back to the typeface's own figures. The explicit default is that
     way back, and it only works if it emits. *)
  let spacing_default =
    text_props
      (figures_only ~figure_spacing:(Some Normal_spacing) ~figure_style:None)
  in
  check_has_prop "font-variant-numeric" "normal" spacing_default;
  let style_default =
    text_props
      (figures_only ~figure_spacing:None ~figure_style:(Some Normal_style))
  in
  check_has_prop "font-variant-numeric" "normal" style_default;
  let both_default =
    text_props
      (figures_only ~figure_spacing:(Some Normal_spacing)
         ~figure_style:(Some Normal_style))
  in
  check_has_prop "font-variant-numeric" "normal" both_default;
  Alcotest.(check int)
    "one declaration when both axes are the default" 1
    (count_prop "font-variant-numeric" both_default);
  (* A defaulted axis contributes no keyword of its own and must not suppress
     its sibling's. *)
  let default_with_sibling =
    text_props
      (figures_only ~figure_spacing:(Some Normal_spacing)
         ~figure_style:(Some Lining))
  in
  check_has_prop "font-variant-numeric" "lining-nums" default_with_sibling;
  (* Distinct from leaving the axis unset, which emits nothing at all and so
     cannot override an inherited ancestor. *)
  check_no_prop "font-variant-numeric"
    (text_props (figures_only ~figure_spacing:None ~figure_style:None))

let test_of_text_unset_figures_emits_nothing () =
  let unset =
    text_props (figures_only ~figure_spacing:None ~figure_style:None)
  in
  check_no_prop "font-variant-numeric" unset;
  Alcotest.(check int) "no properties at all" 0 (List.length unset);
  (* Affirmative arm on the same fixture: the absence above passes just as well
     if the fold is never reached at all, so the fixture has to be shown able to
     produce the property. *)
  let set =
    text_props
      (figures_only ~figure_spacing:(Some Nopal_style.Text.Tabular)
         ~figure_style:None)
  in
  check_has_prop "font-variant-numeric" "tabular-nums" set

let test_of_text_whitespace_unaffected () =
  let open Nopal_style.Text in
  (* The two folds share of_text and nothing else. A set figure axis must leave
     the whitespace pair resolving exactly as it did, and must not add a
     white-space of its own. *)
  let both =
    text_props
      (text_style_with ~whitespace:(Some Preserve) ~text_overflow:(Some No_wrap)
         ~figure_spacing:(Some Tabular) ~figure_style:(Some Oldstyle))
  in
  check_has_prop "white-space" "pre" both;
  Alcotest.(check int)
    "one white-space declaration" 1
    (count_prop "white-space" both);
  check_has_prop "font-variant-numeric" "tabular-nums oldstyle-nums" both;
  Alcotest.(check int)
    "one figures declaration" 1
    (count_prop "font-variant-numeric" both);
  (* And the other direction: with both whitespace axes unset, a set figure axis
     leaves white-space unemitted, exactly as before these fields existed. *)
  check_no_prop "white-space"
    (text_props
       (figures_only ~figure_spacing:(Some Tabular) ~figure_style:None))

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
          position = None;
          top = None;
          right = None;
          bottom = None;
          left = None;
          z_index = None;
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
          Alcotest.test_case "shadow spread emits fourth length" `Quick
            test_shadow_spread_emits_fourth_length;
          Alcotest.test_case "shadow negative spread emits fourth length" `Quick
            test_shadow_negative_spread_emits_fourth_length;
          Alcotest.test_case "shadow zero spread omits fourth length" `Quick
            test_shadow_zero_spread_omits_fourth_length;
          Alcotest.test_case "gap produces css" `Quick test_gap_produces_css;
          Alcotest.test_case "flex grow produces css" `Quick
            test_flex_grow_produces_css;
          Alcotest.test_case "align center produces css" `Quick
            test_align_center_produces_css;
          Alcotest.test_case "cross align stretch produces css" `Quick
            test_cross_align_stretch_produces_css;
          Alcotest.test_case "wrap produces css" `Quick test_wrap_produces_css;
          Alcotest.test_case "wrap false produces nowrap" `Quick
            test_wrap_false_produces_nowrap;
          Alcotest.test_case "wrap none omits property" `Quick
            test_wrap_none_omits_property;
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
          Alcotest.test_case "color hex" `Quick test_text_color_hex;
          Alcotest.test_case "color transparent" `Quick
            test_text_color_transparent;
          Alcotest.test_case "color rgba" `Quick test_text_color_rgba;
          Alcotest.test_case "color through style text" `Quick
            test_style_text_color;
          Alcotest.test_case "whitespace through style text" `Quick
            test_style_text_whitespace;
          Alcotest.test_case "figures through style text" `Quick
            test_style_text_figures;
          Alcotest.test_case "preserve alone wraps" `Quick
            test_of_text_preserve_alone_wraps;
          Alcotest.test_case "preserve with no wrap" `Quick
            test_of_text_preserve_with_no_wrap;
          Alcotest.test_case "preserve with ellipsis" `Quick
            test_of_text_preserve_with_ellipsis;
          Alcotest.test_case "collapse is expressible" `Quick
            test_of_text_collapse_is_expressible;
          Alcotest.test_case "whitespace declaration at most once" `Quick
            test_of_text_emits_whitespace_declaration_at_most_once;
          Alcotest.test_case "emits each figure axis" `Quick
            test_of_text_emits_each_figure_axis;
          Alcotest.test_case "composes both figure axes" `Quick
            test_of_text_composes_both_figure_axes;
          Alcotest.test_case "figures declaration at most once" `Quick
            test_of_text_emits_figures_at_most_once;
          Alcotest.test_case "figures default emits reset" `Quick
            test_of_text_figures_default_emits_reset;
          Alcotest.test_case "unset figures emit nothing" `Quick
            test_of_text_unset_figures_emits_nothing;
          Alcotest.test_case "whitespace unaffected by figures" `Quick
            test_of_text_whitespace_unaffected;
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

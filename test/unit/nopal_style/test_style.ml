open Nopal_style.Style

(* --- Default layout tests --- *)

let test_default_layout_values () =
  Alcotest.(check bool)
    "direction is None" true
    (Option.is_none default_layout.direction);
  Alcotest.(check bool)
    "main_align is None" true
    (Option.is_none default_layout.main_align);
  Alcotest.(check bool)
    "cross_align is None" true
    (Option.is_none default_layout.cross_align);
  Alcotest.(check bool) "wrap is None" true (Option.is_none default_layout.wrap);
  Alcotest.(check bool) "gap is None" true (Option.is_none default_layout.gap);
  Alcotest.(check bool)
    "padding_top is None" true
    (Option.is_none default_layout.padding_top);
  Alcotest.(check bool)
    "padding_right is None" true
    (Option.is_none default_layout.padding_right);
  Alcotest.(check bool)
    "padding_bottom is None" true
    (Option.is_none default_layout.padding_bottom);
  Alcotest.(check bool)
    "padding_left is None" true
    (Option.is_none default_layout.padding_left);
  Alcotest.(check bool)
    "width is None" true
    (Option.is_none default_layout.width);
  Alcotest.(check bool)
    "height is None" true
    (Option.is_none default_layout.height);
  Alcotest.(check (option (float 0.001)))
    "flex_grow is None" None default_layout.flex_grow;
  Alcotest.(check bool)
    "position is None" true
    (Option.is_none default_layout.position);
  Alcotest.(check bool) "top is None" true (Option.is_none default_layout.top);
  Alcotest.(check bool)
    "right is None" true
    (Option.is_none default_layout.right);
  Alcotest.(check bool)
    "bottom is None" true
    (Option.is_none default_layout.bottom);
  Alcotest.(check bool) "left is None" true (Option.is_none default_layout.left);
  Alcotest.(check bool)
    "z_index is None" true
    (Option.is_none default_layout.z_index)

(* --- Default paint tests --- *)

let test_default_paint_values () =
  Alcotest.(check bool)
    "background is None" true
    (match default_paint.background with
    | None -> true
    | Some _ -> false);
  Alcotest.(check bool)
    "border is None" true
    (match default_paint.border with
    | None -> true
    | Some _ -> false);
  Alcotest.(check (float 0.001)) "opacity is 1.0" 1.0 default_paint.opacity;
  Alcotest.(check bool)
    "shadow is None" true
    (match default_paint.shadow with
    | None -> true
    | Some _ -> false);
  Alcotest.(check string)
    "overflow is Visible" "Visible"
    (match default_paint.overflow with
    | Visible -> "Visible"
    | Hidden -> "Hidden")

(* --- Default style test --- *)

let test_default_style_is_defaults () =
  Alcotest.(check bool)
    "default.layout is default_layout" true
    (equal_layout default.layout default_layout);
  Alcotest.(check bool)
    "default.paint is default_paint" true
    (equal_paint default.paint default_paint)

(* --- Size value tests --- *)

let test_size_fill () =
  let l = { default_layout with width = Some Fill } in
  Alcotest.(check string)
    "Fill assigned" "Fill"
    (match l.width with
    | Some Fill -> "Fill"
    | Some Hug
    | Some (Fixed _)
    | Some (Fraction _)
    | None ->
        "other")

let test_size_hug () =
  let l = { default_layout with width = Some Hug } in
  Alcotest.(check string)
    "Hug assigned" "Hug"
    (match l.width with
    | Some Hug -> "Hug"
    | Some Fill
    | Some (Fixed _)
    | Some (Fraction _)
    | None ->
        "other")

let test_size_fixed () =
  let l = { default_layout with width = Some (Fixed 100.) } in
  Alcotest.(check (float 0.001))
    "Fixed carries value" 100.
    (match l.width with
    | Some (Fixed v) -> v
    | Some Fill
    | Some Hug
    | Some (Fraction _)
    | None ->
        -1.)

let test_size_fraction () =
  let l = { default_layout with width = Some (Fraction 0.5) } in
  Alcotest.(check (float 0.001))
    "Fraction carries value" 0.5
    (match l.width with
    | Some (Fraction v) -> v
    | Some Fill
    | Some Hug
    | Some (Fixed _)
    | None ->
        -1.)

(* --- Color value tests --- *)

let test_color_rgba () =
  let c = rgba 255 0 0 1.0 in
  match c with
  | Rgba { r; g; b; a } ->
      Alcotest.(check int) "r" 255 r;
      Alcotest.(check int) "g" 0 g;
      Alcotest.(check int) "b" 0 b;
      Alcotest.(check (float 0.001)) "a" 1.0 a
  | Hex _
  | Named _
  | Transparent ->
      Alcotest.fail "expected Rgba"

let test_color_hex () =
  let c = hex "#ff0000" in
  match c with
  | Hex s -> Alcotest.(check string) "hex value" "#ff0000" s
  | Rgba _
  | Named _
  | Transparent ->
      Alcotest.fail "expected Hex"

let test_color_named () =
  let c = named "red" in
  match c with
  | Named s -> Alcotest.(check string) "named value" "red" s
  | Rgba _
  | Hex _
  | Transparent ->
      Alcotest.fail "expected Named"

let test_color_transparent () =
  match transparent with
  | Transparent -> ()
  | Rgba _
  | Hex _
  | Named _ ->
      Alcotest.fail "expected Transparent"

(* --- Border style tests --- *)

let test_border_style_variants () =
  let styles = [ Solid; Dashed; Dotted; No_border ] in
  Alcotest.(check int) "four variants" 4 (List.length styles);
  Alcotest.(check bool)
    "all distinct" true
    (let unique =
       List.sort_uniq
         (fun a b ->
           match (a, b) with
           | Solid, Solid -> 0
           | Solid, _ -> -1
           | _, Solid -> 1
           | Dashed, Dashed -> 0
           | Dashed, _ -> -1
           | _, Dashed -> 1
           | Dotted, Dotted -> 0
           | Dotted, _ -> -1
           | _, Dotted -> 1
           | No_border, No_border -> 0)
         styles
     in
     List.length unique = List.length styles)

let test_default_border_values () =
  Alcotest.(check (float 0.001)) "width is 0." 0. default_border.width;
  (match default_border.style with
  | No_border -> ()
  | Solid
  | Dashed
  | Dotted ->
      Alcotest.fail "expected No_border");
  (match default_border.color with
  | Transparent -> ()
  | Rgba _
  | Hex _
  | Named _ ->
      Alcotest.fail "expected Transparent");
  Alcotest.(check (float 0.001)) "radius is 0." 0. default_border.radius

(* --- Default shadow tests --- *)

let test_default_shadow_values () =
  Alcotest.(check (float 0.001)) "x is 0." 0. default_shadow.x;
  Alcotest.(check (float 0.001)) "y is 0." 0. default_shadow.y;
  Alcotest.(check (float 0.001)) "blur is 0." 0. default_shadow.blur;
  match default_shadow.color with
  | Transparent -> ()
  | Rgba _
  | Hex _
  | Named _ ->
      Alcotest.fail "expected Transparent"

(* --- Update function tests --- *)

let test_with_layout_returns_new_style () =
  let s = with_layout (fun l -> { l with gap = Some 10. }) default in
  Alcotest.(check bool) "not same reference" true (s != default);
  Alcotest.(check bool)
    "gap changed" true
    (match s.layout.gap with
    | Some v -> Float.equal v 10.
    | None -> false)

let test_with_layout_applies_fn () =
  let s =
    with_layout
      (fun l -> { l with direction = Some Row_dir; wrap = Some true })
      default
  in
  Alcotest.(check string)
    "direction is Row_dir" "Row_dir"
    (match s.layout.direction with
    | Some Row_dir -> "Row_dir"
    | Some Column_dir -> "Column_dir"
    | None -> "None");
  Alcotest.(check bool)
    "wrap is Some true" true
    (match s.layout.wrap with
    | Some true -> true
    | _ -> false)

let test_with_paint_returns_new_style () =
  let s = with_paint (fun p -> { p with opacity = 0.5 }) default in
  Alcotest.(check bool) "not same reference" true (s != default);
  Alcotest.(check (float 0.001)) "opacity changed" 0.5 s.paint.opacity

let test_with_paint_applies_fn () =
  let bg = Some (rgba 255 0 0 1.0) in
  let s =
    with_paint (fun p -> { p with background = bg; overflow = Hidden }) default
  in
  Alcotest.(check bool)
    "background is Some" true
    (match s.paint.background with
    | Some _ -> true
    | None -> false);
  Alcotest.(check string)
    "overflow is Hidden" "Hidden"
    (match s.paint.overflow with
    | Hidden -> "Hidden"
    | Visible -> "Visible")

let test_set_layout_replaces () =
  let new_layout = { default_layout with gap = Some 42. } in
  let s = set_layout new_layout default in
  Alcotest.(check bool)
    "layout replaced" true
    (match s.layout.gap with
    | Some v -> Float.equal v 42.
    | None -> false);
  Alcotest.(check (float 0.001)) "paint unchanged" 1.0 s.paint.opacity

let test_set_paint_replaces () =
  let new_paint = { default_paint with opacity = 0.3 } in
  let s = set_paint new_paint default in
  Alcotest.(check (float 0.001)) "paint replaced" 0.3 s.paint.opacity;
  Alcotest.(check bool)
    "layout unchanged (direction is None)" true
    (Option.is_none s.layout.direction)

let test_original_unchanged_after_with_layout () =
  let original = default in
  let _modified = with_layout (fun l -> { l with gap = Some 99. }) original in
  Alcotest.(check bool)
    "original gap unchanged (None)" true
    (Option.is_none original.layout.gap)

let test_original_unchanged_after_with_paint () =
  let original = default in
  let _modified = with_paint (fun p -> { p with opacity = 0.1 }) original in
  Alcotest.(check (float 0.001))
    "original opacity unchanged" 1.0 original.paint.opacity

(* --- Padding helper tests --- *)

let test_padding_sets_four_sides () =
  let l = padding 1. 2. 3. 4. default_layout in
  Alcotest.(check (option (float 0.001))) "top" (Some 1.) l.padding_top;
  Alcotest.(check (option (float 0.001))) "right" (Some 2.) l.padding_right;
  Alcotest.(check (option (float 0.001))) "bottom" (Some 3.) l.padding_bottom;
  Alcotest.(check (option (float 0.001))) "left" (Some 4.) l.padding_left

let test_padding_all_sets_uniform () =
  let l = padding_all 8. default_layout in
  Alcotest.(check (option (float 0.001))) "top" (Some 8.) l.padding_top;
  Alcotest.(check (option (float 0.001))) "right" (Some 8.) l.padding_right;
  Alcotest.(check (option (float 0.001))) "bottom" (Some 8.) l.padding_bottom;
  Alcotest.(check (option (float 0.001))) "left" (Some 8.) l.padding_left

(* --- Equality tests --- *)

let test_equal_default_default () =
  Alcotest.(check bool) "default = default" true (equal default default)

let test_equal_different_layout () =
  let s = with_layout (fun l -> { l with gap = Some 5. }) default in
  Alcotest.(check bool) "different layout" false (equal default s)

let test_equal_different_paint () =
  let s = with_paint (fun p -> { p with opacity = 0.5 }) default in
  Alcotest.(check bool) "different paint" false (equal default s)

let test_equal_color_rgba_same () =
  Alcotest.(check bool)
    "same rgba" true
    (equal_color (rgba 255 0 0 1.0) (rgba 255 0 0 1.0))

let test_equal_color_rgba_different () =
  Alcotest.(check bool)
    "different rgba" false
    (equal_color (rgba 255 0 0 1.0) (rgba 0 255 0 1.0))

let test_equal_color_different_variants () =
  Alcotest.(check bool)
    "rgba vs hex" false
    (equal_color (rgba 255 0 0 1.0) (hex "#ff0000"))

let test_equal_layout_same () =
  let l1 = { default_layout with gap = Some 10.; direction = Some Row_dir } in
  let l2 = { default_layout with gap = Some 10.; direction = Some Row_dir } in
  Alcotest.(check bool) "same layout" true (equal_layout l1 l2)

let test_equal_paint_same () =
  let p1 = { default_paint with opacity = 0.7 } in
  let p2 = { default_paint with opacity = 0.7 } in
  Alcotest.(check bool) "same paint" true (equal_paint p1 p2)

(* --- Text integration tests --- *)

let test_default_text_is_text_default () =
  Alcotest.(check bool)
    "default.text is Text.default" true
    (Nopal_style.Text.equal default.text Nopal_style.Text.default)

let test_with_text_applies_fn () =
  let s = with_text (fun t -> Nopal_style.Text.font_size 16.0 t) default in
  Alcotest.(check bool)
    "font_size set" true
    (match s.text.Nopal_style.Text.font_size with
    | Some v -> Float.equal v 16.0
    | None -> false)

let test_with_text_preserves_layout_paint () =
  let s = with_text (fun t -> Nopal_style.Text.font_size 16.0 t) default in
  Alcotest.(check bool)
    "layout unchanged" true
    (equal_layout s.layout default_layout);
  Alcotest.(check bool)
    "paint unchanged" true
    (equal_paint s.paint default_paint)

let test_set_text_replaces () =
  let custom_text =
    Nopal_style.Text.default
    |> Nopal_style.Text.font_size 24.0
    |> Nopal_style.Text.italic true
  in
  let s = set_text custom_text default in
  Alcotest.(check bool)
    "text replaced" true
    (Nopal_style.Text.equal s.text custom_text)

let test_equal_different_text () =
  let s =
    with_text
      (fun t -> Nopal_style.Text.font_weight Nopal_style.Font.Bold t)
      default
  in
  Alcotest.(check bool) "different text means not equal" false (equal default s)

let test_backward_compat_default_layout_paint () =
  Alcotest.(check bool)
    "default still has correct layout" true
    (equal_layout default.layout default_layout);
  Alcotest.(check bool)
    "default still has correct paint" true
    (equal_paint default.paint default_paint)

(* --- Optional layout fields tests --- *)

let test_default_layout_all_none () =
  Alcotest.(check bool)
    "direction is None" true
    (Option.is_none default_layout.direction);
  Alcotest.(check bool)
    "main_align is None" true
    (Option.is_none default_layout.main_align);
  Alcotest.(check bool)
    "cross_align is None" true
    (Option.is_none default_layout.cross_align);
  Alcotest.(check bool) "wrap is None" true (Option.is_none default_layout.wrap);
  Alcotest.(check bool) "gap is None" true (Option.is_none default_layout.gap);
  Alcotest.(check bool)
    "padding_top is None" true
    (Option.is_none default_layout.padding_top);
  Alcotest.(check bool)
    "padding_right is None" true
    (Option.is_none default_layout.padding_right);
  Alcotest.(check bool)
    "padding_bottom is None" true
    (Option.is_none default_layout.padding_bottom);
  Alcotest.(check bool)
    "padding_left is None" true
    (Option.is_none default_layout.padding_left);
  Alcotest.(check bool)
    "width is None" true
    (Option.is_none default_layout.width);
  Alcotest.(check bool)
    "height is None" true
    (Option.is_none default_layout.height);
  Alcotest.(check bool)
    "flex_grow is None" true
    (Option.is_none default_layout.flex_grow);
  Alcotest.(check bool)
    "position is None" true
    (Option.is_none default_layout.position);
  Alcotest.(check bool) "top is None" true (Option.is_none default_layout.top);
  Alcotest.(check bool)
    "right is None" true
    (Option.is_none default_layout.right);
  Alcotest.(check bool)
    "bottom is None" true
    (Option.is_none default_layout.bottom);
  Alcotest.(check bool) "left is None" true (Option.is_none default_layout.left);
  Alcotest.(check bool)
    "z_index is None" true
    (Option.is_none default_layout.z_index)

let test_padding_helpers_wrap_some () =
  let l = padding 1. 2. 3. 4. default_layout in
  Alcotest.(check bool)
    "padding_top is Some 1." true
    (match l.padding_top with
    | Some v -> Float.equal v 1.
    | None -> false);
  Alcotest.(check bool)
    "padding_right is Some 2." true
    (match l.padding_right with
    | Some v -> Float.equal v 2.
    | None -> false);
  Alcotest.(check bool)
    "padding_bottom is Some 3." true
    (match l.padding_bottom with
    | Some v -> Float.equal v 3.
    | None -> false);
  Alcotest.(check bool)
    "padding_left is Some 4." true
    (match l.padding_left with
    | Some v -> Float.equal v 4.
    | None -> false);
  let l2 = padding_all 8. default_layout in
  Alcotest.(check bool)
    "padding_all top is Some 8." true
    (match l2.padding_top with
    | Some v -> Float.equal v 8.
    | None -> false);
  Alcotest.(check bool)
    "padding_all right is Some 8." true
    (match l2.padding_right with
    | Some v -> Float.equal v 8.
    | None -> false);
  Alcotest.(check bool)
    "padding_all bottom is Some 8." true
    (match l2.padding_bottom with
    | Some v -> Float.equal v 8.
    | None -> false);
  Alcotest.(check bool)
    "padding_all left is Some 8." true
    (match l2.padding_left with
    | Some v -> Float.equal v 8.
    | None -> false)

let test_equal_layout_none_fields () =
  (* Two all-None layouts are equal *)
  Alcotest.(check bool)
    "all-None layouts equal" true
    (equal_layout default_layout default_layout);
  (* Some vs None is not equal *)
  let l = { default_layout with gap = Some 4.0 } in
  Alcotest.(check bool)
    "Some gap vs None gap" false
    (equal_layout default_layout l);
  (* Two identical Some values are equal *)
  let l1 = { default_layout with direction = Some Row_dir; gap = Some 4.0 } in
  let l2 = { default_layout with direction = Some Row_dir; gap = Some 4.0 } in
  Alcotest.(check bool) "same Some values equal" true (equal_layout l1 l2)

(* --- Position tests --- *)

let test_position_fixed () =
  let l = { default_layout with position = Some Pos_fixed } in
  Alcotest.(check bool)
    "position is Fixed" true
    (match l.position with
    | Some Pos_fixed -> true
    | Some Pos_static
    | Some Pos_relative
    | Some Pos_absolute
    | None ->
        false)

let test_position_offsets () =
  let l =
    {
      default_layout with
      position = Some Pos_absolute;
      top = Some 0.0;
      left = Some 10.0;
      z_index = Some 100;
    }
  in
  Alcotest.(check (option (float 0.001))) "top" (Some 0.0) l.top;
  Alcotest.(check (option (float 0.001))) "left" (Some 10.0) l.left;
  Alcotest.(check bool) "right is None" true (Option.is_none l.right);
  Alcotest.(check (option int)) "z_index" (Some 100) l.z_index

let test_equal_layout_position () =
  let l1 =
    { default_layout with position = Some Pos_fixed; z_index = Some 10 }
  in
  let l2 =
    { default_layout with position = Some Pos_fixed; z_index = Some 10 }
  in
  Alcotest.(check bool) "same position layouts equal" true (equal_layout l1 l2);
  let l3 =
    { default_layout with position = Some Pos_absolute; z_index = Some 10 }
  in
  Alcotest.(check bool)
    "different position layouts not equal" false
    (equal_layout l1 l3)

(* --- Test runner --- *)

let () =
  Alcotest.run "nopal_style"
    [
      ( "Default layout",
        [
          Alcotest.test_case "default_layout_values" `Quick
            test_default_layout_values;
        ] );
      ( "Default paint",
        [
          Alcotest.test_case "default_paint_values" `Quick
            test_default_paint_values;
        ] );
      ( "Default style",
        [
          Alcotest.test_case "default_style_is_defaults" `Quick
            test_default_style_is_defaults;
        ] );
      ( "Size values",
        [
          Alcotest.test_case "size_fill" `Quick test_size_fill;
          Alcotest.test_case "size_hug" `Quick test_size_hug;
          Alcotest.test_case "size_fixed" `Quick test_size_fixed;
          Alcotest.test_case "size_fraction" `Quick test_size_fraction;
        ] );
      ( "Color values",
        [
          Alcotest.test_case "color_rgba" `Quick test_color_rgba;
          Alcotest.test_case "color_hex" `Quick test_color_hex;
          Alcotest.test_case "color_named" `Quick test_color_named;
          Alcotest.test_case "color_transparent" `Quick test_color_transparent;
        ] );
      ( "Border style",
        [
          Alcotest.test_case "border_style_variants" `Quick
            test_border_style_variants;
          Alcotest.test_case "default_border_values" `Quick
            test_default_border_values;
        ] );
      ( "Default shadow",
        [
          Alcotest.test_case "default_shadow_values" `Quick
            test_default_shadow_values;
        ] );
      ( "Update functions",
        [
          Alcotest.test_case "with_layout_returns_new_style" `Quick
            test_with_layout_returns_new_style;
          Alcotest.test_case "with_layout_applies_fn" `Quick
            test_with_layout_applies_fn;
          Alcotest.test_case "with_paint_returns_new_style" `Quick
            test_with_paint_returns_new_style;
          Alcotest.test_case "with_paint_applies_fn" `Quick
            test_with_paint_applies_fn;
          Alcotest.test_case "set_layout_replaces" `Quick
            test_set_layout_replaces;
          Alcotest.test_case "set_paint_replaces" `Quick test_set_paint_replaces;
          Alcotest.test_case "original_unchanged_after_with_layout" `Quick
            test_original_unchanged_after_with_layout;
          Alcotest.test_case "original_unchanged_after_with_paint" `Quick
            test_original_unchanged_after_with_paint;
        ] );
      ( "Padding helpers",
        [
          Alcotest.test_case "padding_sets_four_sides" `Quick
            test_padding_sets_four_sides;
          Alcotest.test_case "padding_all_sets_uniform" `Quick
            test_padding_all_sets_uniform;
        ] );
      ( "Equality",
        [
          Alcotest.test_case "equal_default_default" `Quick
            test_equal_default_default;
          Alcotest.test_case "equal_different_layout" `Quick
            test_equal_different_layout;
          Alcotest.test_case "equal_different_paint" `Quick
            test_equal_different_paint;
          Alcotest.test_case "equal_color_rgba_same" `Quick
            test_equal_color_rgba_same;
          Alcotest.test_case "equal_color_rgba_different" `Quick
            test_equal_color_rgba_different;
          Alcotest.test_case "equal_color_different_variants" `Quick
            test_equal_color_different_variants;
          Alcotest.test_case "equal_layout_same" `Quick test_equal_layout_same;
          Alcotest.test_case "equal_paint_same" `Quick test_equal_paint_same;
        ] );
      ( "Optional layout fields",
        [
          Alcotest.test_case "default_layout_all_none" `Quick
            test_default_layout_all_none;
          Alcotest.test_case "padding_helpers_wrap_some" `Quick
            test_padding_helpers_wrap_some;
          Alcotest.test_case "equal_layout_none_fields" `Quick
            test_equal_layout_none_fields;
        ] );
      ( "Position",
        [
          Alcotest.test_case "position_fixed" `Quick test_position_fixed;
          Alcotest.test_case "position_offsets" `Quick test_position_offsets;
          Alcotest.test_case "equal_layout_position" `Quick
            test_equal_layout_position;
        ] );
      ( "Text integration",
        [
          Alcotest.test_case "default_text_is_text_default" `Quick
            test_default_text_is_text_default;
          Alcotest.test_case "with_text_applies_fn" `Quick
            test_with_text_applies_fn;
          Alcotest.test_case "with_text_preserves_layout_paint" `Quick
            test_with_text_preserves_layout_paint;
          Alcotest.test_case "set_text_replaces" `Quick test_set_text_replaces;
          Alcotest.test_case "equal_different_text" `Quick
            test_equal_different_text;
          Alcotest.test_case "backward_compat_default_layout_paint" `Quick
            test_backward_compat_default_layout_paint;
        ] );
    ]

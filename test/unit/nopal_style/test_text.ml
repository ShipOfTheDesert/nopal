open Nopal_style.Text

(* --- Defaults --- *)

let test_default_all_none () =
  let t = default in
  Alcotest.(check (option reject)) "font_family" None t.font_family;
  Alcotest.(check (option reject)) "font_size" None t.font_size;
  Alcotest.(check (option reject)) "font_weight" None t.font_weight;
  Alcotest.(check (option reject)) "line_height" None t.line_height;
  Alcotest.(check (option reject)) "letter_spacing" None t.letter_spacing;
  Alcotest.(check (option reject)) "text_align" None t.text_align;
  Alcotest.(check (option reject)) "text_decoration" None t.text_decoration;
  Alcotest.(check (option reject)) "text_transform" None t.text_transform;
  Alcotest.(check (option reject)) "text_overflow" None t.text_overflow;
  Alcotest.(check (option reject)) "italic" None t.italic

(* --- Builders --- *)

let test_font_family_sets () =
  let t = font_family Nopal_style.Font.Sans_serif default in
  Alcotest.(check bool)
    "font_family set" true
    (t.font_family = Some Nopal_style.Font.Sans_serif)

let test_font_size_sets () =
  let t = font_size 1.5 default in
  Alcotest.(check bool) "font_size set" true (t.font_size = Some 1.5)

let test_font_weight_sets () =
  let t = font_weight Nopal_style.Font.Bold default in
  Alcotest.(check bool)
    "font_weight set" true
    (t.font_weight = Some Nopal_style.Font.Bold)

let test_line_height_sets () =
  let t = line_height (Lh_multiplier 1.5) default in
  Alcotest.(check bool)
    "line_height set" true
    (t.line_height = Some (Lh_multiplier 1.5))

let test_letter_spacing_sets () =
  let t = letter_spacing (Ls_em 0.05) default in
  Alcotest.(check bool)
    "letter_spacing set" true
    (t.letter_spacing = Some (Ls_em 0.05))

let test_text_align_sets () =
  let t = text_align Align_center default in
  Alcotest.(check bool) "text_align set" true (t.text_align = Some Align_center)

let test_text_decoration_sets () =
  let t = text_decoration Underline default in
  Alcotest.(check bool)
    "text_decoration set" true
    (t.text_decoration = Some Underline)

let test_text_transform_sets () =
  let t = text_transform Uppercase default in
  Alcotest.(check bool)
    "text_transform set" true
    (t.text_transform = Some Uppercase)

let test_text_overflow_sets () =
  let t = text_overflow Ellipsis default in
  Alcotest.(check bool)
    "text_overflow set" true
    (t.text_overflow = Some Ellipsis)

let test_italic_sets () =
  let t = italic true default in
  Alcotest.(check bool) "italic set" true (t.italic = Some true)

let test_builders_compose () =
  let t =
    default
    |> font_family Nopal_style.Font.Monospace
    |> font_size 2.0
    |> font_weight Nopal_style.Font.Bold
    |> line_height (Lh_px 24.0)
    |> letter_spacing (Ls_em 0.1)
    |> text_align Align_right
    |> text_decoration Line_through
    |> text_transform Capitalize
    |> text_overflow No_wrap
    |> italic true
  in
  Alcotest.(check bool)
    "font_family" true
    (t.font_family = Some Nopal_style.Font.Monospace);
  Alcotest.(check bool) "font_size" true (t.font_size = Some 2.0);
  Alcotest.(check bool)
    "font_weight" true
    (t.font_weight = Some Nopal_style.Font.Bold);
  Alcotest.(check bool) "line_height" true (t.line_height = Some (Lh_px 24.0));
  Alcotest.(check bool)
    "letter_spacing" true
    (t.letter_spacing = Some (Ls_em 0.1));
  Alcotest.(check bool) "text_align" true (t.text_align = Some Align_right);
  Alcotest.(check bool)
    "text_decoration" true
    (t.text_decoration = Some Line_through);
  Alcotest.(check bool)
    "text_transform" true
    (t.text_transform = Some Capitalize);
  Alcotest.(check bool) "text_overflow" true (t.text_overflow = Some No_wrap);
  Alcotest.(check bool) "italic" true (t.italic = Some true)

let test_builder_does_not_mutate_other_fields () =
  let t = font_size 1.0 default in
  Alcotest.(check (option reject)) "font_family" None t.font_family;
  Alcotest.(check (option reject)) "font_weight" None t.font_weight;
  Alcotest.(check (option reject)) "line_height" None t.line_height;
  Alcotest.(check (option reject)) "letter_spacing" None t.letter_spacing;
  Alcotest.(check (option reject)) "text_align" None t.text_align;
  Alcotest.(check (option reject)) "text_decoration" None t.text_decoration;
  Alcotest.(check (option reject)) "text_transform" None t.text_transform;
  Alcotest.(check (option reject)) "text_overflow" None t.text_overflow;
  Alcotest.(check (option reject)) "italic" None t.italic

(* --- Line height variants --- *)

let test_line_height_normal () =
  let t = line_height Lh_normal default in
  Alcotest.(check bool) "Lh_normal" true (t.line_height = Some Lh_normal)

let test_line_height_multiplier () =
  let t = line_height (Lh_multiplier 1.6) default in
  Alcotest.(check bool)
    "Lh_multiplier 1.6" true
    (t.line_height = Some (Lh_multiplier 1.6))

let test_line_height_px () =
  let t = line_height (Lh_px 24.0) default in
  Alcotest.(check bool) "Lh_px 24.0" true (t.line_height = Some (Lh_px 24.0))

(* --- Letter spacing variants --- *)

let test_letter_spacing_normal () =
  let t = letter_spacing Ls_normal default in
  Alcotest.(check bool) "Ls_normal" true (t.letter_spacing = Some Ls_normal)

let test_letter_spacing_em () =
  let t = letter_spacing (Ls_em 0.1) default in
  Alcotest.(check bool) "Ls_em 0.1" true (t.letter_spacing = Some (Ls_em 0.1))

(* --- Text overflow variants --- *)

let test_text_overflow_clip () =
  let t = text_overflow Clip default in
  Alcotest.(check bool) "Clip" true (t.text_overflow = Some Clip)

let test_text_overflow_ellipsis () =
  let t = text_overflow Ellipsis default in
  Alcotest.(check bool) "Ellipsis" true (t.text_overflow = Some Ellipsis)

let test_text_overflow_wrap () =
  let t = text_overflow Wrap default in
  Alcotest.(check bool) "Wrap" true (t.text_overflow = Some Wrap)

let test_text_overflow_no_wrap () =
  let t = text_overflow No_wrap default in
  Alcotest.(check bool) "No_wrap" true (t.text_overflow = Some No_wrap)

(* --- Equality --- *)

let test_equal_default_default () =
  Alcotest.(check bool) "default = default" true (equal default default)

let test_equal_different_font_size () =
  let a = font_size 1.0 default in
  let b = font_size 2.0 default in
  Alcotest.(check bool) "different font_size" false (equal a b)

let test_equal_different_weight () =
  let a = font_weight Nopal_style.Font.Bold default in
  let b = font_weight Nopal_style.Font.Light default in
  Alcotest.(check bool) "different weight" false (equal a b)

let test_equal_line_height_multiplier_float () =
  let a = line_height (Lh_multiplier 1.5) default in
  let b = line_height (Lh_multiplier 1.5) default in
  let c = line_height (Lh_multiplier 1.6) default in
  Alcotest.(check bool) "same multiplier" true (equal a b);
  Alcotest.(check bool) "different multiplier" false (equal a c)

let test_equal_letter_spacing_em_float () =
  let a = letter_spacing (Ls_em 0.05) default in
  let b = letter_spacing (Ls_em 0.05) default in
  let c = letter_spacing (Ls_em 0.1) default in
  Alcotest.(check bool) "same em" true (equal a b);
  Alcotest.(check bool) "different em" false (equal a c)

(* --- Runner --- *)

let () =
  Alcotest.run "nopal_style_text"
    [
      ( "defaults",
        [ Alcotest.test_case "default_all_none" `Quick test_default_all_none ]
      );
      ( "builders",
        [
          Alcotest.test_case "font_family_sets" `Quick test_font_family_sets;
          Alcotest.test_case "font_size_sets" `Quick test_font_size_sets;
          Alcotest.test_case "font_weight_sets" `Quick test_font_weight_sets;
          Alcotest.test_case "line_height_sets" `Quick test_line_height_sets;
          Alcotest.test_case "letter_spacing_sets" `Quick
            test_letter_spacing_sets;
          Alcotest.test_case "text_align_sets" `Quick test_text_align_sets;
          Alcotest.test_case "text_decoration_sets" `Quick
            test_text_decoration_sets;
          Alcotest.test_case "text_transform_sets" `Quick
            test_text_transform_sets;
          Alcotest.test_case "text_overflow_sets" `Quick test_text_overflow_sets;
          Alcotest.test_case "italic_sets" `Quick test_italic_sets;
          Alcotest.test_case "builders_compose" `Quick test_builders_compose;
          Alcotest.test_case "builder_does_not_mutate_other_fields" `Quick
            test_builder_does_not_mutate_other_fields;
        ] );
      ( "line_height_variants",
        [
          Alcotest.test_case "line_height_normal" `Quick test_line_height_normal;
          Alcotest.test_case "line_height_multiplier" `Quick
            test_line_height_multiplier;
          Alcotest.test_case "line_height_px" `Quick test_line_height_px;
        ] );
      ( "letter_spacing_variants",
        [
          Alcotest.test_case "letter_spacing_normal" `Quick
            test_letter_spacing_normal;
          Alcotest.test_case "letter_spacing_em" `Quick test_letter_spacing_em;
        ] );
      ( "text_overflow_variants",
        [
          Alcotest.test_case "text_overflow_clip" `Quick test_text_overflow_clip;
          Alcotest.test_case "text_overflow_ellipsis" `Quick
            test_text_overflow_ellipsis;
          Alcotest.test_case "text_overflow_wrap" `Quick test_text_overflow_wrap;
          Alcotest.test_case "text_overflow_no_wrap" `Quick
            test_text_overflow_no_wrap;
        ] );
      ( "equality",
        [
          Alcotest.test_case "equal_default_default" `Quick
            test_equal_default_default;
          Alcotest.test_case "equal_different_font_size" `Quick
            test_equal_different_font_size;
          Alcotest.test_case "equal_different_weight" `Quick
            test_equal_different_weight;
          Alcotest.test_case "equal_line_height_multiplier_float" `Quick
            test_equal_line_height_multiplier_float;
          Alcotest.test_case "equal_letter_spacing_em_float" `Quick
            test_equal_letter_spacing_em_float;
        ] );
    ]

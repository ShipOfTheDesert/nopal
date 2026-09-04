open Nopal_test.Test_renderer
module Text = Nopal_style.Text
module Font = Nopal_style.Font
module Color = Nopal_style.Color

(* Native structural coverage for the whole kitchen-sink typography section:
   every row of [view_typography] an anchor can reach, read back as the
   resolved [Text.t] the section actually built rather than as a rendered
   width or a computed declaration.

   Two of the groups are worth pinning here for reasons a browser cannot cover
   at all. Three of the preserving container's four rows author a value whose
   whole point is what it does *against an inherited* [Preserve], so the row
   and the container are one claim rather than two. The figures rows are the
   mirror case: what they draw depends on the rendering typeface, so a browser
   can be asked only whether a declaration arrived, never whether the intended
   one was authored — and on a face carrying no such figure set, a row naming
   the wrong value renders indistinguishably from a correct one.

   The rest of the section is pinned for a weaker but real reason, and it is
   the same one everywhere: a testid moved to a neighbouring row, or a row
   naming the wrong member of the right axis, compiles and renders as a
   plausible page. These cases read the authored value under the anchor the
   page publishes, and they run on every [dune runtest] where the browser
   suite needs a built bundle and a headless Chromium.

   What this file does not reach, stated so the whole-section claim above is
   not read wider than it holds: the two boxes demonstrating [Wrap] against
   [No_wrap] carry no [data-testid], so no selector here — and none in the
   browser suite either — can address them. [No_wrap] is pinned on the
   section-level and container whitespace rows; [Wrap] is pinned nowhere in
   this suite, and what it would add over the ellipsis row is that one member
   of the axis rather than a behaviour of its own. Whoever gives those boxes
   an anchor writes their pin in the same change. The section's bare labels
   carry no text style, so there is nothing on them to pin.

   Navigation is stubbed and storage in-memory, mirroring
   {!Test_style_removal_section}. *)
module Test_platform : Nopal_platform.Platform.S = struct
  let current_path () = "/"
  let push_state (_ : string) = ()
  let replace_state (_ : string) = ()
  let back () = ()
  let on_popstate (_ : string -> unit) () = ()

  module Store = Nopal_storage.In_memory ()

  let storage = (module Store : Nopal_storage.S)
end

module K = Kitchen_sink_app.Make (Test_platform)

let pp_whitespace ppf (ws : Text.whitespace) =
  Format.pp_print_string ppf
    (match ws with
    | Collapse -> "Collapse"
    | Preserve -> "Preserve")

let pp_text_overflow ppf (ov : Text.text_overflow) =
  Format.pp_print_string ppf
    (match ov with
    | Clip -> "Clip"
    | Ellipsis -> "Ellipsis"
    | Wrap -> "Wrap"
    | No_wrap -> "No_wrap")

let whitespace =
  Alcotest.(option (testable pp_whitespace Text.equal_whitespace))

let text_overflow =
  Alcotest.(option (testable pp_text_overflow Text.equal_text_overflow))

let pp_figure_spacing ppf (fs : Text.figure_spacing) =
  Format.pp_print_string ppf
    (match fs with
    | Tabular -> "Tabular"
    | Proportional -> "Proportional"
    | Normal_spacing -> "Normal_spacing")

let pp_figure_style ppf (fs : Text.figure_style) =
  Format.pp_print_string ppf
    (match fs with
    | Lining -> "Lining"
    | Oldstyle -> "Oldstyle"
    | Normal_style -> "Normal_style")

let figure_spacing =
  Alcotest.(option (testable pp_figure_spacing Text.equal_figure_spacing))

let figure_style =
  Alcotest.(option (testable pp_figure_style Text.equal_figure_style))

let pp_font_family ppf (f : Font.family) =
  Format.pp_print_string ppf
    (match f with
    | System_ui -> "System_ui"
    | Sans_serif -> "Sans_serif"
    | Serif -> "Serif"
    | Monospace -> "Monospace"
    | Custom name -> "Custom " ^ name)

let pp_font_weight ppf (w : Font.weight) =
  Format.pp_print_string ppf
    (match w with
    | Thin -> "Thin"
    | Extra_light -> "Extra_light"
    | Light -> "Light"
    | Normal -> "Normal"
    | Medium -> "Medium"
    | Semi_bold -> "Semi_bold"
    | Bold -> "Bold"
    | Extra_bold -> "Extra_bold"
    | Black -> "Black")

let pp_line_height ppf (lh : Text.line_height) =
  match lh with
  | Lh_normal -> Format.pp_print_string ppf "Lh_normal"
  | Lh_multiplier m -> Format.fprintf ppf "Lh_multiplier %g" m
  | Lh_px px -> Format.fprintf ppf "Lh_px %g" px

let pp_text_align ppf (a : Text.text_align) =
  Format.pp_print_string ppf
    (match a with
    | Align_left -> "Align_left"
    | Align_center -> "Align_center"
    | Align_right -> "Align_right"
    | Align_justify -> "Align_justify")

let pp_text_transform ppf (tr : Text.text_transform) =
  Format.pp_print_string ppf
    (match tr with
    | Uppercase -> "Uppercase"
    | Lowercase -> "Lowercase"
    | Capitalize -> "Capitalize"
    | No_transform -> "No_transform")

let pp_color ppf (c : Color.t) =
  match c with
  | Rgba { r; g; b; a } -> Format.fprintf ppf "Rgba (%d, %d, %d, %g)" r g b a
  | Hex spelling -> Format.fprintf ppf "Hex %s" spelling
  | Named spelling -> Format.fprintf ppf "Named %s" spelling
  | Transparent -> Format.pp_print_string ppf "Transparent"

let font_family = Alcotest.(option (testable pp_font_family Font.equal_family))
let font_weight = Alcotest.(option (testable pp_font_weight Font.equal_weight))

(* [Float.equal] rather than Alcotest's own float testable: the sizes here are
   exact literals the section wrote, so an approximate comparison would accept a
   row that named a neighbouring step of the scale. *)
let font_size = Alcotest.(option (testable Format.pp_print_float Float.equal))

let line_height =
  Alcotest.(option (testable pp_line_height Text.equal_line_height))

let text_align =
  Alcotest.(option (testable pp_text_align Text.equal_text_align))

let text_transform =
  Alcotest.(option (testable pp_text_transform Text.equal_text_transform))

let color = Alcotest.(option (testable pp_color Color.equal))
let italic = Alcotest.(option bool)

(* The whole rendered section. Re-rendered per call rather than shared, so no
   case can observe a tree another case reached into. *)
let section () = tree (render (K.view_typography (fst (K.init ()))))

(* The container node itself, found from the rendered section rather than
   constructed, so a group that stopped being rendered fails loudly instead of
   leaving every row assertion vacuously unreachable. *)
let container () =
  match
    find
      (By_attr ("data-testid", "whitespace-preserving-container"))
      (section ())
  with
  | Some node -> node
  | None -> Alcotest.fail "the typography section rendered no preserving group"

(* The figures group that declares an axis for its subtree, found the same way
   and for the same reason: its three rows are claims about what a row does
   against an inherited axis, so a row that had drifted out of the container
   would be asserting something else entirely. *)
let figures_container () =
  match
    find (By_attr ("data-testid", "figures-oldstyle-container")) (section ())
  with
  | Some node -> node
  | None ->
      Alcotest.fail "the typography section rendered no inherited-figures group"

(* The text style a row resolved to. Reached through the row's own anchor and
   then its first child — the anchor carries the sample alone — so this does not
   restate the sample literal the section defines. *)
let row_text_style group testid =
  let anchor =
    match find (By_attr ("data-testid", testid)) group with
    | Some node -> node
    | None -> Alcotest.fail (testid ^ ": the group renders no such row")
  in
  let sample =
    match find First_child anchor with
    | Some node -> node
    | None -> Alcotest.fail (testid ^ ": the row anchor carries no text")
  in
  match text_style sample with
  | Some style -> style
  | None -> Alcotest.fail (testid ^ ": the row's text carries no text style")

(* The text style an anchored box declares for itself. The alignment boxes and
   the preserving container author on the box rather than on a child, because
   what each demonstrates is a container acting on the content inside it — so
   these are read from the element's own style, not through {!row_text_style}.
*)
let box_text_style group testid =
  let anchor =
    match find (By_attr ("data-testid", testid)) group with
    | Some node -> node
    | None -> Alcotest.fail (testid ^ ": the section renders no such element")
  in
  match style anchor with
  | Some style -> style.Nopal_style.Style.text
  | None -> Alcotest.fail (testid ^ ": the anchor is not an element")

(* Both whitespace groups are read the same way — a table of rows, both axes of
   each, and beside them the monospace family the helper sets whatever its
   arguments. The two groups differ only in their fixture and their
   expectations, so the reading lives here once and each case supplies its own
   table. The family check is what keeps a row expecting two [None]s from going
   vacuous: it is an affirmative arm on that same row, which a sibling row
   producing [Some] cannot be. *)
let check_whitespace_rows group expected =
  List.iter
    (fun (testid, (expected_whitespace, expected_overflow)) ->
      let style = row_text_style group testid in
      Alcotest.check whitespace
        (testid ^ ": collapsing axis")
        expected_whitespace style.Text.whitespace;
      Alcotest.check text_overflow
        (testid ^ ": wrapping axis")
        expected_overflow style.Text.text_overflow;
      Alcotest.check font_family
        (testid ^ ": the family the helper sets on every row")
        (Some Font.Monospace) style.Text.font_family)
    expected

(* The same shape for the two numeric-figures groups. The preserved whitespace
   read alongside the axes is the figures helper's unconditional counterpart of
   the monospace family above, and it carries the same weight: a row expecting
   both figure axes unset would stay green if that row had stopped reaching the
   text-style path at all, and this is the arm on that row which rules it out. *)
let check_figures_rows group expected =
  List.iter
    (fun (testid, (expected_spacing, expected_style)) ->
      let style = row_text_style group testid in
      Alcotest.check figure_spacing (testid ^ ": width axis") expected_spacing
        style.Text.figure_spacing;
      Alcotest.check figure_style (testid ^ ": form axis") expected_style
        style.Text.figure_style;
      Alcotest.check whitespace
        (testid ^ ": the preservation the helper sets on every row")
        (Some Text.Preserve) style.Text.whitespace)
    expected

(* Without this the three rows below assert against nothing: an explicit
   [Collapse] and an unset whitespace resolve identically unless an ancestor
   preserves. *)
let test_container_preserves () =
  Alcotest.check whitespace "the group declares preservation for its subtree"
    (Some Text.Preserve)
    (box_text_style (section ()) "whitespace-preserving-container")
      .Text.whitespace

(* Both axes of all four rows in one table, so the two rows that leave an axis
   unset are read beside the two that set it. The monospace family is read on
   every row as well: it is what the helper sets whatever its arguments, so it
   is the affirmative arm on the same row for the first row's two [None]s — a
   row that had stopped reaching the text-style path altogether would satisfy
   those [None]s, and a sibling row producing [Some] is a different fixture and
   cannot rule that out. The last row is the trap — it authors only the wrapping
   axis and therefore loses the container's preservation at the platform, which
   is exactly why its authored whitespace must stay unset. *)
let test_rows_author_their_axes () =
  check_whitespace_rows (container ())
    [
      ("whitespace-inherited", (None, None));
      ("whitespace-collapse", (Some Text.Collapse, None));
      ("whitespace-collapse-nowrap", (Some Text.Collapse, Some Text.No_wrap));
      ("whitespace-inherited-nowrap", (None, Some Text.No_wrap));
    ]

(* The row that authors neither figure axis is the one that can go vacuous: an
   expectation of two [None]s would stay green if that row had stopped reaching
   the text-style path at all. This is its affirmative arm on the same row —
   the style it carries is present and populated on the axes the helper sets
   unconditionally, so its unset figure axes are the helper passing [None]
   through, not a row that never acquired a style. *)
let test_unset_row_reaches_the_text_style_path () =
  let style = row_text_style (section ()) "figures-unset" in
  Alcotest.check whitespace
    "the row authoring no figure axis still carries the helper's own style"
    (Some Text.Preserve) style.Text.whitespace

(* Both figure axes of all four numeric-figures rows in one table. The rows have
   no anchored container of their own, so they are located from the section root
   rather than through a group node.

   The expectations cross the axes deliberately — one row per axis alone, one
   setting both, one setting neither. What is at risk is not which field an
   argument lands in: the two axes are distinct types, so a width value cannot
   reach the form field and the compiler settles that without a test. What no
   type rules out is the value a row asks for and the anchor it asks under — a
   testid moved to its neighbour, or a row naming the wrong member of the right
   axis, both compile, and on a face carrying no such figure set they render
   indistinguishably from the intended row. The sibling rows producing [Some]
   are also what keeps the neither-axis row's [None]s from being an absence
   nobody would notice. *)
let test_figures_rows_author_their_axes () =
  check_figures_rows (section ())
    [
      ("figures-unset", (None, None));
      ("figures-tabular", (Some Text.Tabular, None));
      ("figures-oldstyle", (None, Some Text.Oldstyle));
      ("figures-tabular-lining", (Some Text.Tabular, Some Text.Lining));
    ]

(* The counterpart of {!test_container_preserves} for the figures group that
   declares an axis for its subtree. Without it the three rows below assert
   against nothing: a row asking for the typeface's own forms and a row asking
   for nothing resolve identically unless an ancestor has asked for something
   else. The container declares one axis only, so the other stays available as
   the axis a row can reset it through. *)
let test_figures_container_authors_oldstyle () =
  let text = box_text_style (section ()) "figures-oldstyle-container" in
  Alcotest.check figure_style
    "the group declares old-style forms for its subtree" (Some Text.Oldstyle)
    text.Text.figure_style;
  Alcotest.check figure_spacing
    "and leaves the width axis for its rows to reset" None
    text.Text.figure_spacing

(* Both figure axes of the three rows under that container. Each is a claim
   about the row *against* an inherited form axis, which is why they are read
   as one group with the container rather than beside the four independent rows
   above: the first inherits it, the second asks for the typeface's own forms
   and so climbs back out of it — the whole reason that variant exists — and
   the third authors only the width axis and loses the inherited forms anyway,
   because the two axes resolve to one declaration and every value of it names
   both. Nothing here is settled by the types: each row's value and the anchor
   it sits under are both free to be wrong and still compile, and on a face
   carrying no old-style set all three render alike. *)
let test_inherited_figures_rows_author_their_axes () =
  check_figures_rows (figures_container ())
    [
      ("figures-inherited", (None, None));
      ("figures-normal-style", (None, Some Text.Normal_style));
      ("figures-inherited-proportional", (Some Text.Proportional, None));
    ]

(* The heading scale. Both fields on every row: the size is what separates the
   four rows from one another, and the weight is what the helper puts on all of
   them — a helper that stopped applying it would leave four rows that still
   differ in size and no longer read as headings anywhere but in a browser. *)
let test_headings_author_size_and_weight () =
  let rendered = section () in
  let expected =
    [
      ("heading-h1", 2.0);
      ("heading-h2", 1.5);
      ("heading-h3", 1.25);
      ("heading-h4", 1.0);
    ]
  in
  List.iter
    (fun (testid, expected_size) ->
      let style = row_text_style rendered testid in
      Alcotest.check font_size (testid ^ ": size") (Some expected_size)
        style.Text.font_size;
      Alcotest.check font_weight (testid ^ ": weight") (Some Font.Bold)
        style.Text.font_weight)
    expected

(* All nine weights in one table. The values are built by one helper from a
   variant, so nothing here is at risk of landing in the wrong field; what is at
   risk is the pairing of a weight with the anchor it is published under, which
   a reader can only check against a face that actually carries nine weights. *)
let test_weight_rows_author_their_weight () =
  let rendered = section () in
  let expected =
    [
      ("weight-100", Font.Thin);
      ("weight-200", Font.Extra_light);
      ("weight-300", Font.Light);
      ("weight-400", Font.Normal);
      ("weight-500", Font.Medium);
      ("weight-600", Font.Semi_bold);
      ("weight-700", Font.Bold);
      ("weight-800", Font.Extra_bold);
      ("weight-900", Font.Black);
    ]
  in
  List.iter
    (fun (testid, expected_weight) ->
      Alcotest.check font_weight (testid ^ ": weight") (Some expected_weight)
        (row_text_style rendered testid).Text.font_weight)
    expected

(* Body copy pins both fields it authors rather than the line height alone: the
   multiplier is only meaningful relative to a size, and reading them together
   is what makes the row a demonstration of the pair. *)
let test_body_copy_authors_its_size_and_line_height () =
  let style = row_text_style (section ()) "body-copy" in
  Alcotest.check font_size "body copy: size" (Some 1.0) style.Text.font_size;
  Alcotest.check line_height "body copy: line height"
    (Some (Text.Lh_multiplier 1.6)) style.Text.line_height

let test_monospace_block_authors_its_family () =
  Alcotest.check font_family "monospace block: family" (Some Font.Monospace)
    (row_text_style (section ()) "monospace-block").Text.font_family

(* The one row in the section that authors [Ellipsis]. The narrow container it
   sits in is what makes the value visible in a browser and is not read here —
   the claim is that this row asked for truncation and not for one of the three
   other members of the axis. *)
let test_ellipsis_row_authors_its_overflow () =
  Alcotest.check text_overflow "ellipsis row: wrapping axis"
    (Some Text.Ellipsis)
    (row_text_style (section ()) "ellipsis-text").Text.text_overflow

let test_italic_row_authors_italic () =
  Alcotest.check italic "italic row: italic" (Some true)
    (row_text_style (section ()) "italic-text").Text.italic

(* The three transform rows. Each renders a literal written in the case the
   transform is meant to change, so a row published under its neighbour's anchor
   renders as text that reads correctly and is wrong about which transform did
   it. *)
let test_transform_rows_author_their_transform () =
  let rendered = section () in
  let expected =
    [
      ("transform-uppercase", Text.Uppercase);
      ("transform-lowercase", Text.Lowercase);
      ("transform-capitalize", Text.Capitalize);
    ]
  in
  List.iter
    (fun (testid, expected_transform) ->
      Alcotest.check text_transform (testid ^ ": transform")
        (Some expected_transform)
        (row_text_style rendered testid).Text.text_transform)
    expected

(* The four alignment boxes. They author on the box, so this reads the
   element's own style: the label inside each is a bare text node with no style
   of its own, and going through the child would find nothing to assert on. *)
let test_alignment_boxes_author_their_alignment () =
  let rendered = section () in
  let expected =
    [
      ("align-left", Text.Align_left);
      ("align-center", Text.Align_center);
      ("align-right", Text.Align_right);
      ("align-justify", Text.Align_justify);
    ]
  in
  List.iter
    (fun (testid, expected_align) ->
      Alcotest.check text_align (testid ^ ": alignment") (Some expected_align)
        (box_text_style rendered testid).Text.text_align)
    expected

(* The four colour rows, with the size the helper sets unconditionally read
   beside the colour on every one of them. The last row authors no colour, and
   an expectation of [None] there would stay green if that row had stopped
   reaching the text-style path at all — the size is its affirmative arm on the
   same row, and reading it on the three coloured rows too is what shows the arm
   is a property of the helper rather than of that one row. The translucent row
   is kept beside the two opaque spellings because its alpha is the component a
   comparison that ignored floats would silently accept. *)
let test_colour_rows_author_their_colour () =
  let rendered = section () in
  let expected =
    [
      ("text-color-hex", Some (Color.hex "#c0392b"));
      ("text-color-rgba", Some (Color.rgba 30 120 200 0.6));
      ("text-color-named", Some (Color.named "rebeccapurple"));
      ("text-color-inherited", None);
    ]
  in
  List.iter
    (fun (testid, expected_color) ->
      let style = row_text_style rendered testid in
      Alcotest.check color (testid ^ ": colour") expected_color style.Text.color;
      Alcotest.check font_size
        (testid ^ ": the size the helper sets on every row")
        (Some 1.0) style.Text.font_size)
    expected

(* The four section-level whitespace rows — the ones outside the preserving
   container, where an unset collapsing axis means the document default rather
   than an inherited [Preserve]. Both axes of every row in one table, for the
   reason the container group states, and the monospace family beside them: the
   first row authors neither axis, and two [None]s on their own would survive
   that row ceasing to reach the text-style path. The family is what the helper
   sets on every row regardless of its arguments, so it is the affirmative arm
   for the unset row and a check on the helper for the other three. *)
let test_section_whitespace_rows_author_their_axes () =
  check_whitespace_rows (section ())
    [
      ("whitespace-unset", (None, None));
      ("whitespace-unset-nowrap", (None, Some Text.No_wrap));
      ("whitespace-preserve", (Some Text.Preserve, None));
      ("whitespace-preserve-nowrap", (Some Text.Preserve, Some Text.No_wrap));
    ]

let () =
  Alcotest.run "kitchen_sink_typography_section"
    [
      ( "heading scale",
        [
          Alcotest.test_case "each heading authors its size and weight" `Quick
            test_headings_author_size_and_weight;
        ] );
      ( "type features",
        [
          Alcotest.test_case "body copy authors its size and line height" `Quick
            test_body_copy_authors_its_size_and_line_height;
          Alcotest.test_case "the monospace block authors its family" `Quick
            test_monospace_block_authors_its_family;
          Alcotest.test_case "the ellipsis row authors its wrapping axis" `Quick
            test_ellipsis_row_authors_its_overflow;
          Alcotest.test_case "the italic row authors italic" `Quick
            test_italic_row_authors_italic;
          Alcotest.test_case "each transform row authors its transform" `Quick
            test_transform_rows_author_their_transform;
        ] );
      ( "weights",
        [
          Alcotest.test_case "each row authors its weight" `Quick
            test_weight_rows_author_their_weight;
        ] );
      ( "alignment",
        [
          Alcotest.test_case "each box authors its alignment" `Quick
            test_alignment_boxes_author_their_alignment;
        ] );
      ( "colours",
        [
          Alcotest.test_case "each row authors its colour" `Quick
            test_colour_rows_author_their_colour;
        ] );
      ( "section-level whitespace",
        [
          Alcotest.test_case "each row authors its own axes" `Quick
            test_section_whitespace_rows_author_their_axes;
        ] );
      ( "inherited whitespace",
        [
          Alcotest.test_case "the container preserves for its subtree" `Quick
            test_container_preserves;
          Alcotest.test_case "each row authors its own axes" `Quick
            test_rows_author_their_axes;
        ] );
      ( "numeric figures",
        [
          Alcotest.test_case "the unset row still reaches the text-style path"
            `Quick test_unset_row_reaches_the_text_style_path;
          Alcotest.test_case "each row authors its own figure axes" `Quick
            test_figures_rows_author_their_axes;
        ] );
      ( "inherited numeric figures",
        [
          Alcotest.test_case "the container authors old-style for its subtree"
            `Quick test_figures_container_authors_oldstyle;
          Alcotest.test_case "each row authors its own figure axes" `Quick
            test_inherited_figures_rows_author_their_axes;
        ] );
    ]

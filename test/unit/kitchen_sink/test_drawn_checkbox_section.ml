(* The drawn-checkbox kitchen-sink section, read structurally.

   The structural renderer paints nothing, so whether a drawn box actually looks
   like its description is the browser spec's to show. What this file pins is
   the description itself: the values the design asks for, the size the view
   picks from its viewport, and the shape of each example the browser spec
   leans on. An example that silently lost its hover background or its ring
   would leave the matching browser case green and meaningless.

   The expected colours and sizes are the design's own numbers, written out
   here rather than read back from the section, so a section that drifted from
   the design fails instead of agreeing with itself. *)

open Nopal_test.Test_renderer
module Sub = Kitchen_sink_app__Sub_drawn_checkbox
module Style = Nopal_style.Style
module Color = Nopal_style.Color
module Interaction = Nopal_style.Interaction
module Checkbox_appearance = Nopal_style.Checkbox_appearance
module Viewport = Nopal_element.Viewport

let field_color = "Hex #FFFDF9"
let teal = "Hex #02403A"
let white = "Hex #FFFFFF"
let unticked = "drawn-checkbox-unticked"
let ticked = "drawn-checkbox-ticked"
let focus_ring = "drawn-checkbox-focus-ring"
let inline = "drawn-checkbox-inline"
let hover_background = "drawn-checkbox-hover-background"
let disabled = "drawn-checkbox-disabled"

let all_examples =
  [ unticked; ticked; focus_ring; inline; hover_background; disabled ]

let by_testid id = By_attr ("data-testid", id)

let rendered_on viewport msgs =
  snd (run_app ~init:Sub.init ~update:Sub.update ~view:Sub.view ~viewport msgs)

let desktop () = rendered_on Viewport.desktop []

let node_of id rendered =
  match find (by_testid id) (tree rendered) with
  | Some node -> node
  | None -> Alcotest.fail (id ^ ": the section renders no such element")

let base_style id rendered =
  match style (node_of id rendered) with
  | Some s -> s
  | None -> Alcotest.fail (id ^ ": carries no style")

let interaction_of id rendered =
  match interaction (node_of id rendered) with
  | Some i -> i
  | None -> Alcotest.fail (id ^ ": carries no interaction")

(* The ticked style and the mark, or a failure naming the example: a [Native]
   example is not drawn at all, which is the defect every case here exists to
   catch first. *)
let drawn id rendered =
  match checkbox_appearance (by_testid id) rendered with
  | Ok (Checkbox_appearance.Drawn { checked; mark }) -> (checked, mark)
  | Ok Checkbox_appearance.Native ->
      Alcotest.fail (id ^ ": declares the platform checkbox, not a drawn one")
  | Error (Not_found _) -> Alcotest.fail (id ^ ": no such element")
  | Error (No_handler _) -> Alcotest.fail (id ^ ": is not a checkbox")

(* Colours are compared as text so a failure names the colour found. Every
   constructor is spelled out so a colour form added later stops compiling here
   instead of reading as one of these. *)
let color_to_string (c : Color.t) =
  match c with
  | Color.Rgba { r; g; b; a } -> Printf.sprintf "Rgba %d %d %d %g" r g b a
  | Color.Hex h -> "Hex " ^ h
  | Color.Named n -> "Named " ^ n
  | Color.Transparent -> "Transparent"

let size_to_string (s : Style.size) =
  match s with
  | Style.Fill -> "Fill"
  | Style.Hug -> "Hug"
  | Style.Fixed f -> Printf.sprintf "Fixed %g" f
  | Style.Fraction f -> Printf.sprintf "Fraction %g" f

let border_style_to_string (b : Style.border_style) =
  match b with
  | Style.Solid -> "Solid"
  | Style.Dashed -> "Dashed"
  | Style.Dotted -> "Dotted"
  | Style.No_border -> "No_border"

let background (s : Style.t) = Option.map color_to_string s.paint.background
let colour = Alcotest.(option string)

let test_section_uses_the_design_values () =
  let r = desktop () in
  let base = base_style unticked r in
  (match base.paint.border with
  | Some border ->
      Alcotest.(check (float 0.0)) "a 1 px hairline" 1.0 border.width;
      Alcotest.(check string)
        "a solid hairline" "Solid"
        (border_style_to_string border.style);
      Alcotest.(check (float 0.0)) "radius 4" 4.0 border.radius
  | None -> Alcotest.fail "the unticked box declares no border");
  Alcotest.check colour "unticked on the field colour" (Some field_color)
    (background base);
  let checked, mark = drawn unticked r in
  Alcotest.check colour "ticked fills teal" (Some teal) (background checked);
  Alcotest.(check string) "the tick is white" white (color_to_string mark);
  let ticked_checked, ticked_mark = drawn ticked r in
  Alcotest.(check bool)
    "the ticked example declares the same design" true
    (Style.equal base (base_style ticked r)
    && Style.equal checked ticked_checked
    && Color.equal mark ticked_mark);
  Alcotest.(check (option string))
    "the ticked example starts ticked" (Some "true")
    (attr "checked" (node_of ticked r))

let sizes_on viewport =
  let r = rendered_on viewport [] in
  List.map
    (fun id ->
      let layout = (base_style id r).layout in
      ( id,
        Option.map size_to_string layout.width,
        Option.map size_to_string layout.height ))
    all_examples

let expect_size label expected viewport =
  List.iter
    (fun (id, width, height) ->
      Alcotest.(check (option string))
        (label ^ ": " ^ id ^ " width")
        (Some expected) width;
      Alcotest.(check (option string))
        (label ^ ": " ^ id ^ " height")
        (Some expected) height)
    (sizes_on viewport)

let test_size_is_18_on_regular_viewport () =
  expect_size "desktop" "Fixed 18" Viewport.desktop;
  expect_size "tablet" "Fixed 18" Viewport.tablet

let test_size_is_20_on_compact_viewport () =
  Alcotest.(check bool)
    "the phone viewport is compact" true
    (Viewport.is_compact Viewport.phone);
  expect_size "phone" "Fixed 20" Viewport.phone

let test_disabled_example_is_ticked_with_caller_styles () =
  let r = desktop () in
  let node = node_of disabled r in
  Alcotest.(check (option string))
    "it is ticked" (Some "true") (attr "checked" node);
  Alcotest.(check (option string))
    "it is disabled" (Some "true") (attr "disabled" node);
  let disabled_checked, _ = drawn disabled r in
  let enabled_checked, _ = drawn unticked r in
  Alcotest.(check bool)
    "its base style is its own" false
    (Style.equal (base_style disabled r) (base_style unticked r));
  Alcotest.(check bool)
    "its ticked style is its own" false
    (Style.equal disabled_checked enabled_checked);
  Alcotest.(check bool)
    "its ticked fill is not the enabled teal" true
    (match background disabled_checked with
    | Some c -> not (String.equal c teal)
    | None -> false)

let test_focus_ring_example_declares_2px_ring () =
  let r = desktop () in
  (match (interaction_of focus_ring r).focused with
  | Some focused -> (
      match focused.paint.shadow with
      | Some s ->
          Alcotest.(check (float 0.0)) "no x offset" 0.0 s.x;
          Alcotest.(check (float 0.0)) "no y offset" 0.0 s.y;
          Alcotest.(check (float 0.0)) "no blur" 0.0 s.blur;
          Alcotest.(check (float 0.0)) "a 2 px spread" 2.0 s.spread;
          Alcotest.(check string)
            "the ring colour" "Rgba 2 64 58 0.5" (color_to_string s.color)
      | None -> Alcotest.fail "the focused style declares no ring")
  | None -> Alcotest.fail "the example declares no focused style");
  let checked, _ = drawn focus_ring r in
  Alcotest.(check bool)
    "the ticked style sets no shadow, so the ring survives ticking" true
    (Option.is_none checked.paint.shadow)

let test_inline_path_example_has_no_interaction () =
  let r = desktop () in
  Alcotest.(check bool)
    "no interaction state" false
    (Interaction.has_any (interaction_of inline r));
  (* The same example is still a drawn box on the design's base style, so the
     absence above is the inline-path shape and not an example that stopped
     being drawn. *)
  let checked, _ = drawn inline r in
  Alcotest.check colour "it is drawn, ticking teal" (Some teal)
    (background checked);
  Alcotest.check colour "on the field colour" (Some field_color)
    (background (base_style inline r));
  Alcotest.(check bool)
    "the focus example beside it does carry interaction" true
    (Interaction.has_any (interaction_of focus_ring r))

let test_hover_background_example_sets_hover_background () =
  let r = desktop () in
  let hover_bg =
    match (interaction_of hover_background r).hover with
    | Some hover -> background hover
    | None -> Alcotest.fail "the example declares no hover style"
  in
  Alcotest.check colour "the hover background" (Some "Hex #E6EFEE") hover_bg;
  let checked, _ = drawn hover_background r in
  Alcotest.check colour "the ticked fill it must lose to" (Some teal)
    (background checked)

let test_toggle_dispatches () =
  let r = desktop () in
  (match toggle (by_testid unticked) r with
  | Ok () -> ()
  | Error (Not_found _) -> Alcotest.fail "no unticked example to toggle"
  | Error (No_handler _) -> Alcotest.fail "the unticked example has no toggle");
  (match messages r with
  | [ (Sub.Toggled (Sub.Unticked_start, true) as msg) ] ->
      Alcotest.(check string)
        "the telemetry fragment" "DrawnCheckbox:Toggled:Unticked_start:true;"
        (Sub.serialize_msg msg)
  | [ Sub.Toggled (_, _) ] ->
      Alcotest.fail "toggled the wrong example or to the wrong state"
  | [] -> Alcotest.fail "the toggle dispatched nothing"
  | _ :: _ :: _ -> Alcotest.fail "the toggle dispatched more than once");
  let after =
    rendered_on Viewport.desktop [ Sub.Toggled (Sub.Unticked_start, true) ]
  in
  Alcotest.(check (option string))
    "the message ticks the example" (Some "true")
    (attr "checked" (node_of unticked after))

let () =
  Alcotest.run "kitchen_sink_drawn_checkbox_section"
    [
      ( "drawn_checkbox_section",
        [
          Alcotest.test_case "section_uses_the_design_values" `Quick
            test_section_uses_the_design_values;
          Alcotest.test_case "size_is_18_on_regular_viewport" `Quick
            test_size_is_18_on_regular_viewport;
          Alcotest.test_case "size_is_20_on_compact_viewport" `Quick
            test_size_is_20_on_compact_viewport;
          Alcotest.test_case "disabled_example_is_ticked_with_caller_styles"
            `Quick test_disabled_example_is_ticked_with_caller_styles;
          Alcotest.test_case "focus_ring_example_declares_2px_ring" `Quick
            test_focus_ring_example_declares_2px_ring;
          Alcotest.test_case "inline_path_example_has_no_interaction" `Quick
            test_inline_path_example_has_no_interaction;
          Alcotest.test_case "hover_background_example_sets_hover_background"
            `Quick test_hover_background_example_sets_hover_background;
          Alcotest.test_case "toggle_dispatches" `Quick test_toggle_dispatches;
        ] );
    ]

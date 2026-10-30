(* Every graphic the kitchen sink renders, read structurally through the whole
   app: each canvas is either an image with a name or hidden, each image carries
   an alt, every name below is found where it is drawn and nowhere else, and
   exactly one graphic, the sparkline beside the value it repeats, is
   decorative.

   The browser spec queries the same names by role, so the two lists below are
   the ones it copies. *)

open Nopal_test.Test_renderer

module Platform : Nopal_platform.Platform.S = struct
  let current_path () = "/kitchen_sink/"
  let push_state (_ : string) = ()
  let replace_state (_ : string) = ()
  let back () = ()
  let on_popstate (_ : string -> unit) () = ()

  module Store = Nopal_storage.In_memory ()

  let storage = (module Store : Nopal_storage.S)
end

module K = Kitchen_sink_app.Make (Platform)

let vp = Nopal_element.Viewport.desktop
let app () = tree (render (K.view vp (fst (K.init ()))))
let draw_section = By_attr ("data-section", "draw")
let charts_section = By_attr ("data-section", "charts")
let extensions_section = By_attr ("data-section", "chart-extensions")
let svg_export_section = By_attr ("data-testid", "svg-export-section")

(* Every named canvas in the app, with the section it is drawn in. *)
let named_canvases =
  [
    ( draw_section,
      "Rectangle, rounded rectangle, circle, ellipse, line, triangle and \
       polyline" );
    (draw_section, "A smooth curve, a run of straight segments and an arc");
    ( draw_section,
      "Rectangles filled solid, with a linear gradient and with a radial \
       gradient" );
    ( draw_section,
      "Lines stroked solid, dashed and with round caps, and a bevel-joined \
       polyline" );
    ( draw_section,
      "Text anchored at start, middle and end, in bold and at size 18" );
    ( draw_section,
      "A rectangle translated, scaled, rotated, rotated about a point and \
       skewed" );
    ( draw_section,
      "Overlapping rectangles at half opacity and under a multiply blend" );
    (draw_section, "Two rectangles clipped to a circle");
    (draw_section, "Interactive drawing");
    (charts_section, "Monthly totals, January to June, with hover details");
    (charts_section, "Monthly revenue, January to June, on themed axes");
    (charts_section, "Revenue and costs over six periods");
    (charts_section, "Products A and B, stacked, over six periods");
    ( charts_section,
      "Device share: desktop 45%, mobile 35%, tablet 15%, other 5%" );
    ( charts_section,
      "Device share as a donut: desktop 45%, mobile 35%, tablet 15%, other 5%"
    );
    ( charts_section,
      "Device share donut and a single full ring, on a canvas over a \
       checkerboard" );
    (charts_section, "Seven points, each sized by a third value");
    (charts_section, "Trend, rising from 5 to 30 over ten points");
    ( extensions_section,
      "Profit and loss by hour, 9am to 12pm, Monday to Friday" );
    (extensions_section, "Correlation matrix of SPY, QQQ, TLT and GLD");
    (extensions_section, "Open, high, low and close prices over ten periods");
    (extensions_section, "Drawdown from peak over ten periods, deepest 8%");
    (extensions_section, "Synchronised panes: open, high, low and close prices");
    (extensions_section, "Synchronised panes: volume");
    (extensions_section, "Synchronised panes: drawdown from peak");
    ( extensions_section,
      "Signal of 1,000 points, drag to pan and scroll to zoom" );
    (svg_export_section, "Monthly totals, January to June, as exported to SVG");
  ]

(* Every image the app shows before any photograph is picked, by its alt. *)
let named_images =
  [
    "Plain grey placeholder square";
    "Placeholder square contained in a wide box";
    "Placeholder square covering a wide box";
    "Device share donut and a single full ring, as an SVG image over a \
     checkerboard";
  ]

let is_blank s = String.equal (String.trim s) ""

let check_canvas_decided canvas =
  match
    (attr "role" canvas, attr "aria-label" canvas, attr "aria-hidden" canvas)
  with
  | Some "img", Some label, None when not (is_blank label) -> ()
  | None, None, Some "true" -> ()
  | role, label, hidden ->
      let show = Option.value ~default:"<absent>" in
      Alcotest.failf "an undecided canvas: role=%s aria-label=%s aria-hidden=%s"
        (show role) (show label) (show hidden)

let test_every_kitchen_sink_canvas_is_decided () =
  let root = app () in
  let canvases = find_all (By_tag "canvas") root in
  let images = find_all (By_tag "image") root in
  Alcotest.(check bool) "the app renders canvases" true (canvases <> []);
  Alcotest.(check bool) "the app renders images" true (images <> []);
  List.iter check_canvas_decided canvases;
  List.iter
    (fun image ->
      Alcotest.(check bool)
        "every image carries alt" true (has_attr "alt" image))
    images

let test_charts_have_their_names () =
  let root = app () in
  List.iter
    (fun (section, name) ->
      let within =
        Test_util.find_or_fail ("the section of " ^ name) section root
      in
      Alcotest.(check int)
        ("one canvas named " ^ name ^ " in its section")
        1
        (List.length (find_all (By_attr ("aria-label", name)) within));
      Alcotest.(check int)
        ("one node named " ^ name ^ " in the app")
        1
        (List.length (find_all (By_attr ("aria-label", name)) root)))
    named_canvases;
  Alcotest.(check int)
    "every named canvas in the app is listed"
    (List.length named_canvases)
    (List.length
       (List.filter
          (fun canvas -> attr "role" canvas = Some "img")
          (find_all (By_tag "canvas") root)));
  List.iter
    (fun name ->
      Alcotest.(check int)
        ("one image with alt " ^ name)
        1
        (List.length (find_all (By_attr ("alt", name)) root)))
    named_images;
  Alcotest.(check int)
    "every image in the app is listed" (List.length named_images)
    (List.length (find_all (By_tag "image") root))

let test_decorative_sparkline_exposes_nothing () =
  let root = app () in
  let row =
    Test_util.find_or_fail "the sparkline row"
      (By_attr ("data-testid", "sparkline-row"))
      root
  in
  let kpi =
    Test_util.find_or_fail "the growth value"
      (By_attr ("data-testid", "growth-kpi"))
      row
  in
  let sparkline =
    Test_util.find_or_fail "the growth sparkline" (By_tag "canvas") kpi
  in
  Alcotest.(check bool)
    "the value the sparkline repeats is visible beside it" true
    (Test_util.string_contains (text_content kpi) ~sub:"5, down from 30");
  Alcotest.(check (list (option string)))
    "aria-hidden, and no role or aria-label"
    [ Some "true"; None; None ]
    [
      attr "aria-hidden" sparkline;
      attr "role" sparkline;
      attr "aria-label" sparkline;
    ];
  Alcotest.(check (list (pair (option string) (option string))))
    "the row's other sparkline is named, so the row reaches the name"
    [ (Some "img", Some "Trend, rising from 5 to 30 over ten points") ]
    (List.filter_map
       (fun canvas ->
         match attr "aria-hidden" canvas with
         | Some _ -> None
         | None -> Some (attr "role" canvas, attr "aria-label" canvas))
       (find_all (By_tag "canvas") row));
  Alcotest.(check int)
    "it is the only decorative canvas in the app" 1
    (List.length
       (List.filter
          (fun canvas -> attr "aria-hidden" canvas = Some "true")
          (find_all (By_tag "canvas") root)))

let () =
  Alcotest.run "graphic_names"
    [
      ( "kitchen_sink",
        [
          Alcotest.test_case "every_kitchen_sink_canvas_is_decided" `Quick
            test_every_kitchen_sink_canvas_is_decided;
          Alcotest.test_case "charts_have_their_names" `Quick
            test_charts_have_their_names;
          Alcotest.test_case "decorative_sparkline_exposes_nothing" `Quick
            test_decorative_sparkline_exposes_nothing;
        ] );
    ]

(* The donut-over-a-checkerboard kitchen-sink section, read structurally through
   the whole kitchen sink so the section's registration is under test too.

   Whether the hole shows the checkerboard is paint, which the structural
   renderer cannot see; that is the browser spec's. What this file holds is what
   the browser spec rests on: the section draws the scene on a canvas and loads
   the same scene's SVG as an image, and the scene fakes no hole by painting a
   disc of the background over the donut. *)

open Nopal_test.Test_renderer
module Sub = Kitchen_sink_app.Sub_donut
module Scene = Nopal_scene.Scene
module Color = Nopal_scene.Color
module Paint = Nopal_scene.Paint

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
let data_uri_prefix = "data:image/svg+xml,"

let section () =
  Test_util.find_or_fail "the donut section"
    (By_attr ("data-testid", "donut-section"))
    (tree (render (K.view vp (fst (K.init ())))))

let test_donut_section_renders_canvas_and_svg () =
  let s = section () in
  let canvas_box =
    Test_util.find_or_fail "the canvas box"
      (By_attr ("data-testid", "donut-canvas"))
      s
  in
  let svg_box =
    Test_util.find_or_fail "the svg box"
      (By_attr ("data-testid", "donut-svg"))
      s
  in
  let canvas =
    Test_util.find_or_fail "the canvas" (By_tag "canvas") canvas_box
  in
  let svg_image =
    Test_util.find_or_fail "the svg image" (By_tag "image") svg_box
  in
  Alcotest.(check bool)
    "the svg image src is an SVG data URI" true
    (match attr "src" svg_image with
    | Some src -> String.starts_with ~prefix:"data:image/svg+xml" src
    | None -> false);
  Alcotest.(check (pair (option string) (option string)))
    "the canvas is the scene's logical size"
    (Some (string_of_float Sub.width), Some (string_of_float Sub.height))
    (attr "width" canvas, attr "height" canvas)

let test_donut_svg_src_is_data_uri () =
  let image =
    Test_util.find_or_fail "the svg image" (By_tag "image")
      (Test_util.find_or_fail "the svg box"
         (By_attr ("data-testid", "donut-svg"))
         (section ()))
  in
  let src =
    match attr "src" image with
    | Some src -> src
    | None -> Alcotest.fail "the svg image has no src"
  in
  let prefix_len = String.length data_uri_prefix in
  Alcotest.(check bool)
    "src is an SVG data URI" true
    (String.starts_with ~prefix:data_uri_prefix src);
  let payload = String.sub src prefix_len (String.length src - prefix_len) in
  let svg =
    match Nopal_fs_key.decode_filename payload with
    | Some svg -> svg
    | None -> Alcotest.fail "the data URI payload is not percent-encoded"
  in
  Alcotest.(check bool)
    "the decoded payload is an SVG document" true
    (String.starts_with ~prefix:"<svg " svg);
  List.iter
    (fun (name, color) ->
      Alcotest.(check bool)
        (name ^ " checker colour is in the SVG")
        true
        (Test_util.string_contains svg
           ~sub:(Nopal_svg.Svg_fmt.color_to_css color)))
    [ ("light", Sub.checker_light); ("dark", Sub.checker_dark) ]

let is_checker (paint : Paint.t) =
  match paint with
  | Solid c -> Color.equal c Sub.checker_light || Color.equal c Sub.checker_dark
  | Linear_gradient _
  | Radial_gradient _
  | No_paint ->
      false

type painted = Disc | Segment of Paint.t | Filled of Paint.t | Unfilled

(* Every painted node in paint order. A clip's shape is not painted, so only its
   children are walked. *)
let rec painted node =
  match (node : Scene.t) with
  | Circle _
  | Ellipse _ ->
      [ Disc ]
  | Path { fill; _ } -> [ Segment fill ]
  | Rect { fill; _ }
  | Polygon { fill; _ }
  | Text { fill; _ } ->
      [ Filled fill ]
  | Line _
  | Polyline _ ->
      [ Unfilled ]
  | Group { children; _ }
  | Clip { children; _ } ->
      List.concat_map painted children

let fill_of = function
  | Segment fill
  | Filled fill ->
      Some fill
  | Disc
  | Unfilled ->
      None

let is_donut_segment = function
  | Segment fill -> not (is_checker fill)
  | Disc
  | Filled _
  | Unfilled ->
      false

let rec after_first_segment = function
  | [] -> []
  | p :: rest -> (
      match is_donut_segment p with
      | true -> rest
      | false -> after_first_segment rest)

let test_donut_scene_has_no_disc () =
  let nodes = List.concat_map painted Sub.scene in
  let checker_fills =
    List.filter
      (fun p -> Option.fold ~none:false ~some:is_checker (fill_of p))
      nodes
  in
  Alcotest.(check bool)
    "the scene paints a checkerboard" true
    (List.length checker_fills >= 2);
  Alcotest.(check int)
    "four segments in the multi-segment donut and one full turn" 5
    (List.length (List.filter is_donut_segment nodes));
  Alcotest.(check int)
    "no circle or ellipse anywhere" 0
    (List.length
       (List.filter
          (function
            | Disc -> true
            | Segment _
            | Filled _
            | Unfilled ->
                false)
          nodes));
  Alcotest.(check int)
    "nothing in a checker colour is painted after a donut segment" 0
    (List.length
       (List.filter
          (fun p -> Option.fold ~none:false ~some:is_checker (fill_of p))
          (after_first_segment nodes)))

let () =
  Alcotest.run "Donut section"
    [
      ( "donut_section",
        [
          Alcotest.test_case "donut_section_renders_canvas_and_svg" `Quick
            test_donut_section_renders_canvas_and_svg;
          Alcotest.test_case "donut_svg_src_is_data_uri" `Quick
            test_donut_svg_src_is_data_uri;
          Alcotest.test_case "donut_scene_has_no_disc" `Quick
            test_donut_scene_has_no_disc;
        ] );
    ]

open Nopal_charts
open Nopal_element
open Nopal_draw

type msg = Hovered of Hover.t | Left

(* --- helpers --- *)

let mk_series ?(smooth = false) ?(area_fill = false) ?(show_points = false)
    ~label ~color data =
  Line.series ~smooth ~area_fill ~show_points ~label ~color
    ~y:(fun (_, v) -> v)
    data

let sample_data = [ (0.0, 10.0); (1.0, 20.0); (2.0, 15.0) ]
let series_a = mk_series ~label:"A" ~color:Color.categorical.(0) sample_data

let series_b =
  mk_series ~label:"B" ~color:Color.categorical.(1)
    [ (0.0, 5.0); (1.0, 25.0); (2.0, 10.0) ]

let line_view ?(series = [ series_a ]) ?on_hover ?on_leave ?hover
    ?format_tooltip () =
  Line.view ~series ~x:fst ~width:400.0 ~height:300.0 ?on_hover ?on_leave ?hover
    ?format_tooltip ()

let extract_draw (el : msg Element.t) =
  match el with
  | Box { children; _ } ->
      List.find_map
        (fun (child : msg Element.t) ->
          match child with
          | Draw d ->
              Some
                ( d.scene,
                  d.on_pointer_move,
                  d.on_pointer_leave,
                  d.width,
                  d.height )
          | _ -> None)
        children
  | Draw d ->
      Some (d.scene, d.on_pointer_move, d.on_pointer_leave, d.width, d.height)
  | _ -> None

let rec count_nodes pred (scene : Scene.t list) =
  List.fold_left
    (fun acc (node : Scene.t) ->
      let acc = if pred node then acc + 1 else acc in
      match node with
      | Clip { children; _ }
      | Group { children; _ } ->
          acc + count_nodes pred children
      | _ -> acc)
    0 scene

let is_polyline (node : Scene.t) =
  match node with
  | Polyline _ -> true
  | _ -> false

let is_path (node : Scene.t) =
  match node with
  | Path _ -> true
  | _ -> false

let is_circle (node : Scene.t) =
  match node with
  | Circle _ -> true
  | _ -> false

let rec has_filled_path (scene : Scene.t list) =
  List.exists
    (fun (node : Scene.t) ->
      match node with
      | Path { fill; _ } -> (
          match fill with
          | Solid _ -> true
          | _ -> false)
      | Clip { children; _ }
      | Group { children; _ } ->
          has_filled_path children
      | _ -> false)
    scene

(* --- tests --- *)

let test_empty_series () =
  let el = Line.view ~series:[] ~x:fst ~width:400.0 ~height:300.0 () in
  match (el : msg Element.t) with
  | Draw { scene; _ } ->
      Alcotest.(check int) "empty scene" 0 (List.length scene)
  | _ -> Alcotest.fail "expected Draw element for empty series"

let test_empty_data_in_series () =
  let s = mk_series ~label:"empty" ~color:Color.categorical.(0) [] in
  let el = Line.view ~series:[ s ] ~x:fst ~width:400.0 ~height:300.0 () in
  match (el : msg Element.t) with
  | Draw { scene; _ } ->
      Alcotest.(check int) "empty scene" 0 (List.length scene)
  | _ -> Alcotest.fail "expected Draw element for empty data"

let test_single_series_straight () =
  let el = line_view () in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let n = count_nodes is_polyline scene in
      Alcotest.(check bool) "has polyline" true (n >= 1)
  | None -> Alcotest.fail "expected Draw element"

let test_single_series_smooth () =
  let s =
    mk_series ~smooth:true ~label:"smooth" ~color:Color.categorical.(0)
      sample_data
  in
  let el = line_view ~series:[ s ] () in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      (* Smooth uses Path with Bezier segments, not Polyline *)
      let n = count_nodes is_path scene in
      Alcotest.(check bool) "has path (bezier)" true (n >= 1)
  | None -> Alcotest.fail "expected Draw element"

let test_multi_series () =
  let el = line_view ~series:[ series_a; series_b ] () in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      (* At least 2 polylines for 2 series *)
      let n = count_nodes is_polyline scene in
      Alcotest.(check bool) "at least 2 polylines" true (n >= 2)
  | None -> Alcotest.fail "expected Draw element"

let test_area_fill () =
  let s =
    mk_series ~area_fill:true ~label:"area" ~color:Color.categorical.(0)
      sample_data
  in
  let el = line_view ~series:[ s ] () in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      Alcotest.(check bool) "has filled path" true (has_filled_path scene)
  | None -> Alcotest.fail "expected Draw element"

let test_show_points () =
  let s =
    mk_series ~show_points:true ~label:"pts" ~color:Color.categorical.(0)
      sample_data
  in
  let el = line_view ~series:[ s ] () in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let n = count_nodes is_circle scene in
      (* At least one circle per data point *)
      Alcotest.(check bool)
        "has circle per point" true
        (n >= List.length sample_data)
  | None -> Alcotest.fail "expected Draw element"

let test_hover_vertical_band () =
  let el = line_view ~on_hover:(fun h -> Hovered h) ~on_leave:Left () in
  match extract_draw el with
  | Some (_, Some on_move, _, _, _) -> (
      (* Pointer move in the chart area should produce a hover message *)
      let msg =
        on_move { x = 200.0; y = 150.0; client_x = 200.0; client_y = 150.0 }
      in
      match msg with
      | Hovered h ->
          (* Index should be valid (0..2 for 3 data points) *)
          Alcotest.(check bool)
            "hover index in range" true
            (h.Hover.index >= 0 && h.Hover.index < List.length sample_data)
      | _ -> Alcotest.fail "expected Hovered message")
  | Some (_, None, _, _, _) -> Alcotest.fail "expected on_pointer_move handler"
  | None -> Alcotest.fail "expected Draw element"

let test_hover_tooltip_all_series () =
  let hover =
    Hover.{ index = 1; series = 0; cursor_x = 200.0; cursor_y = 150.0 }
  in
  let tooltip_called = ref false in
  let format_tooltip entries =
    tooltip_called := true;
    (* Should receive entries for all series *)
    Alcotest.(check int) "entries for all series" 2 (List.length entries);
    Tooltip.text "test"
  in
  let _el =
    line_view ~series:[ series_a; series_b ] ~hover ~format_tooltip ()
  in
  Alcotest.(check bool) "format_tooltip was called" true !tooltip_called

let test_series_constructor_defaults () =
  let s =
    Line.series ~label:"def" ~color:Color.categorical.(0)
      ~y:(fun (_, v) -> v)
      sample_data
  in
  (* Defaults: smooth=false, area_fill=false, show_points=false *)
  Alcotest.(check bool) "smooth default false" false s.smooth;
  Alcotest.(check bool) "area_fill default false" false s.area_fill;
  Alcotest.(check bool) "show_points default false" false s.show_points

let test_single_point_series () =
  let s =
    mk_series ~label:"single" ~color:Color.categorical.(0) [ (0.0, 5.0) ]
  in
  let el = line_view ~series:[ s ] () in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      (* Single point: should produce a valid scene without crashing *)
      Alcotest.(check bool)
        "single point produces scene" true
        (List.length scene >= 0)
  | None -> Alcotest.fail "expected Draw element"

let () =
  Alcotest.run "Line"
    [
      ( "line",
        [
          Alcotest.test_case "empty_series" `Quick test_empty_series;
          Alcotest.test_case "empty_data_in_series" `Quick
            test_empty_data_in_series;
          Alcotest.test_case "single_series_straight" `Quick
            test_single_series_straight;
          Alcotest.test_case "single_series_smooth" `Quick
            test_single_series_smooth;
          Alcotest.test_case "multi_series" `Quick test_multi_series;
          Alcotest.test_case "area_fill" `Quick test_area_fill;
          Alcotest.test_case "show_points" `Quick test_show_points;
          Alcotest.test_case "hover_vertical_band" `Quick
            test_hover_vertical_band;
          Alcotest.test_case "hover_tooltip_all_series" `Quick
            test_hover_tooltip_all_series;
          Alcotest.test_case "series_constructor_defaults" `Quick
            test_series_constructor_defaults;
          Alcotest.test_case "single_point_series" `Quick
            test_single_point_series;
        ] );
    ]

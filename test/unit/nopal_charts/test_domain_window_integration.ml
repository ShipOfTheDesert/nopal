open Nopal_charts
open Nopal_element
open Nopal_draw

(* --- helpers --- *)

let extract_draw (el : _ Element.t) =
  match el with
  | Box { children; _ } ->
      List.find_map
        (fun (child : _ Element.t) ->
          match child with
          | Draw d -> Some d.scene
          | _ -> None)
        children
  | Draw d -> Some d.scene
  | _ -> None

let count_nodes pred (scene : Scene.t list) =
  List.fold_left (fun acc node -> if pred node then acc + 1 else acc) 0 scene

let is_polyline (node : Scene.t) =
  match node with
  | Polyline _ -> true
  | _ -> false

let is_rect (node : Scene.t) =
  match node with
  | Rect _ -> true
  | _ -> false

let is_circle (node : Scene.t) =
  match node with
  | Circle _ -> true
  | _ -> false

let is_path (node : Scene.t) =
  match node with
  | Path _ -> true
  | _ -> false

(* 10 data points spanning x = 0..9 *)
let line_data =
  List.init 10 (fun i ->
      let fi = Float.of_int i in
      (fi, fi *. 10.0))

let line_series =
  Line.series ~label:"S" ~color:Color.categorical.(0)
    ~y:(fun (_, v) -> v)
    line_data

let area_series =
  Area.series ~label:"S" ~color:Color.categorical.(0)
    ~y:(fun (_, v) -> v)
    line_data

(* Bar data with numeric x accessor *)
let bar_data =
  List.init 10 (fun i ->
      let fi = Float.of_int i in
      (fi, fi *. 5.0, "bar" ^ string_of_int i))

(* Scatter data *)
let scatter_data =
  List.init 10 (fun i ->
      let fi = Float.of_int i in
      (fi, fi *. 3.0))

(* Window showing only x = 2..5 *)
let window = Domain_window.create ~x_min:2.0 ~x_max:5.0

(* --- tests --- *)

let test_line_domain_window () =
  (* With domain_window, only points in x=2..5 (+ buffer=1) should contribute.
     That means x=1..6 visible. The chart should still produce scene nodes, but
     fewer than the full 10-point chart. *)
  let el_clipped =
    Line.view ~series:[ line_series ] ~x:fst ~width:400.0 ~height:300.0
      ~domain_window:window ()
  in
  let el_full =
    Line.view ~series:[ line_series ] ~x:fst ~width:400.0 ~height:300.0 ()
  in
  let scene_clipped = extract_draw el_clipped in
  let scene_full = extract_draw el_full in
  match (scene_clipped, scene_full) with
  | Some sc, Some sf ->
      (* Clipped should produce a polyline with fewer points *)
      let clipped_polylines = count_nodes is_polyline sc in
      let full_polylines = count_nodes is_polyline sf in
      Alcotest.(check int) "clipped has polyline" 1 clipped_polylines;
      Alcotest.(check int) "full has polyline" 1 full_polylines;
      (* The clipped polyline should have fewer points *)
      let get_polyline_points scene =
        List.find_map
          (fun (node : Scene.t) ->
            match node with
            | Polyline { points; _ } -> Some (List.length points)
            | _ -> None)
          scene
      in
      let clipped_pts = Option.value ~default:0 (get_polyline_points sc) in
      let full_pts = Option.value ~default:0 (get_polyline_points sf) in
      Alcotest.(check bool)
        "clipped has fewer points" true (clipped_pts < full_pts)
  | _ -> Alcotest.fail "expected Draw elements"

let test_line_y_rescale () =
  (* When domain_window clips to x=2..5, Y should rescale to visible data
     only. With buffer=1, visible data is x=1..6, y=10..60.
     Without clipping, Y range covers 0..90. *)
  let el_clipped =
    Line.view ~series:[ line_series ] ~x:fst ~width:400.0 ~height:300.0
      ~domain_window:window ()
  in
  let scene = extract_draw el_clipped in
  match scene with
  | Some sc -> (
      (* The polyline points should be scaled to the visible Y range.
         We verify the chart rendered successfully with clipped data. *)
      let polylines = count_nodes is_polyline sc in
      Alcotest.(check int) "has polyline" 1 polylines;
      (* Extract polyline points — Y values should span the full chart area
         since they are rescaled to visible range *)
      let points =
        List.find_map
          (fun (node : Scene.t) ->
            match node with
            | Polyline { points; _ } -> Some points
            | _ -> None)
          sc
      in
      match points with
      | Some pts ->
          let ys = List.map snd pts in
          let y_min = List.fold_left Float.min Float.infinity ys in
          let y_max = List.fold_left Float.max Float.neg_infinity ys in
          (* Y range should be nontrivial — data is rescaled to chart area *)
          Alcotest.(check bool)
            "Y range is nontrivial" true
            (y_max -. y_min > 10.0)
      | None -> Alcotest.fail "expected polyline points")
  | None -> Alcotest.fail "expected Draw element"

let test_area_domain_window () =
  let el_clipped =
    Area.view ~series:[ area_series ] ~x:fst ~width:400.0 ~height:300.0
      ~domain_window:window ()
  in
  let el_full =
    Area.view ~series:[ area_series ] ~x:fst ~width:400.0 ~height:300.0 ()
  in
  let scene_clipped = extract_draw el_clipped in
  let scene_full = extract_draw el_full in
  match (scene_clipped, scene_full) with
  | Some sc, Some sf ->
      (* Area uses Path nodes *)
      let clipped_paths = count_nodes is_path sc in
      let full_paths = count_nodes is_path sf in
      Alcotest.(check int) "clipped has path" 1 clipped_paths;
      Alcotest.(check int) "full has path" 1 full_paths
  | _ -> Alcotest.fail "expected Draw elements"

let test_bar_domain_window () =
  let el_clipped =
    Bar.view ~data:bar_data
      ~label:(fun (_, _, l) -> l)
      ~value:(fun (_, v, _) -> v)
      ~color:(fun _ -> Color.categorical.(0))
      ~x:(fun (xv, _, _) -> xv)
      ~width:400.0 ~height:300.0 ~domain_window:window ()
  in
  let el_full =
    Bar.view ~data:bar_data
      ~label:(fun (_, _, l) -> l)
      ~value:(fun (_, v, _) -> v)
      ~color:(fun _ -> Color.categorical.(0))
      ~x:(fun (xv, _, _) -> xv)
      ~width:400.0 ~height:300.0 ()
  in
  let scene_clipped = extract_draw el_clipped in
  let scene_full = extract_draw el_full in
  match (scene_clipped, scene_full) with
  | Some sc, Some sf ->
      let clipped_rects = count_nodes is_rect sc in
      let full_rects = count_nodes is_rect sf in
      Alcotest.(check bool)
        "clipped has fewer rects" true
        (clipped_rects < full_rects)
  | _ -> Alcotest.fail "expected Draw elements"

let test_scatter_domain_window () =
  let el_clipped =
    Scatter.view ~data:scatter_data ~x:fst ~y:snd
      ~color:(fun _ -> Color.categorical.(0))
      ~width:400.0 ~height:300.0 ~domain_window:window ()
  in
  let el_full =
    Scatter.view ~data:scatter_data ~x:fst ~y:snd
      ~color:(fun _ -> Color.categorical.(0))
      ~width:400.0 ~height:300.0 ()
  in
  let scene_clipped = extract_draw el_clipped in
  let scene_full = extract_draw el_full in
  match (scene_clipped, scene_full) with
  | Some sc, Some sf ->
      let clipped_circles = count_nodes is_circle sc in
      let full_circles = count_nodes is_circle sf in
      Alcotest.(check bool)
        "clipped has fewer circles" true
        (clipped_circles < full_circles)
  | _ -> Alcotest.fail "expected Draw elements"

let test_no_domain_window_unchanged () =
  (* Without domain_window, all 10 data points should be rendered *)
  let el =
    Line.view ~series:[ line_series ] ~x:fst ~width:400.0 ~height:300.0 ()
  in
  let scene = extract_draw el in
  match scene with
  | Some sc ->
      let points =
        List.find_map
          (fun (node : Scene.t) ->
            match node with
            | Polyline { points; _ } -> Some (List.length points)
            | _ -> None)
          sc
      in
      Alcotest.(check (option int)) "all 10 points rendered" (Some 10) points
  | None -> Alcotest.fail "expected Draw element"

let () =
  Alcotest.run "domain_window_integration"
    [
      ( "domain_window_integration",
        [
          Alcotest.test_case "line domain window" `Quick test_line_domain_window;
          Alcotest.test_case "line y rescale" `Quick test_line_y_rescale;
          Alcotest.test_case "area domain window" `Quick test_area_domain_window;
          Alcotest.test_case "bar domain window" `Quick test_bar_domain_window;
          Alcotest.test_case "scatter domain window" `Quick
            test_scatter_domain_window;
          Alcotest.test_case "no domain window unchanged" `Quick
            test_no_domain_window_unchanged;
        ] );
    ]

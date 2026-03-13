open Nopal_charts
open Nopal_element
open Nopal_draw

type msg = Hovered of Hover.t | Left | Noop

(* --- helpers --- *)

let sample = [ (1.0, 10.0); (2.0, 20.0); (3.0, 15.0); (4.0, 25.0) ]

let scatter_view ?(on_hover = fun _ -> Noop) ?(on_leave = Noop) ?hover ?radius
    ?format_tooltip data =
  Scatter.view ~data ~x:fst ~y:snd
    ~color:(fun _ -> Color.categorical.(0))
    ~width:400.0 ~height:300.0 ~on_hover ~on_leave ?hover ?radius
    ?format_tooltip ()

let extract_draw = Chart_test_helpers.extract_draw

let count_circles (scene : Scene.t list) =
  List.fold_left
    (fun acc (node : Scene.t) ->
      match node with
      | Circle _ -> acc + 1
      | _ -> acc)
    0 scene

let get_circle_radii (scene : Scene.t list) =
  List.filter_map
    (fun (node : Scene.t) ->
      match node with
      | Circle { r; _ } -> Some r
      | _ -> None)
    scene

(* --- tests --- *)

let test_empty_data () =
  let el = scatter_view [] in
  match (el : msg Element.t) with
  | Draw { scene; _ } ->
      Alcotest.(check int) "empty scene" 0 (List.length scene)
  | _ -> Alcotest.fail "expected Draw element for empty data"

let test_points_as_circles () =
  let el = scatter_view sample in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let n = count_circles scene in
      Alcotest.(check bool)
        "at least one circle per datum" true
        (n >= List.length sample)
  | None -> Alcotest.fail "expected Draw element"

let test_variable_radius () =
  let radius (x, _y) = x *. 2.0 in
  let el = scatter_view ~radius sample in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let radii = get_circle_radii scene in
      (* With variable radius, not all radii should be the same *)
      let all_same =
        match radii with
        | [] -> true
        | r :: rest -> List.for_all (fun r2 -> Float.equal r r2) rest
      in
      Alcotest.(check bool) "radii vary" false all_same
  | None -> Alcotest.fail "expected Draw element"

let test_default_radius () =
  let el = scatter_view sample in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let radii = get_circle_radii scene in
      (* Without radius function, all points should have same size (4.0) *)
      let all_default = List.for_all (fun r -> Float.equal r 4.0) radii in
      Alcotest.(check bool) "all radii are 4.0" true all_default
  | None -> Alcotest.fail "expected Draw element"

let test_hover_enlarged_point () =
  let hover =
    Hover.{ index = 1; series = 0; cursor_x = 200.0; cursor_y = 150.0 }
  in
  let el_no_hover = scatter_view sample in
  let el_hover = scatter_view ~hover sample in
  match (extract_draw el_no_hover, extract_draw el_hover) with
  | Some (scene_no, _, _, _, _), Some (scene_yes, _, _, _, _) ->
      let radii_no = get_circle_radii scene_no in
      let radii_yes = get_circle_radii scene_yes in
      (* The hovered point (index 1) should have a larger radius *)
      let r_no = List.nth radii_no 1 in
      let r_yes = List.nth radii_yes 1 in
      Alcotest.(check bool) "hovered point enlarged" true (r_yes > r_no)
  | _ -> Alcotest.fail "expected Draw elements"

let test_hit_map_circle_regions () =
  let el =
    Scatter.view ~data:sample ~x:fst ~y:snd
      ~color:(fun _ -> Color.categorical.(0))
      ~width:400.0 ~height:300.0
      ~on_hover:(fun h -> Hovered h)
      ~on_leave:Left ()
  in
  match extract_draw el with
  | Some (_, Some on_move, _, _, _) ->
      (* The handler should be present and callable *)
      let _msg =
        on_move { x = 200.0; y = 150.0; client_x = 200.0; client_y = 150.0 }
      in
      ()
  | Some (_, None, _, _, _) -> Alcotest.fail "expected on_pointer_move handler"
  | None -> Alcotest.fail "expected Draw element"

let test_topmost_overlap () =
  (* Three points: index 0 at origin, indices 1 and 2 overlap at (10,10).
     Default padding: top=40, right=20, bottom=40, left=50; w=400, h=300.
     chart_x=50, chart_width=330, chart_y=40, chart_height=220.
     X domain 0..10, range 50..380 → x=10 maps to 380.
     Y domain 0..10, range 260..40 → y=10 maps to 40.
     Last-drawn (index 2) should take hit priority over index 1. *)
  let data = [ (0.0, 0.0); (10.0, 10.0); (10.0, 10.0) ] in
  let el =
    Scatter.view ~data ~x:fst ~y:snd
      ~color:(fun _ -> Color.categorical.(0))
      ~width:400.0 ~height:300.0
      ~on_hover:(fun h -> Hovered h)
      ~on_leave:Left ()
  in
  match extract_draw el with
  | Some (_, Some on_move, _, _, _) -> (
      let msg =
        on_move { x = 380.0; y = 40.0; client_x = 380.0; client_y = 40.0 }
      in
      match msg with
      | Hovered h ->
          (* Hit map traverses in reverse, so index 2 (last drawn) wins *)
          Alcotest.(check int) "topmost point hit" 2 h.Hover.index
      | _ -> Alcotest.fail "expected Hovered message")
  | Some (_, None, _, _, _) -> Alcotest.fail "expected on_pointer_move handler"
  | None -> Alcotest.fail "expected Draw element"

let () =
  Alcotest.run "Scatter"
    [
      ( "scatter",
        [
          Alcotest.test_case "empty_data" `Quick test_empty_data;
          Alcotest.test_case "points_as_circles" `Quick test_points_as_circles;
          Alcotest.test_case "variable_radius" `Quick test_variable_radius;
          Alcotest.test_case "default_radius" `Quick test_default_radius;
          Alcotest.test_case "hover_enlarged_point" `Quick
            test_hover_enlarged_point;
          Alcotest.test_case "hit_map_circle_regions" `Quick
            test_hit_map_circle_regions;
          Alcotest.test_case "topmost_overlap" `Quick test_topmost_overlap;
        ] );
    ]

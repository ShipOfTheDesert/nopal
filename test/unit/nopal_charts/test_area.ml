open Nopal_charts
open Nopal_element
open Nopal_draw

type msg = Hovered of Hover.t | Left

(* --- helpers --- *)

let sample_data = [ (0.0, 10.0); (1.0, 20.0); (2.0, 15.0) ]

let mk_series ~label ~color data =
  Area.series ~label ~color ~y:(fun (_, v) -> v) data

let series_a = mk_series ~label:"A" ~color:Color.categorical.(0) sample_data

let series_b =
  mk_series ~label:"B" ~color:Color.categorical.(1)
    [ (0.0, 5.0); (1.0, 25.0); (2.0, 10.0) ]

let area_view ?(series = [ series_a ]) ?(mode = Area.Overlapping) ?on_hover
    ?on_leave ?hover ?format_tooltip () =
  Area.view ~series ~x:fst ~width:400.0 ~height:300.0 ~mode ?on_hover ?on_leave
    ?hover ?format_tooltip ()

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

let has_filled_path (scene : Scene.t list) =
  List.exists
    (fun (node : Scene.t) ->
      match node with
      | Path { fill; _ } -> (
          match fill with
          | Solid _ -> true
          | _ -> false)
      | _ -> false)
    scene

let count_filled_paths (scene : Scene.t list) =
  List.fold_left
    (fun acc (node : Scene.t) ->
      match node with
      | Path { fill; _ } -> (
          match fill with
          | Solid _ -> acc + 1
          | _ -> acc)
      | _ -> acc)
    0 scene

(* --- tests --- *)

let test_empty_series () =
  let el = Area.view ~series:[] ~x:fst ~width:400.0 ~height:300.0 () in
  match (el : msg Element.t) with
  | Draw { scene; _ } ->
      Alcotest.(check int) "empty scene" 0 (List.length scene)
  | _ -> Alcotest.fail "expected Draw element for empty series"

let test_overlapping_mode () =
  let el = area_view ~series:[ series_a; series_b ] ~mode:Overlapping () in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      (* Each series should produce a filled path from baseline y=0 *)
      let n = count_filled_paths scene in
      Alcotest.(check bool) "at least 2 filled paths for 2 series" true (n >= 2)
  | None -> Alcotest.fail "expected Draw element"

let test_stacked_mode () =
  let el = area_view ~series:[ series_a; series_b ] ~mode:Stacked () in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      (* Stacked: should also produce filled paths *)
      let n = count_filled_paths scene in
      Alcotest.(check bool) "at least 2 filled paths for stacked" true (n >= 2)
  | None -> Alcotest.fail "expected Draw element"

let test_stacked_values_accumulated () =
  (* In stacked mode, second series baseline = first series top.
     We verify by checking that the scene differs from overlapping. *)
  let el_stacked = area_view ~series:[ series_a; series_b ] ~mode:Stacked () in
  let el_overlap =
    area_view ~series:[ series_a; series_b ] ~mode:Overlapping ()
  in
  match (extract_draw el_stacked, extract_draw el_overlap) with
  | Some (scene_s, _, _, _, _), Some (scene_o, _, _, _, _) ->
      (* Stacked and overlapping should produce different scenes *)
      Alcotest.(check bool)
        "stacked differs from overlapping" true (scene_s <> scene_o)
  | _ -> Alcotest.fail "expected Draw elements"

let test_produces_filled_paths () =
  let el = area_view () in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      Alcotest.(check bool) "has filled path" true (has_filled_path scene)
  | None -> Alcotest.fail "expected Draw element"

let test_hover_vertical_band () =
  let el = area_view ~on_hover:(fun h -> Hovered h) ~on_leave:Left () in
  match extract_draw el with
  | Some (_, Some on_move, _, _, _) -> (
      let msg = on_move { x = 200.0; y = 150.0 } in
      match msg with
      | Hovered h ->
          Alcotest.(check bool)
            "hover index in range" true
            (h.Hover.index >= 0 && h.Hover.index < List.length sample_data)
      | _ -> Alcotest.fail "expected Hovered message")
  | Some (_, None, _, _, _) -> Alcotest.fail "expected on_pointer_move handler"
  | None -> Alcotest.fail "expected Draw element"

let test_blend_mode_overlapping () =
  (* In overlapping mode, areas should use semi-transparent fill *)
  let el = area_view ~series:[ series_a; series_b ] ~mode:Overlapping () in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let has_alpha =
        List.exists
          (fun (node : Scene.t) ->
            match node with
            | Path { fill; _ } -> (
                match fill with
                | Solid c -> c.Color.a < 1.0
                | _ -> false)
            | _ -> false)
          scene
      in
      Alcotest.(check bool) "overlapping uses alpha" true has_alpha
  | None -> Alcotest.fail "expected Draw element"

let () =
  Alcotest.run "Area"
    [
      ( "area",
        [
          Alcotest.test_case "empty_series" `Quick test_empty_series;
          Alcotest.test_case "overlapping_mode" `Quick test_overlapping_mode;
          Alcotest.test_case "stacked_mode" `Quick test_stacked_mode;
          Alcotest.test_case "stacked_values_accumulated" `Quick
            test_stacked_values_accumulated;
          Alcotest.test_case "produces_filled_paths" `Quick
            test_produces_filled_paths;
          Alcotest.test_case "hover_vertical_band" `Quick
            test_hover_vertical_band;
          Alcotest.test_case "blend_mode_overlapping" `Quick
            test_blend_mode_overlapping;
        ] );
    ]

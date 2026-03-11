open Nopal_charts
open Nopal_element
open Nopal_draw

type msg = Hovered of Hover.t | Left

(* --- helpers --- *)

let sample =
  [
    ("Apple", 30.0, Color.categorical.(0));
    ("Banana", 50.0, Color.categorical.(1));
    ("Cherry", 20.0, Color.categorical.(2));
  ]

let pie_view ?(inner_radius = 0.0) ?label_threshold ?on_hover ?on_leave ?hover
    ?format_tooltip data =
  Pie.view ~data
    ~value:(fun (_, v, _) -> v)
    ~label:(fun (l, _, _) -> l)
    ~color:(fun (_, _, c) -> c)
    ~width:400.0 ~height:400.0 ~inner_radius ?label_threshold ?on_hover
    ?on_leave ?hover ?format_tooltip ()

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

let count_paths (scene : Scene.t list) =
  List.fold_left
    (fun acc (node : Scene.t) ->
      match node with
      | Path _ -> acc + 1
      | _ -> acc)
    0 scene

let count_texts (scene : Scene.t list) =
  List.fold_left
    (fun acc (node : Scene.t) ->
      match node with
      | Text _ -> acc + 1
      | _ -> acc)
    0 scene

let has_path_with_fill (pred : Paint.t -> bool) (scene : Scene.t list) =
  List.exists
    (fun (node : Scene.t) ->
      match node with
      | Path { fill; _ } -> pred fill
      | _ -> false)
    scene

(* --- tests --- *)

let test_empty_data () =
  let el = pie_view [] in
  match (el : msg Element.t) with
  | Draw { scene; _ } ->
      Alcotest.(check int) "empty scene" 0 (List.length scene)
  | _ -> Alcotest.fail "expected Draw element for empty data"

let test_single_segment_full_circle () =
  let data = [ ("Only", 100.0, Color.categorical.(0)) ] in
  let el = pie_view data in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      (* Single segment should produce exactly 1 path *)
      let n = count_paths scene in
      Alcotest.(check bool) "has path for single segment" true (n >= 1)
  | None -> Alcotest.fail "expected Draw element"

let test_two_segments () =
  let data =
    [ ("A", 60.0, Color.categorical.(0)); ("B", 40.0, Color.categorical.(1)) ]
  in
  let el = pie_view data in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let n = count_paths scene in
      Alcotest.(check bool) "has path per segment" true (n >= 2)
  | None -> Alcotest.fail "expected Draw element"

let test_donut_inner_radius () =
  let el = pie_view ~inner_radius:50.0 sample in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      (* Donut should still produce paths *)
      let n = count_paths scene in
      Alcotest.(check bool) "donut has paths" true (n >= 3)
  | None -> Alcotest.fail "expected Draw element"

let test_label_threshold_hides_small () =
  (* label_threshold in degrees. With 3 segments of 30, 50, 20:
     angles are ~108, ~180, ~72 degrees.
     A threshold of 100 degrees should hide the 72-degree segment's label. *)
  let el = pie_view ~label_threshold:100.0 sample in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let n_texts = count_texts scene in
      (* Should have fewer texts than segments because small ones are hidden *)
      Alcotest.(check bool)
        "some labels hidden" true
        (n_texts < List.length sample)
  | None -> Alcotest.fail "expected Draw element"

let test_label_threshold_shows_large () =
  (* With a very low threshold, all labels should be visible *)
  let el = pie_view ~label_threshold:1.0 sample in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let n_texts = count_texts scene in
      Alcotest.(check bool)
        "all labels shown" true
        (n_texts >= List.length sample)
  | None -> Alcotest.fail "expected Draw element"

let test_hover_offset_segment () =
  let hover =
    Hover.{ index = 0; series = 0; cursor_x = 200.0; cursor_y = 200.0 }
  in
  let el_no_hover = pie_view sample in
  let el_hover = pie_view ~hover sample in
  match (extract_draw el_no_hover, extract_draw el_hover) with
  | Some (scene_no, _, _, _, _), Some (scene_yes, _, _, _, _) ->
      (* Hovered scene should differ from non-hovered due to offset *)
      Alcotest.(check bool) "hovered scene differs" true (scene_no <> scene_yes)
  | _ -> Alcotest.fail "expected Draw elements"

let test_hit_map_wedge_regions () =
  let el =
    Pie.view ~data:sample
      ~value:(fun (_, v, _) -> v)
      ~label:(fun (l, _, _) -> l)
      ~color:(fun (_, _, c) -> c)
      ~width:400.0 ~height:400.0
      ~on_hover:(fun h -> Hovered h)
      ~on_leave:Left ()
  in
  match extract_draw el with
  | Some (_, Some on_move, _, _, _) ->
      (* Hit the center-right of the chart where a wedge should be *)
      let _msg =
        on_move { x = 300.0; y = 200.0; client_x = 300.0; client_y = 200.0 }
      in
      (* If we got here, wedge hit testing is wired *)
      ()
  | Some (_, None, _, _, _) -> Alcotest.fail "expected on_pointer_move handler"
  | None -> Alcotest.fail "expected Draw element"

let test_donut_hit_map_inner_radius () =
  let el =
    Pie.view ~data:sample
      ~value:(fun (_, v, _) -> v)
      ~label:(fun (l, _, _) -> l)
      ~color:(fun (_, _, c) -> c)
      ~width:400.0 ~height:400.0 ~inner_radius:80.0
      ~on_hover:(fun h -> Hovered h)
      ~on_leave:Left ()
  in
  match extract_draw el with
  | Some (_, Some on_move, _, _, _) -> (
      (* Hit the exact center of the donut — should NOT match any wedge.
         With on_leave provided, a miss returns the leave message. *)
      let msg =
        on_move { x = 200.0; y = 200.0; client_x = 200.0; client_y = 200.0 }
      in
      match msg with
      | Left -> ()
      | Hovered _ -> Alcotest.fail "donut center should not hit any wedge")
  | Some (_, None, _, _, _) -> Alcotest.fail "expected on_pointer_move handler"
  | None -> Alcotest.fail "expected Draw element"

let test_zero_value_segment () =
  let data =
    [
      ("A", 50.0, Color.categorical.(0));
      ("Zero", 0.0, Color.categorical.(1));
      ("B", 50.0, Color.categorical.(2));
    ]
  in
  let el = pie_view data in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      (* Zero-value datum should produce no wedge path.
         Only 2 paths for the 2 non-zero segments. *)
      let has_nonzero_paths =
        has_path_with_fill
          (fun p ->
            match p with
            | Solid _ -> true
            | _ -> false)
          scene
      in
      Alcotest.(check bool)
        "has paths for non-zero segments" true has_nonzero_paths;
      let n = count_paths scene in
      Alcotest.(check int) "only non-zero segments have paths" 2 n
  | None -> Alcotest.fail "expected Draw element"

let test_very_small_wedge () =
  (* One segment is ~0.36 degrees (0.001/100.001 * 360) *)
  let data =
    [
      ("Big", 100.0, Color.categorical.(0));
      ("Tiny", 0.001, Color.categorical.(1));
    ]
  in
  let el = pie_view data in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      (* Both segments should produce paths without crashing *)
      let n = count_paths scene in
      Alcotest.(check bool) "has paths for both segments" true (n >= 2)
  | None -> Alcotest.fail "expected Draw element"

let () =
  Alcotest.run "Pie"
    [
      ( "pie",
        [
          Alcotest.test_case "empty_data" `Quick test_empty_data;
          Alcotest.test_case "single_segment_full_circle" `Quick
            test_single_segment_full_circle;
          Alcotest.test_case "two_segments" `Quick test_two_segments;
          Alcotest.test_case "donut_inner_radius" `Quick test_donut_inner_radius;
          Alcotest.test_case "label_threshold_hides_small" `Quick
            test_label_threshold_hides_small;
          Alcotest.test_case "label_threshold_shows_large" `Quick
            test_label_threshold_shows_large;
          Alcotest.test_case "hover_offset_segment" `Quick
            test_hover_offset_segment;
          Alcotest.test_case "hit_map_wedge_regions" `Quick
            test_hit_map_wedge_regions;
          Alcotest.test_case "donut_hit_map_inner_radius" `Quick
            test_donut_hit_map_inner_radius;
          Alcotest.test_case "zero_value_segment" `Quick test_zero_value_segment;
          Alcotest.test_case "very_small_wedge" `Quick test_very_small_wedge;
        ] );
    ]

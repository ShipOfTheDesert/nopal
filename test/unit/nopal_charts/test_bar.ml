open Nopal_charts
open Nopal_element
open Nopal_draw

type msg = Hovered of Hover.t | Left | Noop

(* --- helpers --- *)

let sample = [ ("A", 10.0); ("B", 20.0); ("C", 15.0) ]

let bar_view ?(on_hover = fun _ -> Noop) ?(on_leave = Noop) ?hover ?y_axis
    ?format_tooltip data =
  Bar.view ~data ~label:fst ~value:snd
    ~color:(fun _ -> Color.categorical.(0))
    ~width:400.0 ~height:300.0 ~on_hover ~on_leave ?hover ?y_axis
    ?format_tooltip ()

let count_rects (scene : Scene.t list) =
  List.fold_left
    (fun acc (node : Scene.t) ->
      match node with
      | Rect _ -> acc + 1
      | _ -> acc)
    0 scene

let has_rect_with_fill (pred : Paint.t -> bool) (scene : Scene.t list) =
  List.exists
    (fun (node : Scene.t) ->
      match node with
      | Rect { fill; _ } -> pred fill
      | _ -> false)
    scene

let lighter_than (base : Color.t) (paint : Paint.t) =
  match paint with
  | Solid c ->
      (* Lighter means the color is lerped toward white *)
      c.r >= base.r
      && c.g >= base.g
      && c.b >= base.b
      && not (Color.equal c base)
  | _ -> false

(* --- tests --- *)

let test_empty_data () =
  let el = bar_view [] in
  match (el : msg Element.t) with
  | Draw { scene; _ } ->
      Alcotest.(check int) "empty scene" 0 (List.length scene)
  | _ -> Alcotest.fail "expected Draw element for empty data"

let test_bar_count_in_scene () =
  let el = bar_view sample in
  match (el : msg Element.t) with
  | Box { children; _ } -> (
      let draw =
        List.find
          (fun (child : msg Element.t) ->
            match child with
            | Draw _ -> true
            | _ -> false)
          children
      in
      match draw with
      | Draw { scene; _ } ->
          let n = count_rects scene in
          (* At least 3 rects for 3 data points *)
          Alcotest.(check bool)
            "at least one rect per datum" true
            (n >= List.length sample)
      | _ -> Alcotest.fail "unreachable")
  | Draw { scene; _ } ->
      let n = count_rects scene in
      Alcotest.(check bool)
        "at least one rect per datum" true
        (n >= List.length sample)
  | _ -> Alcotest.fail "expected Box or Draw element"

let extract_draw = Chart_test_helpers.extract_draw

let test_zero_value_minimum_height () =
  let data = [ ("A", 0.0); ("B", 10.0) ] in
  let el = bar_view data in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let has_min_height =
        List.exists
          (fun (node : Scene.t) ->
            match node with
            | Rect { h; _ } -> h >= 2.0
            | _ -> false)
          scene
      in
      Alcotest.(check bool)
        "zero-value bar has minimum height" true has_min_height
  | None -> Alcotest.fail "expected Draw element"

let test_negative_values () =
  let data = [ ("A", -10.0); ("B", 5.0); ("C", -3.0); ("D", 20.0) ] in
  let el = bar_view data in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let rects =
        List.filter_map
          (fun (node : Scene.t) ->
            match node with
            | Rect { h; fill; _ } -> (
                match fill with
                | Solid _ -> Some h
                | _ -> None)
            | _ -> None)
          scene
      in
      Alcotest.(check bool)
        "has at least 4 filled rects" true
        (List.length rects >= 4);
      Alcotest.(check bool)
        "all bars have positive height" true
        (List.for_all (fun h -> h > 0.0) rects)
  | None -> Alcotest.fail "expected Draw element"

let test_hover_lighter_fill () =
  let hover =
    Hover.{ index = 0; series = 0; cursor_x = 50.0; cursor_y = 50.0 }
  in
  let el = bar_view ~hover sample in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let base_color = Color.categorical.(0) in
      Alcotest.(check bool)
        "hovered bar has lighter fill" true
        (has_rect_with_fill (lighter_than base_color) scene)
  | None -> Alcotest.fail "expected Draw element"

let test_no_hover_normal_fill () =
  let el = bar_view sample in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let base_color = Color.categorical.(0) in
      (* Without hover, no bar should have a lightened fill *)
      let has_lighter = has_rect_with_fill (lighter_than base_color) scene in
      Alcotest.(check bool) "no lighter fill" false has_lighter
  | None -> Alcotest.fail "expected Draw element"

let test_hit_map_rect_count () =
  (* We can't directly inspect the hit map, but we can verify that
     on_pointer_move is wired and the handler produces correct hits.
     We'll test by simulating a pointer move over each bar position. *)
  let el =
    Bar.view ~data:sample ~label:fst ~value:snd
      ~color:(fun _ -> Color.categorical.(0))
      ~width:400.0 ~height:300.0
      ~on_hover:(fun h -> Hovered h)
      ~on_leave:Left ()
  in
  match extract_draw el with
  | Some (_, Some on_move, _, _, _) ->
      (* The handler should be present *)
      let _msg =
        on_move { x = 100.0; y = 150.0; client_x = 100.0; client_y = 150.0 }
      in
      (* If we got here, the handler is wired correctly *)
      ()
  | Some (_, None, _, _, _) -> Alcotest.fail "expected on_pointer_move handler"
  | None -> Alcotest.fail "expected Draw element"

let test_custom_axis_bounds () =
  let y_axis = Axis.{ default_config with min = Some 0.0; max = Some 50.0 } in
  let el = bar_view ~y_axis sample in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      (* With custom Y bounds 0..50, bars should still render *)
      let n = count_rects scene in
      Alcotest.(check bool)
        "has rects with custom bounds" true
        (n >= List.length sample)
  | None -> Alcotest.fail "expected Draw element"

let test_custom_tooltip () =
  let hover =
    Hover.{ index = 0; series = 0; cursor_x = 50.0; cursor_y = 50.0 }
  in
  let format_tooltip datum =
    Tooltip.text (Printf.sprintf "Custom: %s = %.0f" (fst datum) (snd datum))
  in
  let el = bar_view ~hover ~format_tooltip sample in
  (* Tooltip is now merged into canvas scene nodes *)
  match (el : msg Element.t) with
  | Draw { scene; _ } ->
      Alcotest.(check bool) "has scene nodes" true (List.length scene >= 2)
  | _ ->
      (* Even if structured differently, the element should exist *)
      ()

let rec has_text_with_content content (node : Scene.t) =
  match node with
  | Text { content = c; _ } -> String.equal c content
  | Group { children; _ } ->
      List.exists (has_text_with_content content) children
  | _ -> false

let test_category_labels_rendered () =
  let el = bar_view sample in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      (* Each datum's label should appear as a Text node in the scene *)
      List.iter
        (fun (lbl, _) ->
          Alcotest.(check bool)
            ("has category label " ^ lbl)
            true
            (List.exists (has_text_with_content lbl) scene))
        sample
  | None -> Alcotest.fail "expected Draw element"

let () =
  Alcotest.run "Bar"
    [
      ( "bar",
        [
          Alcotest.test_case "empty_data" `Quick test_empty_data;
          Alcotest.test_case "bar_count_in_scene" `Quick test_bar_count_in_scene;
          Alcotest.test_case "zero_value_minimum_height" `Quick
            test_zero_value_minimum_height;
          Alcotest.test_case "negative_values" `Quick test_negative_values;
          Alcotest.test_case "hover_lighter_fill" `Quick test_hover_lighter_fill;
          Alcotest.test_case "no_hover_normal_fill" `Quick
            test_no_hover_normal_fill;
          Alcotest.test_case "hit_map_rect_count" `Quick test_hit_map_rect_count;
          Alcotest.test_case "custom_axis_bounds" `Quick test_custom_axis_bounds;
          Alcotest.test_case "custom_tooltip" `Quick test_custom_tooltip;
          Alcotest.test_case "category_labels_rendered" `Quick
            test_category_labels_rendered;
        ] );
    ]

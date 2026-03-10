open Nopal_charts
open Nopal_element
open Nopal_draw

let test_empty_data () =
  let el = Sparkline.view ~data:[] ~width:100.0 ~height:20.0 () in
  match (el : _ Element.t) with
  | Draw { scene; _ } ->
      Alcotest.(check int) "empty scene" 0 (List.length scene)
  | _ -> Alcotest.fail "expected Draw element"

let test_single_point () =
  let el = Sparkline.view ~data:[ 5.0 ] ~width:100.0 ~height:20.0 () in
  match (el : _ Element.t) with
  | Draw _ -> ()
  | _ -> Alcotest.fail "expected Draw element"

let test_produces_draw_element () =
  let el =
    Sparkline.view ~data:[ 1.0; 2.0; 3.0 ] ~width:100.0 ~height:20.0 ()
  in
  match (el : _ Element.t) with
  | Draw { width; height; _ } ->
      Alcotest.(check (float 0.01)) "width" 100.0 width;
      Alcotest.(check (float 0.01)) "height" 20.0 height
  | _ -> Alcotest.fail "expected Draw element"

let test_no_interaction () =
  let el =
    Sparkline.view ~data:[ 1.0; 2.0; 3.0 ] ~width:100.0 ~height:20.0 ()
  in
  match (el : _ Element.t) with
  | Draw { on_pointer_move; on_click; on_pointer_leave; _ } ->
      Alcotest.(check bool)
        "no on_pointer_move" true
        (Option.is_none on_pointer_move);
      Alcotest.(check bool) "no on_click" true (Option.is_none on_click);
      Alcotest.(check bool)
        "no on_pointer_leave" true
        (Option.is_none on_pointer_leave)
  | _ -> Alcotest.fail "expected Draw element"

let has_stroke_color color (scene : Scene.t list) =
  List.exists
    (fun (node : Scene.t) ->
      match node with
      | Polyline { stroke; _ } -> Paint.equal (Solid color) stroke.paint
      | _ -> false)
    scene

let test_custom_color () =
  let color = Color.red in
  let el =
    Sparkline.view ~data:[ 1.0; 2.0 ] ~width:100.0 ~height:20.0 ~color ()
  in
  match (el : _ Element.t) with
  | Draw { scene; _ } ->
      Alcotest.(check bool)
        "uses custom color" true
        (has_stroke_color color scene)
  | _ -> Alcotest.fail "expected Draw element"

let has_stroke_width w (scene : Scene.t list) =
  List.exists
    (fun (node : Scene.t) ->
      match node with
      | Polyline { stroke; _ } -> Float.equal stroke.width w
      | _ -> false)
    scene

let test_custom_stroke_width () =
  let el =
    Sparkline.view ~data:[ 1.0; 2.0 ] ~width:100.0 ~height:20.0
      ~stroke_width:3.0 ()
  in
  match (el : _ Element.t) with
  | Draw { scene; _ } ->
      Alcotest.(check bool)
        "uses custom stroke width" true
        (has_stroke_width 3.0 scene)
  | _ -> Alcotest.fail "expected Draw element"

let () =
  Alcotest.run "Sparkline"
    [
      ( "sparkline",
        [
          Alcotest.test_case "empty_data" `Quick test_empty_data;
          Alcotest.test_case "single_point" `Quick test_single_point;
          Alcotest.test_case "produces_draw_element" `Quick
            test_produces_draw_element;
          Alcotest.test_case "no_interaction" `Quick test_no_interaction;
          Alcotest.test_case "custom_color" `Quick test_custom_color;
          Alcotest.test_case "custom_stroke_width" `Quick
            test_custom_stroke_width;
        ] );
    ]

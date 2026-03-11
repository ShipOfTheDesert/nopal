open Nopal_charts
open Nopal_element

type msg = Noop [@@warning "-37"]

let sample_scene =
  [
    Nopal_draw.Scene.rect
      ~fill:(Nopal_draw.Paint.solid Nopal_draw.Color.black)
      ~x:0.0 ~y:0.0 ~w:100.0 ~h:100.0 ();
  ]

let test_compose_without_tooltip () =
  let el =
    Chart_compose.compose ~scene:sample_scene ~tooltip_scene:[] ~width:400.0
      ~height:300.0 ()
  in
  match (el : msg Element.t) with
  | Draw { scene; _ } ->
      Alcotest.(check int) "scene has original nodes" 1 (List.length scene)
  | _ -> Alcotest.fail "expected Draw element"

let test_compose_with_tooltip () =
  let tip_scene =
    Tooltip.scene ~x:50.0 ~y:50.0 ~chart_width:400.0 ~chart_height:300.0 "hello"
  in
  let el =
    Chart_compose.compose ~scene:sample_scene ~tooltip_scene:tip_scene
      ~width:400.0 ~height:300.0 ()
  in
  match (el : msg Element.t) with
  | Draw { scene; _ } ->
      (* original scene + tooltip scene nodes *)
      Alcotest.(check bool) "merged scene" true (List.length scene > 1)
  | _ -> Alcotest.fail "expected Draw element"

let test_compose_dimensions () =
  let el =
    Chart_compose.compose ~scene:sample_scene ~tooltip_scene:[] ~width:400.0
      ~height:300.0 ()
  in
  match (el : msg Element.t) with
  | Draw { width; height; _ } ->
      Alcotest.(check (float 0.01)) "width" 400.0 width;
      Alcotest.(check (float 0.01)) "height" 300.0 height
  | _ -> Alcotest.fail "expected Draw element"

let () =
  Alcotest.run "Chart_compose"
    [
      ( "compose",
        [
          Alcotest.test_case "without_tooltip" `Quick
            test_compose_without_tooltip;
          Alcotest.test_case "with_tooltip" `Quick test_compose_with_tooltip;
          Alcotest.test_case "dimensions" `Quick test_compose_dimensions;
        ] );
    ]

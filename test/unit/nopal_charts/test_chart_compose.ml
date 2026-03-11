open Nopal_charts
open Nopal_element

type msg = Noop [@@warning "-37"]

let sample_scene =
  [
    Nopal_draw.Scene.rect
      ~fill:(Nopal_draw.Paint.solid Nopal_draw.Color.black)
      ~x:0.0 ~y:0.0 ~w:100.0 ~h:100.0 ();
  ]

let test_compose_with_tooltip () =
  let draw_el = Element.draw ~width:400.0 ~height:300.0 sample_scene in
  let tooltip =
    Some
      (Tooltip.container ~x:50.0 ~y:50.0 ~chart_width:400.0 ~chart_height:300.0
         (Tooltip.text "hello"))
  in
  let el = Chart_compose.compose ~draw_el ~width:400.0 ~height:300.0 ~tooltip in
  match (el : msg Element.t) with
  | Box { children; _ } ->
      (* Should have both draw and tooltip children *)
      Alcotest.(check bool) "has children" true (List.length children >= 2)
  | _ -> Alcotest.fail "expected Box element"

let test_compose_dimensions () =
  let draw_el = Element.draw ~width:400.0 ~height:300.0 sample_scene in
  let el =
    Chart_compose.compose ~draw_el ~width:400.0 ~height:300.0 ~tooltip:None
  in
  match (el : msg Element.t) with
  | Box { style = _; children; _ } ->
      (* The draw child should preserve dimensions *)
      let has_draw =
        List.exists
          (fun (child : msg Element.t) ->
            match child with
            | Draw { width; height; _ } ->
                Float.equal width 400.0 && Float.equal height 300.0
            | _ -> false)
          children
      in
      Alcotest.(check bool) "draw child with correct dimensions" true has_draw
  | _ -> Alcotest.fail "expected Box element"

let () =
  Alcotest.run "Chart_compose"
    [
      ( "compose",
        [
          Alcotest.test_case "with_tooltip" `Quick test_compose_with_tooltip;
          Alcotest.test_case "dimensions" `Quick test_compose_dimensions;
        ] );
    ]

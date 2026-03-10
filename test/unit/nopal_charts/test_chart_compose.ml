open Nopal_charts
open Nopal_element

type msg = Noop [@@warning "-37"]

let draw_el : msg Element.t =
  Element.draw ~width:400.0 ~height:300.0
    [
      Nopal_draw.Scene.rect
        ~fill:(Nopal_draw.Paint.solid Nopal_draw.Color.black)
        ~x:0.0 ~y:0.0 ~w:100.0 ~h:100.0 ();
    ]

let test_compose_without_tooltip () =
  let el =
    Chart_compose.compose ~draw_el ~width:400.0 ~height:300.0 ~tooltip:None
  in
  match (el : msg Element.t) with
  | Box { children; _ } ->
      Alcotest.(check int) "single child (draw)" 1 (List.length children)
  | _ -> Alcotest.fail "expected Box element"

let test_compose_with_tooltip () =
  let tip = Tooltip.text "hello" in
  let tip_container =
    Tooltip.container ~x:50.0 ~y:50.0 ~chart_width:400.0 ~chart_height:300.0 tip
  in
  let el =
    Chart_compose.compose ~draw_el ~width:400.0 ~height:300.0
      ~tooltip:(Some tip_container)
  in
  match (el : msg Element.t) with
  | Box { children; _ } ->
      Alcotest.(check int)
        "two children (draw + tooltip)" 2 (List.length children)
  | _ -> Alcotest.fail "expected Box element"

let test_compose_fixed_dimensions () =
  let el =
    Chart_compose.compose ~draw_el ~width:400.0 ~height:300.0 ~tooltip:None
  in
  match (el : msg Element.t) with
  | Box { style; _ } ->
      (* Verify the style has Fixed width and height by checking it was set *)
      let expected =
        Nopal_style.Style.default
        |> Nopal_style.Style.with_layout (fun l ->
            { l with width = Fixed 400.0; height = Fixed 300.0 })
      in
      Alcotest.(check bool) "style matches" true (style = expected)
  | _ -> Alcotest.fail "expected Box element"

let () =
  Alcotest.run "Chart_compose"
    [
      ( "compose",
        [
          Alcotest.test_case "without_tooltip" `Quick
            test_compose_without_tooltip;
          Alcotest.test_case "with_tooltip" `Quick test_compose_with_tooltip;
          Alcotest.test_case "fixed_dimensions" `Quick
            test_compose_fixed_dimensions;
        ] );
    ]

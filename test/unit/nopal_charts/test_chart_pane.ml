open Nopal_charts
open Nopal_element
open Nopal_style

type msg =
  | PointerDown of float
  | PointerMove of float
  | PointerUp
  | PointerLeave
[@@warning "-37"]

(* --- helpers --- *)

let window = Domain_window.create ~x_min:0.0 ~x_max:10.0
let dummy_chart _dw ~width ~height = Element.draw ~width ~height []
let make_pane ratio chart = Chart_pane.pane ~height_ratio:ratio chart

(** Extract children of a Column element, searching through Box wrappers. *)
let get_column_children (el : msg Element.t) =
  match el with
  | Column { children; _ } -> Some children
  | Box { children; _ } ->
      List.find_map
        (fun (child : msg Element.t) ->
          match child with
          | Column { children; _ } -> Some children
          | _ -> None)
        children
  | _ -> None

(** Get the fixed height from a Box element's style. *)
let get_fixed_height (el : msg Element.t) =
  match el with
  | Box { style; _ } -> (
      match style.Style.layout.height with
      | Fixed h -> Some h
      | _ -> None)
  | _ -> None

(* --- tests --- *)

let test_single_pane () =
  let el =
    Chart_pane.view
      ~panes:[ make_pane 1.0 dummy_chart ]
      ~domain_window:window ~width:400.0 ~height:300.0 ()
  in
  match get_column_children el with
  | Some children ->
      Alcotest.(check int) "one pane child" 1 (List.length children)
  | None -> (
      match el with
      | Column { children; _ } ->
          Alcotest.(check int) "one pane child" 1 (List.length children)
      | _ -> Alcotest.fail "expected Column layout")

let test_two_panes_equal () =
  let el =
    Chart_pane.view
      ~panes:[ make_pane 1.0 dummy_chart; make_pane 1.0 dummy_chart ]
      ~domain_window:window ~width:400.0 ~height:300.0 ()
  in
  match get_column_children el with
  | Some [ p1; p2 ] -> (
      let h1 = get_fixed_height p1 in
      let h2 = get_fixed_height p2 in
      match (h1, h2) with
      | Some h1, Some h2 ->
          Alcotest.(check (float 0.01)) "pane 1 height" 150.0 h1;
          Alcotest.(check (float 0.01)) "pane 2 height" 150.0 h2
      | _ -> Alcotest.fail "expected fixed heights on pane boxes")
  | Some children ->
      Alcotest.failf "expected 2 children, got %d" (List.length children)
  | None -> Alcotest.fail "expected Column layout"

let test_three_panes_custom_ratio () =
  let el =
    Chart_pane.view
      ~panes:
        [
          make_pane 0.6 dummy_chart;
          make_pane 0.2 dummy_chart;
          make_pane 0.2 dummy_chart;
        ]
      ~domain_window:window ~width:400.0 ~height:300.0 ()
  in
  match get_column_children el with
  | Some [ p1; p2; p3 ] -> (
      let h1 = get_fixed_height p1 in
      let h2 = get_fixed_height p2 in
      let h3 = get_fixed_height p3 in
      match (h1, h2, h3) with
      | Some h1, Some h2, Some h3 ->
          Alcotest.(check (float 0.01)) "pane 1 height (60%)" 180.0 h1;
          Alcotest.(check (float 0.01)) "pane 2 height (20%)" 60.0 h2;
          Alcotest.(check (float 0.01)) "pane 3 height (20%)" 60.0 h3
      | _ -> Alcotest.fail "expected fixed heights on pane boxes")
  | Some children ->
      Alcotest.failf "expected 3 children, got %d" (List.length children)
  | None -> Alcotest.fail "expected Column layout"

let test_domain_window_passed () =
  let received_window = ref None in
  let chart dw ~width ~height =
    received_window := Some dw;
    Element.draw ~width ~height []
  in
  let _el =
    Chart_pane.view
      ~panes:[ make_pane 1.0 chart ]
      ~domain_window:window ~width:400.0 ~height:300.0 ()
  in
  match !received_window with
  | Some dw ->
      Alcotest.(check bool)
        "received correct window" true
        (Domain_window.equal dw window)
  | None -> Alcotest.fail "chart function was not called with domain window"

let test_produces_column_layout () =
  let el =
    Chart_pane.view
      ~panes:[ make_pane 1.0 dummy_chart; make_pane 1.0 dummy_chart ]
      ~domain_window:window ~width:400.0 ~height:300.0 ()
  in
  let has_column = get_column_children el in
  Alcotest.(check bool) "has Column layout" true (Option.is_some has_column)

let test_pointer_down_on_box () =
  let el =
    Chart_pane.view
      ~panes:[ make_pane 1.0 dummy_chart ]
      ~domain_window:window ~width:400.0 ~height:300.0
      ~on_pointer_down:(fun pe -> PointerDown pe.x)
      ()
  in
  match el with
  | Box { on_pointer_down = Some handler; _ } -> (
      let msg =
        handler
          { Element.x = 150.0; y = 100.0; client_x = 150.0; client_y = 100.0 }
      in
      match msg with
      | PointerDown x -> Alcotest.(check (float 0.01)) "pointer down x" 150.0 x
      | _ -> Alcotest.fail "expected PointerDown message")
  | _ -> Alcotest.fail "expected Box with on_pointer_down handler"

let test_pointer_leave_on_box () =
  let el =
    Chart_pane.view
      ~panes:[ make_pane 1.0 dummy_chart ]
      ~domain_window:window ~width:400.0 ~height:300.0
      ~on_pointer_leave:PointerLeave ()
  in
  match el with
  | Box { on_pointer_leave = Some msg; _ } -> (
      match msg with
      | PointerLeave -> Alcotest.(check pass) "got PointerLeave" () ()
      | _ -> Alcotest.fail "expected PointerLeave message")
  | _ -> Alcotest.fail "expected Box with on_pointer_leave"

let test_pane_constructor () =
  let p = Chart_pane.pane ~height_ratio:0.75 dummy_chart in
  Alcotest.(check (float 0.01)) "height_ratio" 0.75 p.height_ratio;
  Alcotest.(check bool) "y_axis is None" true (Option.is_none p.y_axis);
  let _el = p.chart window in
  Alcotest.(check pass) "chart function callable" () ()

let () =
  Alcotest.run "Chart_pane"
    [
      ( "chart_pane",
        [
          Alcotest.test_case "single_pane" `Quick test_single_pane;
          Alcotest.test_case "two_panes_equal" `Quick test_two_panes_equal;
          Alcotest.test_case "three_panes_custom_ratio" `Quick
            test_three_panes_custom_ratio;
          Alcotest.test_case "domain_window_passed" `Quick
            test_domain_window_passed;
          Alcotest.test_case "produces_column_layout" `Quick
            test_produces_column_layout;
          Alcotest.test_case "pointer_down_on_box" `Quick
            test_pointer_down_on_box;
          Alcotest.test_case "pointer_leave_on_box" `Quick
            test_pointer_leave_on_box;
          Alcotest.test_case "pane_constructor" `Quick test_pane_constructor;
        ] );
    ]

open Nopal_charts
open Nopal_draw
open Nopal_test.Test_renderer

type msg = Hovered of Hover.t | Left

let sample = [ ("A", 10.0); ("B", 20.0); ("C", 15.0) ]

let bar_element ?(on_hover = fun h -> Hovered h) ?(on_leave = Left) ?hover
    ?format_tooltip () =
  Bar.view ~data:sample ~label:fst ~value:snd
    ~color:(fun _ -> Color.categorical.(0))
    ~width:400.0 ~height:300.0 ~on_hover ~on_leave ?hover ?format_tooltip ()

let test_bar_render_and_hover_simulation () =
  let el = bar_element () in
  let r = render el in
  let canvas = find (By_tag "canvas") (tree r) in
  Alcotest.(check bool) "canvas found" true (Option.is_some canvas);
  let result = pointer_move (By_tag "canvas") ~x:100.0 ~y:150.0 r in
  match result with
  | Ok () -> (
      let msgs = messages r in
      Alcotest.(check bool) "at least one message" true (List.length msgs >= 1);
      match msgs with
      | Hovered h :: _ ->
          Alcotest.(check bool) "hover index non-negative" true (h.index >= 0)
      | _ -> Alcotest.fail "expected Hovered message")
  | Error (Not_found _) -> Alcotest.fail "canvas not found for pointer_move"
  | Error (No_handler _) -> Alcotest.fail "no pointer_move handler on canvas"

let test_bar_pointer_leave () =
  let el = bar_element () in
  let r = render el in
  let result = pointer_leave (By_tag "canvas") r in
  match result with
  | Ok () -> (
      let msgs = messages r in
      Alcotest.(check bool) "has leave message" true (List.length msgs = 1);
      match msgs with
      | [ Left ] -> ()
      | _ -> Alcotest.fail "expected Left message")
  | Error (Not_found _) -> Alcotest.fail "canvas not found"
  | Error (No_handler _) -> Alcotest.fail "no pointer_leave handler"

let test_line_render_structure () =
  let s =
    Line.series ~label:"Series A" ~color:Color.categorical.(0) ~y:snd
      [ (0.0, 10.0); (1.0, 20.0); (2.0, 15.0) ]
  in
  let el =
    Line.view ~series:[ s ] ~x:fst ~width:400.0 ~height:300.0
      ~on_hover:(fun h -> Hovered h)
      ~on_leave:Left ()
  in
  let r = render el in
  let t = tree r in
  let canvas = find (By_tag "canvas") t in
  Alcotest.(check bool) "line canvas found" true (Option.is_some canvas);
  match canvas with
  | Some c -> (
      let scene_nodes = attr "scene-nodes" c in
      match scene_nodes with
      | Some n ->
          Alcotest.(check bool) "has scene nodes" true (int_of_string n > 0)
      | None -> Alcotest.fail "missing scene-nodes attr")
  | None -> Alcotest.fail "unreachable"

let test_pie_render_structure () =
  let data = [ ("Slice A", 30.0); ("Slice B", 70.0) ] in
  let el =
    Pie.view ~data ~value:snd ~label:fst
      ~color:(fun _ -> Color.categorical.(1))
      ~width:300.0 ~height:300.0
      ~on_hover:(fun h -> Hovered h)
      ~on_leave:Left ()
  in
  let r = render el in
  let t = tree r in
  let canvas = find (By_tag "canvas") t in
  Alcotest.(check bool) "pie canvas found" true (Option.is_some canvas);
  match canvas with
  | Some c -> (
      let scene_nodes = attr "scene-nodes" c in
      match scene_nodes with
      | Some n ->
          Alcotest.(check bool) "pie has scene nodes" true (int_of_string n > 0)
      | None -> Alcotest.fail "missing scene-nodes attr")
  | None -> Alcotest.fail "unreachable"

let test_tooltip_appears_on_hover () =
  let hover =
    Hover.{ index = 0; series = 0; cursor_x = 50.0; cursor_y = 50.0 }
  in
  let format_tooltip datum = Tooltip.text (fst datum) in
  let el = bar_element ~hover ~format_tooltip () in
  let r = render el in
  let t = tree r in
  (* With hover + format_tooltip, bar chart wraps in a Box with tooltip child *)
  let boxes = find_all (By_tag "box") t in
  (* Tooltip container is a Box; there should be at least one box wrapping
     both canvas and tooltip content *)
  Alcotest.(check bool) "has box wrapper" true (List.length boxes >= 1);
  let canvas = find (By_tag "canvas") t in
  Alcotest.(check bool) "canvas still present" true (Option.is_some canvas)

let test_tooltip_absent_without_hover () =
  let el = bar_element () in
  let r = render el in
  let t = tree r in
  (* Without hover, bar chart has no tooltip. The tree structure is simpler —
     either a bare canvas or a box with just canvas (no tooltip children). *)
  let all_boxes = find_all (By_tag "box") t in
  let canvas_count = List.length (find_all (By_tag "canvas") t) in
  (* With no hover, there should be exactly 1 canvas and minimal structure *)
  Alcotest.(check int) "single canvas" 1 canvas_count;
  (* If there's a box wrapper, it should have few children (no tooltip) *)
  List.iter
    (fun box ->
      match box with
      | Element { children; _ } ->
          (* A box without tooltip should not have text children *)
          let has_tooltip_text =
            List.exists
              (fun child ->
                let tc = text_content child in
                String.length tc > 0)
              children
          in
          Alcotest.(check bool) "no tooltip text in box" false has_tooltip_text
      | _ -> ())
    all_boxes

let () =
  Alcotest.run "Charts_structural"
    [
      ( "structural",
        [
          Alcotest.test_case "bar_render_and_hover_simulation" `Quick
            test_bar_render_and_hover_simulation;
          Alcotest.test_case "bar_pointer_leave" `Quick test_bar_pointer_leave;
          Alcotest.test_case "line_render_structure" `Quick
            test_line_render_structure;
          Alcotest.test_case "pie_render_structure" `Quick
            test_pie_render_structure;
          Alcotest.test_case "tooltip_appears_on_hover" `Quick
            test_tooltip_appears_on_hover;
          Alcotest.test_case "tooltip_absent_without_hover" `Quick
            test_tooltip_absent_without_hover;
        ] );
    ]

(* The dashboard example's view, read structurally: every chart is named, and
   the detail panel shows the hovered month, or the prompt on a miss. *)

open Nopal_test.Test_renderer

let vp = Nopal_element.Viewport.desktop

let panel_text model =
  let panel =
    find
      (By_attr ("data-testid", "detail-panel"))
      (tree (render (Dashboard_app.view vp model)))
  in
  match panel with
  | Some n -> text_content n
  | None -> Alcotest.fail "no detail panel"

let names =
  [
    "Monthly revenue, January to June";
    "Monthly revenue and costs, January to June";
    "Revenue breakdown by product";
  ]

let check_canvas_decided canvas =
  match
    (attr "role" canvas, attr "aria-label" canvas, attr "aria-hidden" canvas)
  with
  | Some "img", Some _, None -> ()
  | None, None, Some "true" -> ()
  | _ -> Alcotest.fail "an undecided canvas"

let test_names () =
  let model, _ = Dashboard_app.init () in
  let t = tree (render (Dashboard_app.view vp model)) in
  List.iter
    (fun n ->
      match find (By_attr ("aria-label", n)) t with
      | Some node ->
          Alcotest.(check bool)
            (n ^ " is a canvas") true
            (List.memq node (find_all (By_tag "canvas") t));
          Alcotest.(check (option string))
            (n ^ " role") (Some "img") (attr "role" node)
      | None -> Alcotest.fail ("no node named " ^ n))
    names;
  List.iter check_canvas_decided (find_all (By_tag "canvas") t)

let drawn name = Nopal_element.Element.draw ~name ~width:10.0 ~height:10.0 []

let test_blank () =
  let el = Dashboard_app__Named_graphic.named_graphic "  " drawn in
  let t = tree (render el) in
  Alcotest.(check bool)
    "refusal shown as text" true
    (find (By_text (Dashboard_app__Named_graphic.refusal_message "  ")) t
    <> None);
  Alcotest.(check bool)
    "no canvas drawn" true
    (find_all (By_tag "canvas") t = [])

let hover index =
  Nopal_charts.Hover.{ index; series = 0; cursor_x = 0.0; cursor_y = 0.0 }

let test_hit () =
  let model, _ = Dashboard_app.init () in
  let model, _ =
    Dashboard_app.update model (Dashboard_app.ChartHovered (hover 1))
  in
  Alcotest.(check string)
    "Feb selected" "Selected: Feb — Revenue: 45, Costs: 25, Customers: 150"
    (panel_text model)

let test_miss () =
  let model, _ = Dashboard_app.init () in
  let model, _ =
    Dashboard_app.update model (Dashboard_app.ChartHovered (hover 99))
  in
  Alcotest.(check string)
    "out of range falls back" "Hover over a chart to see details"
    (panel_text model)

let () =
  Alcotest.run "dashboard"
    [
      ( "view",
        [
          Alcotest.test_case "names" `Quick test_names;
          Alcotest.test_case "blank" `Quick test_blank;
          Alcotest.test_case "hit" `Quick test_hit;
          Alcotest.test_case "miss" `Quick test_miss;
        ] );
    ]

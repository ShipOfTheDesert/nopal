open Nopal_charts
open Nopal_element

let is_not_empty el =
  match (el : _ Element.t) with
  | Empty -> false
  | _ -> true

let get_box_style (el : _ Element.t) =
  match el with
  | Box { style; _ } -> Some style
  | _ -> None

let test_text_produces_element () =
  let el = Tooltip.text "foo" in
  Alcotest.(check bool) "not empty" true (is_not_empty el)

let test_container_produces_element () =
  let content = Tooltip.text "hello" in
  let el =
    Tooltip.container ~x:100.0 ~y:100.0 ~chart_width:400.0 ~chart_height:300.0
      content
  in
  Alcotest.(check bool) "not empty" true (is_not_empty el);
  Alcotest.(check bool) "is a box" true (Option.is_some (get_box_style el))

let test_container_stays_in_bounds_right () =
  let content = Tooltip.text "tip" in
  (* Place tooltip near the right edge *)
  let el =
    Tooltip.container ~x:380.0 ~y:100.0 ~chart_width:400.0 ~chart_height:300.0
      content
  in
  match get_box_style el with
  | Some style ->
      (* When near right edge, padding_left should position the tooltip
         to the left of the cursor, so padding_left should be less than x *)
      let pl = style.layout.padding_left in
      Alcotest.(check bool)
        "tooltip flips left (padding_left < x)" true (pl < 380.0)
  | None -> Alcotest.fail "expected a Box element"

let test_container_stays_in_bounds_bottom () =
  let content = Tooltip.text "tip" in
  (* Place tooltip near the bottom edge *)
  let el =
    Tooltip.container ~x:100.0 ~y:280.0 ~chart_width:400.0 ~chart_height:300.0
      content
  in
  match get_box_style el with
  | Some style ->
      (* When near bottom edge, padding_top should position the tooltip
         above the cursor, so padding_top should be less than y *)
      let pt = style.layout.padding_top in
      Alcotest.(check bool)
        "tooltip flips up (padding_top < y)" true (pt < 280.0)
  | None -> Alcotest.fail "expected a Box element"

let test_container_stays_in_bounds_corner () =
  let content = Tooltip.text "tip" in
  (* Place tooltip near both right and bottom edges simultaneously *)
  let el =
    Tooltip.container ~x:380.0 ~y:280.0 ~chart_width:400.0 ~chart_height:300.0
      content
  in
  match get_box_style el with
  | Some style ->
      let pl = style.layout.padding_left in
      let pt = style.layout.padding_top in
      Alcotest.(check bool)
        "tooltip flips left (padding_left < x)" true (pl < 380.0);
      Alcotest.(check bool)
        "tooltip flips up (padding_top < y)" true (pt < 280.0)
  | None -> Alcotest.fail "expected a Box element"

let () =
  Alcotest.run "Tooltip"
    [
      ( "tooltip",
        [
          Alcotest.test_case "text_produces_element" `Quick
            test_text_produces_element;
          Alcotest.test_case "container_produces_element" `Quick
            test_container_produces_element;
          Alcotest.test_case "container_stays_in_bounds_right" `Quick
            test_container_stays_in_bounds_right;
          Alcotest.test_case "container_stays_in_bounds_bottom" `Quick
            test_container_stays_in_bounds_bottom;
          Alcotest.test_case "container_stays_in_bounds_corner" `Quick
            test_container_stays_in_bounds_corner;
        ] );
    ]

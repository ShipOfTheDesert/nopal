open Nopal_charts
open Nopal_element

let red = Nopal_draw.Color.red
let blue = Nopal_draw.Color.blue

let test_empty_entries () =
  let el = Legend.view ~entries:[] () in
  match (el : _ Element.t) with
  | Empty -> ()
  | _ -> Alcotest.fail "expected Empty for no entries"

let test_horizontal_layout () =
  let entries =
    [ Legend.entry ~label:"A" ~color:red; Legend.entry ~label:"B" ~color:blue ]
  in
  let el = Legend.view ~entries () in
  match (el : _ Element.t) with
  | Row _ -> ()
  | _ -> Alcotest.fail "expected Row for horizontal (default) direction"

let test_vertical_layout () =
  let entries =
    [ Legend.entry ~label:"A" ~color:red; Legend.entry ~label:"B" ~color:blue ]
  in
  let el = Legend.view ~entries ~direction:Vertical () in
  match (el : _ Element.t) with
  | Column _ -> ()
  | _ -> Alcotest.fail "expected Column for vertical direction"

let test_entry_count () =
  let entries =
    [
      Legend.entry ~label:"A" ~color:red;
      Legend.entry ~label:"B" ~color:blue;
      Legend.entry ~label:"C" ~color:red;
    ]
  in
  let el = Legend.view ~entries () in
  match (el : _ Element.t) with
  | Row { children; _ } ->
      Alcotest.(check int) "3 entries" 3 (List.length children)
  | _ -> Alcotest.fail "expected Row"

let rec contains_text label (el : _ Element.t) =
  match el with
  | Text s -> String.equal s label
  | Box { children; _ }
  | Row { children; _ }
  | Column { children; _ } ->
      List.exists (contains_text label) children
  | _ -> false

let test_entry_labels () =
  let entries =
    [
      Legend.entry ~label:"Sales" ~color:red;
      Legend.entry ~label:"Costs" ~color:blue;
    ]
  in
  let el = Legend.view ~entries () in
  match (el : _ Element.t) with
  | Row { children; _ } ->
      Alcotest.(check bool)
        "contains Sales" true
        (List.exists (contains_text "Sales") children);
      Alcotest.(check bool)
        "contains Costs" true
        (List.exists (contains_text "Costs") children)
  | _ -> Alcotest.fail "expected Row"

let () =
  Alcotest.run "Legend"
    [
      ( "legend",
        [
          Alcotest.test_case "empty_entries" `Quick test_empty_entries;
          Alcotest.test_case "horizontal_layout" `Quick test_horizontal_layout;
          Alcotest.test_case "vertical_layout" `Quick test_vertical_layout;
          Alcotest.test_case "entry_count" `Quick test_entry_count;
          Alcotest.test_case "entry_labels" `Quick test_entry_labels;
        ] );
    ]

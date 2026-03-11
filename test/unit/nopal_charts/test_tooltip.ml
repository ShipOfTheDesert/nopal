open Nopal_charts
open Nopal_element

type msg = Noop [@@warning "-37"]

let test_text_returns_element () =
  let el = Tooltip.text "foo" in
  match (el : msg Element.t) with
  | Box _ -> ()
  | _ -> Alcotest.fail "expected Box element from Tooltip.text"

let test_container_produces_element () =
  let el =
    Tooltip.container ~x:100.0 ~y:100.0 ~chart_width:400.0 ~chart_height:300.0
      (Tooltip.text "hello")
  in
  match (el : msg Element.t) with
  | Box _ -> ()
  | _ -> Alcotest.fail "expected Box element from Tooltip.container"

let () =
  Alcotest.run "Tooltip"
    [
      ( "tooltip",
        [
          Alcotest.test_case "text_returns_element" `Quick
            test_text_returns_element;
          Alcotest.test_case "container_produces_element" `Quick
            test_container_produces_element;
        ] );
    ]

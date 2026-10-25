(* The kitchen sink's one graphic-naming helper: a good label reaches the
   graphic, a blank one is shown as visible text and never drawn. *)

open Nopal_test.Test_renderer
module Element = Nopal_element.Element

let drawn name = Element.draw ~name ~width:10.0 ~height:10.0 []

let test_named () =
  let el = Kitchen_sink_app__Named_graphic.named_graphic "A square" drawn in
  Alcotest.(check bool)
    "named canvas carries its label" true
    (find (By_attr ("aria-label", "A square")) (tree (render el)) <> None)

let test_blank () =
  let el = Kitchen_sink_app__Named_graphic.named_graphic "  " drawn in
  Alcotest.(check bool)
    "refusal shown as text" true
    (find
       (By_text (Kitchen_sink_app__Named_graphic.refusal_message "  "))
       (tree (render el))
    <> None);
  Alcotest.(check bool)
    "no canvas drawn" true
    (find_all (By_tag "canvas") (tree (render el)) = [])

let () =
  Alcotest.run "named_graphic"
    [
      ( "named_graphic",
        [
          Alcotest.test_case "named" `Quick test_named;
          Alcotest.test_case "blank" `Quick test_blank;
        ] );
    ]

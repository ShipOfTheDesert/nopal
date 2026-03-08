open Counter
open Nopal_test.Test_renderer

let test_init_count_is_zero () =
  let model, _cmd = init () in
  Alcotest.(check int) "initial count is zero" 0 model.count

let test_increment () =
  let model = { count = 0 } in
  let model', _cmd = update model Increment in
  Alcotest.(check int) "count incremented to 1" 1 model'.count

let test_decrement_from_positive () =
  let model = { count = 3 } in
  let model', _cmd = update model Decrement in
  Alcotest.(check int) "count decremented to 2" 2 model'.count

let test_decrement_at_zero () =
  let model = { count = 0 } in
  let model', _cmd = update model Decrement in
  Alcotest.(check int) "count stays at zero" 0 model'.count

let test_reset () =
  let model = { count = 42 } in
  let model', _cmd = update model Reset in
  Alcotest.(check int) "count reset to zero" 0 model'.count

let test_view_structure () =
  let r = render (view { count = 5 }) in
  let t = tree r in
  (* Top-level is a column *)
  (match t with
  | Element { tag = "column"; _ } -> ()
  | _ -> Alcotest.fail "expected top-level column");
  (* Text shows "5" *)
  let text_node = find (By_text "5") t in
  Alcotest.(check bool) "has text 5" true (Option.is_some text_node);
  (* Three buttons with correct labels *)
  let buttons = find_all (By_tag "button") t in
  Alcotest.(check int) "three buttons" 3 (List.length buttons);
  let labels = List.map text_content buttons in
  Alcotest.(check (list string)) "button labels" [ "+"; "-"; "Reset" ] labels

let () =
  Alcotest.run "counter"
    [
      ( "model",
        [
          Alcotest.test_case "init count is zero" `Quick test_init_count_is_zero;
          Alcotest.test_case "increment" `Quick test_increment;
          Alcotest.test_case "decrement from positive" `Quick
            test_decrement_from_positive;
          Alcotest.test_case "decrement at zero" `Quick test_decrement_at_zero;
          Alcotest.test_case "reset" `Quick test_reset;
        ] );
      ( "view",
        [ Alcotest.test_case "view structure" `Quick test_view_structure ] );
    ]

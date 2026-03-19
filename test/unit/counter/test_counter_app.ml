open Counter
open Nopal_test.Test_renderer

let msg_pp fmt msg =
  match msg with
  | Increment -> Format.fprintf fmt "Increment"
  | Decrement -> Format.fprintf fmt "Decrement"
  | Reset -> Format.fprintf fmt "Reset"

let msg_testable = Alcotest.testable msg_pp ( = )

let error_testable = Test_util.error_testable

let test_click_increment () =
  let r = render (view Nopal_element.Viewport.desktop { count = 0 }) in
  (* The first button in the counter view is "+" *)
  let result = click (By_tag "button") r in
  Alcotest.(check (result unit error_testable)) "click succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "messages contains Increment" [ Increment ] (messages r)

let test_full_mvu_cycle () =
  let model, r =
    run_app ~init ~update ~view [ Increment; Increment; Decrement ]
  in
  Alcotest.(check int) "final count is 1" 1 model.count;
  let t = tree r in
  let text_node = find (By_text "1") t in
  Alcotest.(check bool) "view shows 1" true (Option.is_some text_node)

let () =
  Alcotest.run "counter_app"
    [
      ( "app",
        [
          Alcotest.test_case "click increment" `Quick test_click_increment;
          Alcotest.test_case "full MVU cycle" `Quick test_full_mvu_cycle;
        ] );
    ]

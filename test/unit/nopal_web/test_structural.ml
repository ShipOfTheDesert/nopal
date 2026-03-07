open Nopal_test

let test_counter_initial_view () =
  let _model, rendered =
    Test_renderer.run_app ~init:Counter.init ~update:Counter.update
      ~view:Counter.view []
  in
  let tree = Test_renderer.tree rendered in
  let count_text = Test_renderer.find (By_text "0") tree in
  Alcotest.(check bool) "initial count is 0" true (Option.is_some count_text);
  let buttons = Test_renderer.find_all (By_tag "button") tree in
  Alcotest.(check int) "three buttons" 3 (List.length buttons)

let test_counter_increment () =
  let _model, rendered =
    Test_renderer.run_app ~init:Counter.init ~update:Counter.update
      ~view:Counter.view
      [ Counter.Increment; Counter.Increment ]
  in
  let tree = Test_renderer.tree rendered in
  let count_text = Test_renderer.find (By_text "2") tree in
  Alcotest.(check bool)
    "count is 2 after two increments" true
    (Option.is_some count_text)

let test_counter_decrement_below_zero () =
  let _model, rendered =
    Test_renderer.run_app ~init:Counter.init ~update:Counter.update
      ~view:Counter.view
      [ Counter.Decrement; Counter.Decrement ]
  in
  let tree = Test_renderer.tree rendered in
  let count_text = Test_renderer.find (By_text "-2") tree in
  Alcotest.(check bool)
    "count is -2 after two decrements" true
    (Option.is_some count_text)

let () =
  Alcotest.run "nopal_web structural"
    [
      ( "counter",
        [
          Alcotest.test_case "44: counter initial view" `Quick
            test_counter_initial_view;
          Alcotest.test_case "45: counter increment" `Quick
            test_counter_increment;
          Alcotest.test_case "46: counter decrement below zero" `Quick
            test_counter_decrement_below_zero;
        ] );
    ]

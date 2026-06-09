module Nav_stack = Nopal_navigation.Nav_stack

let test_pop_at_root_is_noop () =
  let s = Nav_stack.create "root" |> Nav_stack.pop in
  Alcotest.(check string) "current unchanged" "root" (Nav_stack.current s);
  Alcotest.(check int) "depth still 1" 1 (Nav_stack.depth s)

let test_push_sets_current_and_grows_depth () =
  let s = Nav_stack.create "root" |> Nav_stack.push "a" in
  Alcotest.(check string) "current is pushed screen" "a" (Nav_stack.current s);
  Alcotest.(check int) "depth grew to 2" 2 (Nav_stack.depth s)

let test_pop_returns_to_previous_screen () =
  let s =
    Nav_stack.create "root"
    |> Nav_stack.push "a"
    |> Nav_stack.push "b"
    |> Nav_stack.pop
  in
  Alcotest.(check string) "current is previous screen" "a" (Nav_stack.current s);
  Alcotest.(check int) "depth back to 2" 2 (Nav_stack.depth s)

let test_can_pop_reflects_depth () =
  Alcotest.(check bool)
    "root alone cannot pop" false
    (Nav_stack.can_pop (Nav_stack.create "root"));
  Alcotest.(check bool)
    "after push can pop" true
    (Nav_stack.can_pop (Nav_stack.push "a" (Nav_stack.create "root")))

let test_screens_are_root_first () =
  let s = Nav_stack.create "root" |> Nav_stack.push "a" |> Nav_stack.push "b" in
  Alcotest.(check (list string))
    "root first, current last" [ "root"; "a"; "b" ] (Nav_stack.screens s)

let test_pop_to_root_then_cannot_pop () =
  let s = Nav_stack.create "root" |> Nav_stack.push "a" |> Nav_stack.pop in
  Alcotest.(check bool) "cannot pop at root" false (Nav_stack.can_pop s);
  Alcotest.(check int) "depth is 1" 1 (Nav_stack.depth s)

let () =
  Alcotest.run "nopal_navigation_nav_stack"
    [
      ( "nav_stack",
        [
          Alcotest.test_case "pop at root is no-op" `Quick
            test_pop_at_root_is_noop;
          Alcotest.test_case "push sets current and grows depth" `Quick
            test_push_sets_current_and_grows_depth;
          Alcotest.test_case "pop returns to previous screen" `Quick
            test_pop_returns_to_previous_screen;
          Alcotest.test_case "can_pop reflects depth" `Quick
            test_can_pop_reflects_depth;
          Alcotest.test_case "screens are root first" `Quick
            test_screens_are_root_first;
          Alcotest.test_case "pop to root then cannot pop" `Quick
            test_pop_to_root_then_cannot_pop;
        ] );
    ]

open Nopal_style

let test_default_has_all_none () =
  let d = Interaction.default in
  Alcotest.(check bool) "hover is None" true (Option.is_none d.hover);
  Alcotest.(check bool) "pressed is None" true (Option.is_none d.pressed);
  Alcotest.(check bool) "focused is None" true (Option.is_none d.focused)

let test_equal_both_default () =
  Alcotest.(check bool)
    "two defaults are equal" true
    (Interaction.equal Interaction.default Interaction.default)

let test_equal_different_hover () =
  let a = Interaction.default in
  let hover_style =
    Style.with_paint
      (fun p -> { p with background = Some (Style.rgba 255 0 0 1.0) })
      Style.default
  in
  let b = { a with hover = Some hover_style } in
  Alcotest.(check bool)
    "different hover not equal" false (Interaction.equal a b)

let test_has_any_default () =
  Alcotest.(check bool)
    "default has_any is false" false
    (Interaction.has_any Interaction.default)

let test_has_any_with_hover () =
  let hover_style =
    Style.with_paint
      (fun p -> { p with background = Some (Style.rgba 0 128 0 1.0) })
      Style.default
  in
  let i = { Interaction.default with hover = Some hover_style } in
  Alcotest.(check bool)
    "has_any with hover is true" true (Interaction.has_any i)

let ring_style =
  Style.with_paint
    (fun p -> { p with background = Some (Style.rgba 0 0 255 1.0) })
    Style.default

let test_focused_within_alone_makes_has_any_true () =
  let i = { Interaction.default with focused_within = Some ring_style } in
  Alcotest.(check bool)
    "has_any with only focused_within is true" true (Interaction.has_any i)

let test_equal_distinguishes_focused_within () =
  let a = Interaction.default in
  let b = { a with focused_within = Some ring_style } in
  Alcotest.(check bool)
    "differ only in focused_within, not equal" false (Interaction.equal a b);
  Alcotest.(check bool) "reversed, not equal" false (Interaction.equal b a)

let () =
  Alcotest.run "interaction"
    [
      ( "Interaction",
        [
          Alcotest.test_case "default_has_all_none" `Quick
            test_default_has_all_none;
          Alcotest.test_case "equal_both_default" `Quick test_equal_both_default;
          Alcotest.test_case "equal_different_hover" `Quick
            test_equal_different_hover;
          Alcotest.test_case "has_any_default" `Quick test_has_any_default;
          Alcotest.test_case "has_any_with_hover" `Quick test_has_any_with_hover;
          Alcotest.test_case "focused_within_alone_makes_has_any_true" `Quick
            test_focused_within_alone_makes_has_any_true;
          Alcotest.test_case "equal_distinguishes_focused_within" `Quick
            test_equal_distinguishes_focused_within;
        ] );
    ]

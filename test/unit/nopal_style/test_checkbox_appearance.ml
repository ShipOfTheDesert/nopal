open Nopal_style

(* Fixture colours are the brand teal and white of the drawn design this type
   was built for. Each fixture is built fresh per call, so an [equal] that fell
   back to physical identity would read two equal values as different. *)
let paint_with_background background : Style.paint =
  {
    background = Some background;
    border = None;
    opacity = 1.0;
    shadow = None;
    overflow = Visible;
  }

let ticked_style () =
  Style.set_paint (paint_with_background (Color.Hex "#02403A")) Style.empty

let other_ticked_style () =
  Style.set_paint (paint_with_background (Color.Hex "#8A1C1C")) Style.empty

let drawn ~checked ~mark = Checkbox_appearance.Drawn { checked; mark }

let check_equal label expected a b =
  Alcotest.(check bool) label expected (Checkbox_appearance.equal a b)

let test_native_equals_native () =
  check_equal "Native equals Native" true Checkbox_appearance.Native
    Checkbox_appearance.Native

let test_drawn_differs_on_mark () =
  check_equal "a white tick and a black tick differ" false
    (drawn ~checked:(ticked_style ()) ~mark:(Color.Hex "#FFFFFF"))
    (drawn ~checked:(ticked_style ()) ~mark:(Color.Hex "#000000"));
  check_equal "the same drawn appearance, built twice, is equal" true
    (drawn ~checked:(ticked_style ()) ~mark:(Color.Hex "#FFFFFF"))
    (drawn ~checked:(ticked_style ()) ~mark:(Color.Hex "#FFFFFF"))

let test_drawn_differs_on_checked_style () =
  check_equal "two ticked fills differ" false
    (drawn ~checked:(ticked_style ()) ~mark:(Color.Hex "#FFFFFF"))
    (drawn ~checked:(other_ticked_style ()) ~mark:(Color.Hex "#FFFFFF"))

let test_native_differs_from_drawn () =
  let a_drawn = drawn ~checked:(ticked_style ()) ~mark:(Color.Hex "#FFFFFF") in
  check_equal "Native against Drawn" false Checkbox_appearance.Native a_drawn;
  check_equal "Drawn against Native" false a_drawn Checkbox_appearance.Native

let () =
  Alcotest.run "nopal_style_checkbox_appearance"
    [
      ( "Checkbox_appearance",
        [
          Alcotest.test_case "native_equals_native" `Quick
            test_native_equals_native;
          Alcotest.test_case "drawn_differs_on_mark" `Quick
            test_drawn_differs_on_mark;
          Alcotest.test_case "drawn_differs_on_checked_style" `Quick
            test_drawn_differs_on_checked_style;
          Alcotest.test_case "native_differs_from_drawn" `Quick
            test_native_differs_from_drawn;
        ] );
    ]

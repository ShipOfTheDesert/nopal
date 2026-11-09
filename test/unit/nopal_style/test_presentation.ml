open Nopal_style

let check_equal label expected a b =
  Alcotest.(check bool) label expected (Presentation.equal a b)

let test_equal_distinguishes_arms () =
  check_equal "Visible equals Visible" true Presentation.Visible
    Presentation.Visible;
  check_equal "Visually_hidden equals Visually_hidden" true
    Presentation.Visually_hidden Presentation.Visually_hidden;
  check_equal "Visible against Visually_hidden" false Presentation.Visible
    Presentation.Visually_hidden;
  check_equal "Visually_hidden against Visible" false
    Presentation.Visually_hidden Presentation.Visible

let () =
  Alcotest.run "nopal_style_presentation"
    [
      ( "Presentation",
        [
          Alcotest.test_case "equal_distinguishes_arms" `Quick
            test_equal_distinguishes_arms;
        ] );
    ]

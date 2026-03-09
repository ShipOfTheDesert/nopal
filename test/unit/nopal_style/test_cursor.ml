open Nopal_style.Cursor

let test_cursor_variants () =
  let cursors =
    [ Default; Pointer; Crosshair; Text; Grab; Grabbing; None_cursor ]
  in
  Alcotest.(check int) "seven variants" 7 (List.length cursors);
  Alcotest.(check bool) "Default = Default" true (equal Default Default);
  Alcotest.(check bool) "Default <> Pointer" false (equal Default Pointer);
  Alcotest.(check bool) "Grab = Grab" true (equal Grab Grab);
  Alcotest.(check bool)
    "Grabbing <> None_cursor" false
    (equal Grabbing None_cursor)

let test_cursor_to_css () =
  Alcotest.(check string) "default" "default" (to_css_string Default);
  Alcotest.(check string) "pointer" "pointer" (to_css_string Pointer);
  Alcotest.(check string) "crosshair" "crosshair" (to_css_string Crosshair);
  Alcotest.(check string) "text" "text" (to_css_string Text);
  Alcotest.(check string) "grab" "grab" (to_css_string Grab);
  Alcotest.(check string) "grabbing" "grabbing" (to_css_string Grabbing);
  Alcotest.(check string) "none" "none" (to_css_string None_cursor)

let () =
  Alcotest.run "nopal_style_cursor"
    [
      ( "Cursor",
        [
          Alcotest.test_case "cursor_variants" `Quick test_cursor_variants;
          Alcotest.test_case "cursor_to_css" `Quick test_cursor_to_css;
        ] );
    ]

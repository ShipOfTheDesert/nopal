module Viewport = Nopal_element.Viewport
module Platform = Nopal_tauri.Platform_tauri

let test_parse_safe_area_reads_all_four_insets () =
  match Platform.parse_safe_area "top=10;right=20;bottom=30;left=40;" with
  | None -> Alcotest.fail "expected Some safe_area for a well-formed payload"
  | Some insets ->
      Alcotest.(check int) "top" 10 (Viewport.safe_area_top insets);
      Alcotest.(check int) "right" 20 (Viewport.safe_area_right insets);
      Alcotest.(check int) "bottom" 30 (Viewport.safe_area_bottom insets);
      Alcotest.(check int) "left" 40 (Viewport.safe_area_left insets)

let test_parse_safe_area_rejects_malformed () =
  Alcotest.(check bool)
    "missing field -> None" true
    (Option.is_none (Platform.parse_safe_area "top=10;right=20;bottom=30;"));
  Alcotest.(check bool)
    "non-int field -> None" true
    (Option.is_none
       (Platform.parse_safe_area "top=10;right=xx;bottom=30;left=40;"))

let test_parse_keyboard_height_reads_px () =
  Alcotest.(check (option int))
    "shown height" (Some 320)
    (Platform.parse_keyboard_height "320");
  Alcotest.(check (option int))
    "hidden height" (Some 0)
    (Platform.parse_keyboard_height "0")

let test_parse_keyboard_height_rejects_malformed () =
  Alcotest.(check (option int))
    "non-int -> None" None
    (Platform.parse_keyboard_height "abc");
  Alcotest.(check (option int))
    "empty -> None" None
    (Platform.parse_keyboard_height "")

let () =
  Alcotest.run "nopal_tauri_platform"
    [
      ( "platform",
        [
          Alcotest.test_case "parse_safe_area reads all four insets" `Quick
            test_parse_safe_area_reads_all_four_insets;
          Alcotest.test_case "parse_safe_area rejects malformed" `Quick
            test_parse_safe_area_rejects_malformed;
          Alcotest.test_case "parse_keyboard_height reads px" `Quick
            test_parse_keyboard_height_reads_px;
          Alcotest.test_case "parse_keyboard_height rejects malformed" `Quick
            test_parse_keyboard_height_rejects_malformed;
        ] );
    ]

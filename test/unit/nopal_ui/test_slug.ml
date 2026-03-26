module Slug = Nopal_ui.Slug

let test_simple_lowercase () =
  Alcotest.(check string) "lowercase" "hello" (Slug.slugify "hello")

let test_uppercase_to_lowercase () =
  Alcotest.(check string) "uppercase" "hello" (Slug.slugify "HELLO")

let test_spaces_to_hyphens () =
  Alcotest.(check string) "spaces" "first-name" (Slug.slugify "First Name")

let test_mixed_case_and_spaces () =
  Alcotest.(check string) "mixed" "my-cool-label" (Slug.slugify "My Cool Label")

let test_digits_preserved () =
  Alcotest.(check string) "digits" "field-1" (Slug.slugify "Field 1")

let test_special_chars_to_hyphens () =
  Alcotest.(check string)
    "special" "hello--world-"
    (Slug.slugify "hello!!world?")

let test_consecutive_spaces () =
  Alcotest.(check string) "consecutive spaces" "a--b" (Slug.slugify "a  b")

let test_already_hyphenated () =
  Alcotest.(check string)
    "already hyphenated" "pre-filled"
    (Slug.slugify "pre-filled")

let test_empty_string () = Alcotest.(check string) "empty" "" (Slug.slugify "")

let test_all_uppercase () =
  Alcotest.(check string) "all caps" "email" (Slug.slugify "EMAIL")

let () =
  Alcotest.run "nopal_ui_slug"
    [
      ( "slugify",
        [
          Alcotest.test_case "simple lowercase" `Quick test_simple_lowercase;
          Alcotest.test_case "uppercase to lowercase" `Quick
            test_uppercase_to_lowercase;
          Alcotest.test_case "spaces to hyphens" `Quick test_spaces_to_hyphens;
          Alcotest.test_case "mixed case and spaces" `Quick
            test_mixed_case_and_spaces;
          Alcotest.test_case "digits preserved" `Quick test_digits_preserved;
          Alcotest.test_case "special chars to hyphens" `Quick
            test_special_chars_to_hyphens;
          Alcotest.test_case "consecutive spaces" `Quick test_consecutive_spaces;
          Alcotest.test_case "already hyphenated" `Quick test_already_hyphenated;
          Alcotest.test_case "empty string" `Quick test_empty_string;
          Alcotest.test_case "all uppercase" `Quick test_all_uppercase;
        ] );
    ]

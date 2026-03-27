let test_simple_label () =
  Alcotest.(check string)
    "lowercased with hyphens" "my-label"
    (Nopal_ui.Slug.slugify "My Label")

let test_extra_spaces () =
  Alcotest.(check string)
    "collapses spaces" "hello-world"
    (Nopal_ui.Slug.slugify "  Hello   World  ")

let test_special_chars () =
  Alcotest.(check string)
    "strips special chars" "what-s-up"
    (Nopal_ui.Slug.slugify "What's Up?!")

let test_consecutive_hyphens () =
  Alcotest.(check string)
    "collapses hyphens" "a-b"
    (Nopal_ui.Slug.slugify "a - - b")

let test_empty_string () =
  Alcotest.(check string) "empty stays empty" "" (Nopal_ui.Slug.slugify "")

let test_leading_non_alnum () =
  Alcotest.(check string)
    "strips leading non-alnum" "abc"
    (Nopal_ui.Slug.slugify "---abc")

let test_leading_special_chars () =
  Alcotest.(check string)
    "strips leading special chars" "test"
    (Nopal_ui.Slug.slugify "!@#test")

let test_pure_numeric () =
  Alcotest.(check string)
    "pure numeric preserved" "123"
    (Nopal_ui.Slug.slugify "123")

let test_uppercase_to_lowercase () =
  Alcotest.(check string) "uppercase" "hello" (Nopal_ui.Slug.slugify "HELLO")

let test_digits_preserved () =
  Alcotest.(check string) "digits" "field-1" (Nopal_ui.Slug.slugify "Field 1")

let test_already_hyphenated () =
  Alcotest.(check string)
    "already hyphenated" "pre-filled"
    (Nopal_ui.Slug.slugify "pre-filled")

let test_all_uppercase () =
  Alcotest.(check string) "all caps" "email" (Nopal_ui.Slug.slugify "EMAIL")

let () =
  Alcotest.run "nopal_ui_slug"
    [
      ( "slugify",
        [
          Alcotest.test_case "simple label" `Quick test_simple_label;
          Alcotest.test_case "extra spaces" `Quick test_extra_spaces;
          Alcotest.test_case "special chars" `Quick test_special_chars;
          Alcotest.test_case "consecutive hyphens" `Quick
            test_consecutive_hyphens;
          Alcotest.test_case "empty string" `Quick test_empty_string;
          Alcotest.test_case "leading non-alnum" `Quick test_leading_non_alnum;
          Alcotest.test_case "leading special chars" `Quick
            test_leading_special_chars;
          Alcotest.test_case "pure numeric" `Quick test_pure_numeric;
          Alcotest.test_case "uppercase to lowercase" `Quick
            test_uppercase_to_lowercase;
          Alcotest.test_case "digits preserved" `Quick test_digits_preserved;
          Alcotest.test_case "already hyphenated" `Quick test_already_hyphenated;
          Alcotest.test_case "all uppercase" `Quick test_all_uppercase;
        ] );
    ]

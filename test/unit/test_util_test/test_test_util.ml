let test_contains_present () =
  Alcotest.(check bool)
    "substring present" true
    (Test_util.string_contains "hello world" ~sub:"world")

let test_contains_absent () =
  Alcotest.(check bool)
    "substring absent" false
    (Test_util.string_contains "hello world" ~sub:"xyz")

let test_contains_at_start () =
  Alcotest.(check bool)
    "substring at start" true
    (Test_util.string_contains "hello world" ~sub:"hello")

let test_contains_at_end () =
  Alcotest.(check bool)
    "substring at end" true
    (Test_util.string_contains "hello world" ~sub:"world")

let test_contains_empty_sub () =
  Alcotest.(check bool)
    "empty substring always matches" true
    (Test_util.string_contains "hello" ~sub:"")

let test_contains_empty_string () =
  Alcotest.(check bool)
    "empty string contains nothing" false
    (Test_util.string_contains "" ~sub:"a")

let test_contains_sub_longer_than_string () =
  Alcotest.(check bool)
    "sub longer than string" false
    (Test_util.string_contains "hi" ~sub:"hello")

let test_contains_exact_match () =
  Alcotest.(check bool)
    "exact match" true
    (Test_util.string_contains "abc" ~sub:"abc")

let test_contains_special_characters () =
  Alcotest.(check bool)
    "contains encoded ampersand" true
    (Test_util.string_contains "a%26b=c%3Dd" ~sub:"%26")

let () =
  Alcotest.run "test_util"
    [
      ( "string_contains",
        [
          Alcotest.test_case "present" `Quick test_contains_present;
          Alcotest.test_case "absent" `Quick test_contains_absent;
          Alcotest.test_case "at start" `Quick test_contains_at_start;
          Alcotest.test_case "at end" `Quick test_contains_at_end;
          Alcotest.test_case "empty sub" `Quick test_contains_empty_sub;
          Alcotest.test_case "empty string" `Quick test_contains_empty_string;
          Alcotest.test_case "sub longer than string" `Quick
            test_contains_sub_longer_than_string;
          Alcotest.test_case "exact match" `Quick test_contains_exact_match;
          Alcotest.test_case "special characters" `Quick
            test_contains_special_characters;
        ] );
    ]

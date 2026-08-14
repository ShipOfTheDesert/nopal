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

(* A serialized record as the kitchen sink writes one: `field=value;` fragments
   joined with a space. The two lengths are deliberately equal in every case
   below, because that is the only situation in which the two field names can be
   told apart by anything but the anchor. *)
let record = "processing=ready; byte_size=4096; original_byte_size=4096;"

let test_fragment_after_a_separator () =
  Alcotest.(check bool)
    "a fragment following the space that separates it from the previous one"
    true
    (Test_util.contains_fragment record ~fragment:"byte_size=4096;")

let test_fragment_at_the_start () =
  Alcotest.(check bool)
    "the first fragment in a record is anchored by the start of it" true
    (Test_util.contains_fragment record ~fragment:"processing=ready;")

let test_fragment_absent () =
  Alcotest.(check bool)
    "a fragment the record does not carry" false
    (Test_util.contains_fragment record ~fragment:"width=4096;")

(* The case the helper exists for. [original_byte_size=] ends in [byte_size=],
   so an unanchored search for the shorter field is satisfied by the longer
   field's fragment whenever the two values coincide - and coincide they can,
   since both are byte lengths of the same picture. *)
let test_fragment_does_not_left_alias_a_longer_field () =
  let only_the_longer_field = "processing=ready; original_byte_size=4096;" in
  Alcotest.(check bool)
    "the aliasing substring really is there" true
    (Test_util.string_contains only_the_longer_field ~sub:"byte_size=4096;");
  Alcotest.(check bool)
    "but a fragment naming the shorter field is not satisfied by it" false
    (Test_util.contains_fragment only_the_longer_field
       ~fragment:"byte_size=4096;")

let test_fragment_does_not_right_alias_a_longer_value () =
  Alcotest.(check bool)
    "a shorter value, which the trailing ';' already bounds" false
    (Test_util.contains_fragment record ~fragment:"byte_size=409;")

let () =
  Alcotest.run "test_util"
    [
      ( "contains_fragment",
        [
          Alcotest.test_case "after a separator" `Quick
            test_fragment_after_a_separator;
          Alcotest.test_case "at the start of the record" `Quick
            test_fragment_at_the_start;
          Alcotest.test_case "absent" `Quick test_fragment_absent;
          Alcotest.test_case "does not left-alias a longer field name" `Quick
            test_fragment_does_not_left_alias_a_longer_field;
          Alcotest.test_case "does not right-alias a longer value" `Quick
            test_fragment_does_not_right_alias_a_longer_value;
        ] );
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

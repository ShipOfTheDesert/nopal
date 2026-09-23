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

(* A document shaped like llms.txt: a heading line, prose, a table, then a
   second table that belongs to nothing the heading introduces. *)
let document =
  String.concat "\n"
    [
      "**Some earlier list.**";
      "";
      "| # | Key | Now |";
      "|---|---|---|";
      "| 1 | `earlier-key` | x |";
      "";
      "**The list under test.**";
      "Prose between the heading and its table,";
      "which is skipped.";
      "";
      "| # | Key | When | Now |";
      "|---|---|---|---|";
      "| 1 | `first-key` | a | b |";
      "| 2 | second-key | c | d |";
      "";
      "| # | Key | Now |";
      "|---|---|---|";
      "| 1 | `a-later-table` | x |";
    ]

(* [check_change_list] raises (via [Alcotest.check]) on a mismatch in either
   direction; there is no existing idiom in this suite for catching that, so
   we catch broadly and assert that something was raised. *)
let raises f =
  match f () with
  | () -> false
  | exception _ -> true

let test_check_change_list_agrees () =
  Test_util.check_change_list
    ~candidates:
      [
        ("moved-key", "before", fun () -> "after");
        ("unmoved-key", "same", fun () -> "same");
      ]
    ~published:[ "moved-key" ] ~unchanged:[ "unmoved-key" ]

let test_check_change_list_published_key_did_not_move () =
  Alcotest.(check bool)
    "a key published as moved that in fact did not move fails the check" true
    (raises (fun () ->
         Test_util.check_change_list
           ~candidates:[ ("unmoved-key", "same", fun () -> "same") ]
           ~published:[ "unmoved-key" ] ~unchanged:[]))

let test_check_change_list_moved_key_not_published () =
  Alcotest.(check bool)
    "a key that moved but was not published fails the check" true
    (raises (fun () ->
         Test_util.check_change_list
           ~candidates:[ ("moved-key", "before", fun () -> "after") ]
           ~published:[] ~unchanged:[]))

let key_list = Alcotest.(option (list string))

let test_table_keys_are_the_first_table_after_the_heading () =
  Alcotest.check key_list
    "the key column, in row order, backticks stripped, header and separator \
     dropped, and nothing from the table before the heading or after it"
    (Some [ "first-key"; "second-key" ])
    (Test_util.table_keys_under ~heading:"**The list under test.**" document)

let test_table_keys_under_the_earlier_heading () =
  Alcotest.check key_list "the same reading from a different heading"
    (Some [ "earlier-key" ])
    (Test_util.table_keys_under ~heading:"**Some earlier list.**" document)

let test_table_keys_heading_absent () =
  Alcotest.check key_list "a heading that is not a whole line of the text" None
    (Test_util.table_keys_under ~heading:"**The list under" document)

let () =
  Alcotest.run "test_util"
    [
      ( "table_keys_under",
        [
          Alcotest.test_case "the first table after the heading" `Quick
            test_table_keys_are_the_first_table_after_the_heading;
          Alcotest.test_case "another heading reads its own table" `Quick
            test_table_keys_under_the_earlier_heading;
          Alcotest.test_case "an absent heading" `Quick
            test_table_keys_heading_absent;
        ] );
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
      ( "check_change_list",
        [
          Alcotest.test_case "a moved and an unmoved key agree with the lists"
            `Quick test_check_change_list_agrees;
          Alcotest.test_case "a published key that did not move" `Quick
            test_check_change_list_published_key_did_not_move;
          Alcotest.test_case "a moved key that is not published" `Quick
            test_check_change_list_moved_key_not_published;
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

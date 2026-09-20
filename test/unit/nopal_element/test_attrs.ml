(** Tests for [Nopal_element.Attrs] — the single definition of how a repeated
    attribute key resolves.

    This fold is what both renderers answer an attribute lookup with, so the
    cases here are the only place the resolution rule is stated once. A copy in
    either backend could drift; a shared definition cannot, and these cases are
    what hold it. *)

open Nopal_element

let check_resolved name expected actual =
  Alcotest.(check (option string)) name expected actual

let test_absent_key_resolves_to_none () =
  check_resolved "no pair declares the key" None
    (Attrs.resolve "placeholder" [ ("role", "textbox"); ("id", "search") ])

let test_empty_list_resolves_to_none () =
  check_resolved "nothing is declared" None (Attrs.resolve "placeholder" [])

let test_single_pair_resolves_to_its_value () =
  check_resolved "the only pair answers" (Some "Search")
    (Attrs.resolve "placeholder" [ ("placeholder", "Search") ])

let test_last_pair_of_a_repeated_key_wins () =
  check_resolved "the later pair replaces the earlier one" (Some "second")
    (Attrs.resolve "role"
       [ ("role", "first"); ("id", "x"); ("role", "second") ])

let test_last_pair_wins_across_three_writes () =
  check_resolved "resolution is a fold, not a two-element special case"
    (Some "third")
    (Attrs.resolve "role"
       [ ("role", "first"); ("role", "second"); ("role", "third") ])

let test_an_empty_value_is_a_value_not_an_absence () =
  check_resolved "a declared empty string answers Some" (Some "")
    (Attrs.resolve "data-marker" [ ("data-marker", "") ])

let test_an_empty_later_value_still_replaces () =
  check_resolved "last-wins does not skip an empty replacement" (Some "")
    (Attrs.resolve "data-marker"
       [ ("data-marker", "set"); ("data-marker", "") ])

let test_a_neighbouring_key_does_not_shadow () =
  check_resolved "only the named key is read" (Some "own")
    (Attrs.resolve "aria-label"
       [ ("aria-labelledby", "other"); ("aria-label", "own") ])

let test_lookup_is_exact_not_a_prefix () =
  check_resolved "a key that extends the name does not match" None
    (Attrs.resolve "aria-label" [ ("aria-labelledby", "other") ])

let () =
  Alcotest.run "Nopal_element.Attrs"
    [
      ( "resolve",
        [
          Alcotest.test_case "absent key resolves to None" `Quick
            test_absent_key_resolves_to_none;
          Alcotest.test_case "empty list resolves to None" `Quick
            test_empty_list_resolves_to_none;
          Alcotest.test_case "single pair resolves to its value" `Quick
            test_single_pair_resolves_to_its_value;
          Alcotest.test_case "last pair of a repeated key wins" `Quick
            test_last_pair_of_a_repeated_key_wins;
          Alcotest.test_case "last pair wins across three writes" `Quick
            test_last_pair_wins_across_three_writes;
          Alcotest.test_case "an empty value is a value, not an absence" `Quick
            test_an_empty_value_is_a_value_not_an_absence;
          Alcotest.test_case "an empty later value still replaces" `Quick
            test_an_empty_later_value_still_replaces;
          Alcotest.test_case "a neighbouring key does not shadow" `Quick
            test_a_neighbouring_key_does_not_shadow;
          Alcotest.test_case "lookup is exact, not a prefix" `Quick
            test_lookup_is_exact_not_a_prefix;
        ] );
    ]

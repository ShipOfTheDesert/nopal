(** Tests for [Nopal_element.Url_text] — the pre-pass shared by [Url] and
    [Route_path]. *)

open Nopal_element

let test_flags_control_and_edge_spaces () =
  List.iter
    (fun input ->
      Alcotest.(check bool)
        (Printf.sprintf "%S is flagged" input)
        true
        (Url_text.has_control_or_surrounding_space input))
    [ "a\tb"; "\nx"; "x\x7f"; "a\x00"; " a"; "a " ]

let test_passes_clean_text () =
  List.iter
    (fun input ->
      Alcotest.(check bool)
        (Printf.sprintf "%S is not flagged" input)
        false
        (Url_text.has_control_or_surrounding_space input))
    [ ""; "a b"; "https://a"; "/x?y=1" ]

let () =
  Alcotest.run "Url_text"
    [
      ( "url_text",
        [
          Alcotest.test_case "flags_control_and_edge_spaces" `Quick
            test_flags_control_and_edge_spaces;
          Alcotest.test_case "passes_clean_text" `Quick test_passes_clean_text;
        ] );
    ]

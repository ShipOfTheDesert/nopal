(** Tests for [Nopal_element.Url] — the checked external URL a link carries.

    Every case asserts the whole outcome: an accepted URL round-trips through
    [to_string] unchanged, and a rejected one names the constructor and the
    exact input (and scheme) it rejected. *)

open Nopal_element

let pp_error ppf (error : Url.error) =
  match error with
  | Url.Missing_scheme { input } ->
      Format.fprintf ppf "Missing_scheme { input = %S }" input
  | Url.Unsupported_scheme { input; scheme } ->
      Format.fprintf ppf "Unsupported_scheme { input = %S; scheme = %S }" input
        scheme
  | Url.Control_character { input } ->
      Format.fprintf ppf "Control_character { input = %S }" input

let equal_error (a : Url.error) (b : Url.error) =
  match (a, b) with
  | Url.Missing_scheme { input = i1 }, Url.Missing_scheme { input = i2 } ->
      String.equal i1 i2
  | ( Url.Unsupported_scheme { input = i1; scheme = s1 },
      Url.Unsupported_scheme { input = i2; scheme = s2 } ) ->
      String.equal i1 i2 && String.equal s1 s2
  | Url.Control_character { input = i1 }, Url.Control_character { input = i2 }
    ->
      String.equal i1 i2
  | ( (Url.Missing_scheme _ | Url.Unsupported_scheme _ | Url.Control_character _),
      _ ) ->
      false

let outcome = Alcotest.(result string (Alcotest.testable pp_error equal_error))
let parse input = Result.map Url.to_string (Url.of_string input)

let test_accepts_four_schemes_any_case () =
  List.iter
    (fun input ->
      Alcotest.check outcome
        (Printf.sprintf "%S is accepted unchanged" input)
        (Ok input) (parse input))
    [
      "http://example.com/a?b=1#c";
      "https://example.com/";
      "mailto:someone@example.com";
      "tel:+15550100";
      "HTTPS://example.com/";
      "Mailto:someone@example.com";
    ]

let test_rejects_javascript_and_data () =
  List.iter
    (fun (input, scheme) ->
      Alcotest.check outcome
        (Printf.sprintf "%S is an unsupported scheme" input)
        (Error (Url.Unsupported_scheme { input; scheme }))
        (parse input))
    [
      ("javascript:alert(1)", "javascript");
      ("JavaScript:alert(1)", "JavaScript");
      ("data:text/html,<script>alert(1)</script>", "data");
      ("file:///etc/passwd", "file");
    ]

let test_rejects_missing_scheme () =
  List.iter
    (fun input ->
      Alcotest.check outcome
        (Printf.sprintf "%S has no scheme" input)
        (Error (Url.Missing_scheme { input }))
        (parse input))
    [ "example.com"; "/path"; ""; ":no-scheme"; "/a:b" ]

let test_rejects_control_and_whitespace () =
  List.iter
    (fun input ->
      Alcotest.check outcome
        (Printf.sprintf "%S carries a control character or surrounding space"
           input)
        (Error (Url.Control_character { input }))
        (parse input))
    [
      "java\tscript:alert(1)";
      "\nhttps://a";
      " https://a";
      "https://a ";
      "https://a\x7f";
      "https://a\x00b";
    ]

let test_scheme_characters_and_bare_http () =
  Alcotest.check outcome "svn+ssh is a scheme, and unsupported"
    (Error
       (Url.Unsupported_scheme
          { input = "svn+ssh://host/x"; scheme = "svn+ssh" }))
    (parse "svn+ssh://host/x");
  Alcotest.check outcome
    "https:foo is accepted: nothing after the scheme is read" (Ok "https:foo")
    (parse "https:foo")

let () =
  Alcotest.run "Url"
    [
      ( "url",
        [
          Alcotest.test_case "accepts_four_schemes_any_case" `Quick
            test_accepts_four_schemes_any_case;
          Alcotest.test_case "rejects_javascript_and_data" `Quick
            test_rejects_javascript_and_data;
          Alcotest.test_case "rejects_missing_scheme" `Quick
            test_rejects_missing_scheme;
          Alcotest.test_case "rejects_control_and_whitespace" `Quick
            test_rejects_control_and_whitespace;
          Alcotest.test_case "scheme_characters_and_bare_http" `Quick
            test_scheme_characters_and_bare_http;
        ] );
    ]

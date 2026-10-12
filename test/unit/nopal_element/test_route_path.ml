(** Tests for [Nopal_element.Route_path] — the checked in-app path a link
    carries.

    Every case asserts the whole outcome: an accepted path round-trips through
    [to_string] unchanged, and a rejected one names the constructor and the
    exact input it rejected. *)

open Nopal_element

let pp_error ppf (error : Route_path.error) =
  match error with
  | Route_path.Not_absolute { input } ->
      Format.fprintf ppf "Not_absolute { input = %S }" input
  | Route_path.Protocol_relative { input } ->
      Format.fprintf ppf "Protocol_relative { input = %S }" input
  | Route_path.Control_character { input } ->
      Format.fprintf ppf "Control_character { input = %S }" input

let equal_error (a : Route_path.error) (b : Route_path.error) =
  match (a, b) with
  | ( Route_path.Not_absolute { input = i1 },
      Route_path.Not_absolute { input = i2 } ) ->
      String.equal i1 i2
  | ( Route_path.Protocol_relative { input = i1 },
      Route_path.Protocol_relative { input = i2 } ) ->
      String.equal i1 i2
  | ( Route_path.Control_character { input = i1 },
      Route_path.Control_character { input = i2 } ) ->
      String.equal i1 i2
  | ( ( Route_path.Not_absolute _ | Route_path.Protocol_relative _
      | Route_path.Control_character _ ),
      _ ) ->
      false

let outcome = Alcotest.(result string (Alcotest.testable pp_error equal_error))
let parse input = Result.map Route_path.to_string (Route_path.of_string input)

let test_accepts_rooted_path () =
  List.iter
    (fun input ->
      Alcotest.check outcome
        (Printf.sprintf "%S is accepted unchanged" input)
        (Ok input) (parse input))
    [ "/"; "/a/b?q=1#h"; "/a//b"; "/a\\b" ]

let test_rejects_protocol_relative_slash_and_backslash () =
  List.iter
    (fun input ->
      Alcotest.check outcome
        (Printf.sprintf "%S is protocol-relative" input)
        (Error (Route_path.Protocol_relative { input }))
        (parse input))
    [ "//evil.example"; "/\\evil.example"; "//"; "/\\" ]

let test_rejects_javascript_as_path () =
  List.iter
    (fun input ->
      Alcotest.check outcome
        (Printf.sprintf "%S does not start with /" input)
        (Error (Route_path.Not_absolute { input }))
        (parse input))
    [ "javascript:alert(1)"; "a/b"; ""; "\\\\evil.example"; "\\/evil.example" ]

let test_rejects_control_and_whitespace () =
  List.iter
    (fun input ->
      Alcotest.check outcome
        (Printf.sprintf "%S carries a control character or surrounding space"
           input)
        (Error (Route_path.Control_character { input }))
        (parse input))
    [ "/a\tb"; "\n/a"; " /a"; "/a "; "/\t/evil.example"; "/a\x7f" ]

let () =
  Alcotest.run "Route_path"
    [
      ( "route_path",
        [
          Alcotest.test_case "accepts_rooted_path" `Quick
            test_accepts_rooted_path;
          Alcotest.test_case "rejects_protocol_relative_slash_and_backslash"
            `Quick test_rejects_protocol_relative_slash_and_backslash;
          Alcotest.test_case "rejects_javascript_as_path" `Quick
            test_rejects_javascript_as_path;
          Alcotest.test_case "rejects_control_and_whitespace" `Quick
            test_rejects_control_and_whitespace;
        ] );
    ]

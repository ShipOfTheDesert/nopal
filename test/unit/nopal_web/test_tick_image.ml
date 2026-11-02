open Nopal_style.Style

let prefix = "url(\"data:image/svg+xml,"
let suffix = "\")"

(* The data portion of the CSS value, failing the test when the value is not
   wrapped as [url("data:image/svg+xml,…")]. *)
let payload_of value =
  let value_length = String.length value in
  let prefix_length = String.length prefix in
  let suffix_length = String.length suffix in
  match
    value_length >= prefix_length + suffix_length
    && String.starts_with ~prefix value
    && String.ends_with ~suffix value
  with
  | true ->
      String.sub value prefix_length
        (value_length - prefix_length - suffix_length)
  | false ->
      Alcotest.failf "not a url(\"data:image/svg+xml,…\") value: %s" value

let hex_digit_value c =
  match c with
  | '0' .. '9' -> Some (Char.code c - Char.code '0')
  | 'A' .. 'F' -> Some (Char.code c - Char.code 'A' + 10)
  | 'a' .. 'f' -> Some (Char.code c - Char.code 'a' + 10)
  | _ -> None

(* Replaces every [%XX] triplet with the byte it names. A [%] not followed by
   two hex digits fails the test, so a malformed escape cannot decode quietly. *)
let percent_decode s =
  let length = String.length s in
  let buf = Buffer.create length in
  let rec go i =
    match i < length with
    | false -> Buffer.contents buf
    | true -> (
        match s.[i] with
        | '%' -> (
            match i + 2 < length with
            | false -> Alcotest.failf "truncated escape at %d in %s" i s
            | true -> (
                match
                  (hex_digit_value s.[i + 1], hex_digit_value s.[i + 2])
                with
                | Some high, Some low ->
                    Buffer.add_char buf (Char.chr ((high * 16) + low));
                    go (i + 3)
                | None, _
                | _, None ->
                    Alcotest.failf "malformed escape at %d in %s" i s))
        | c ->
            Buffer.add_char buf c;
            go (i + 1))
  in
  go 0

let is_unreserved c =
  match c with
  | 'A' .. 'Z'
  | 'a' .. 'z'
  | '0' .. '9'
  | '-'
  | '.'
  | '_'
  | '~' ->
      true
  | _ -> false

(* Every byte of [payload] is an RFC 3986 unreserved character or part of a
   [%XX] triplet, which is what makes it safe inside [url("…")]: no quote,
   parenthesis, backslash or [#] can survive to close the value early or cut
   the data URI at a fragment. *)
let check_only_unreserved_or_escaped payload =
  let length = String.length payload in
  let rec go i =
    match i < length with
    | false -> ()
    | true -> (
        match payload.[i] with
        | '%' -> go (i + 3)
        | c -> (
            match is_unreserved c with
            | true -> go (i + 1)
            | false -> Alcotest.failf "raw %C at %d in payload %s" c i payload))
  in
  go 0

let check_absent label ~sub s =
  Alcotest.(check bool)
    (Printf.sprintf "%s: no raw %S" label sub)
    false
    (Test_util.string_contains s ~sub)

let check_present label ~sub s =
  Alcotest.(check bool)
    (Printf.sprintf "%s: contains %S" label sub)
    true
    (Test_util.string_contains s ~sub)

(* The expected colour spellings below are the CSS forms the backend writes for
   each [Color.t] arm everywhere else: a hex string verbatim, [rgba(r,g,b,a)]
   with [%g] alpha, a name verbatim, and the [transparent] keyword. *)

let test_hex_mark_has_no_raw_hash () =
  let value = Nopal_web.Tick_image.css_url (Hex "#FFFDF9") in
  check_absent "value" ~sub:"#" value;
  check_present "value" ~sub:"%23FFFDF9" value

let test_rgba_mark_is_encoded () =
  let value =
    Nopal_web.Tick_image.css_url (Rgba { r = 255; g = 253; b = 249; a = 0.5 })
  in
  let payload = payload_of value in
  List.iter
    (fun sub -> check_absent "payload" ~sub payload)
    [ "("; ")"; "\""; "#" ];
  check_present "decoded" ~sub:"rgba(255,253,249,0.5)" (percent_decode payload)

let test_uri_is_a_css_url_value () =
  let payload = payload_of (Nopal_web.Tick_image.css_url (Hex "#0F6E56")) in
  check_only_unreserved_or_escaped payload;
  let decoded = percent_decode payload in
  Alcotest.(check bool)
    "decoded payload is one SVG document" true
    (String.starts_with ~prefix:"<svg" decoded
    && String.ends_with ~suffix:"</svg>" decoded);
  check_present "decoded" ~sub:"xmlns=" decoded;
  check_present "decoded" ~sub:"#0F6E56" decoded

let test_named_and_transparent_marks_encode () =
  List.iter
    (fun (label, mark, spelling) ->
      let payload = payload_of (Nopal_web.Tick_image.css_url mark) in
      check_only_unreserved_or_escaped payload;
      check_present label ~sub:spelling (percent_decode payload))
    [
      ("hex", Hex "#FFFDF9", "#FFFDF9");
      ("rgba", Rgba { r = 1; g = 2; b = 3; a = 1.0 }, "rgba(1,2,3,1)");
      ("named", Named "rebeccapurple", "rebeccapurple");
      ("named with url delimiters", Named "red\")", "red&quot;)");
      ("transparent", Transparent, "transparent");
    ]

let test_named_mark_is_xml_escaped () =
  let payload =
    payload_of (Nopal_web.Tick_image.css_url (Named "a'b<c>d&e\"f"))
  in
  check_present "decoded" ~sub:"stroke='a&apos;b&lt;c&gt;d&amp;e&quot;f'"
    (percent_decode payload)

let () =
  Alcotest.run "Tick_image"
    [
      ( "css_url",
        [
          Alcotest.test_case "hex_mark_has_no_raw_hash" `Quick
            test_hex_mark_has_no_raw_hash;
          Alcotest.test_case "rgba_mark_is_encoded" `Quick
            test_rgba_mark_is_encoded;
          Alcotest.test_case "uri_is_a_css_url_value" `Quick
            test_uri_is_a_css_url_value;
          Alcotest.test_case "named_and_transparent_marks_encode" `Quick
            test_named_and_transparent_marks_encode;
          Alcotest.test_case "named_mark_is_xml_escaped" `Quick
            test_named_mark_is_xml_escaped;
        ] );
    ]

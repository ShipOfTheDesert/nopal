(** Tests for the key↔filename codec used by the Tauri filesystem storage
    backend. These functions are security-critical — they prevent a key from
    escaping the scoped storage directory ([..]/[/]) or colliding on a
    case-insensitive filesystem — so they get a dedicated native test
    independent of any Tauri runtime. *)

let roundtrips key =
  Alcotest.(check (option string))
    (Printf.sprintf "roundtrip %S" key)
    (Some key)
    (Nopal_fs_key.decode_filename (Nopal_fs_key.encode_key key))

let test_roundtrip_preserves_keys () =
  List.iter roundtrips
    [
      "";
      "abc";
      "user:1";
      "a/b";
      "..";
      ".";
      "Foo";
      "foo";
      "with space";
      "a%b";
      "../../etc/passwd";
      "C:\\Windows\\system32";
      "café";
      (* raw UTF-8 bytes *)
    ]

(* The encoded filename must contain no path-significant character. (Uppercase
   ASCII may appear in the output as hex digits of a [%XX] escape — that is
   intentional; case-collision safety is covered separately by injectivity in
   {!test_case_distinct_keys_stay_distinct}.) *)
let no_path_chars label key =
  let encoded = Nopal_fs_key.encode_key key in
  String.iter
    (fun c ->
      match c with
      | '/'
      | '\\'
      | '.' ->
          Alcotest.failf "%s: encoded %S contains path char %C" label encoded c
      | _ -> ())
    encoded

let test_encoding_strips_path () =
  no_path_chars "traversal" "../../etc/passwd";
  no_path_chars "dot" "..";
  no_path_chars "backslash" "C:\\Windows"

let test_parent_dir_is_neutralised () =
  (* [..] must not encode to anything the filesystem reads as the parent dir. *)
  Alcotest.(check string)
    ".. encodes to a flat filename" "%2E%2E"
    (Nopal_fs_key.encode_key "..")

let test_case_distinct_keys_stay_distinct () =
  Alcotest.(check bool)
    "Foo and foo map to different filenames" true
    (Nopal_fs_key.encode_key "Foo" <> Nopal_fs_key.encode_key "foo")

let test_decode_rejects_malformed () =
  List.iter
    (fun name ->
      Alcotest.(check (option string))
        (Printf.sprintf "malformed %S decodes to None" name)
        None
        (Nopal_fs_key.decode_filename name))
    [ "%"; "%2"; "abc%"; "%G1"; "%2G"; "%zz" ]

let test_decode_accepts_lowercase_hex () =
  (* [encode_key] emits uppercase hex, but [decode_filename] tolerates both so a
     hand-written filename still round-trips. *)
  Alcotest.(check (option string))
    "%2e decodes to ." (Some ".")
    (Nopal_fs_key.decode_filename "%2e")

let () =
  Alcotest.run "nopal_fs_key"
    [
      ( "encode/decode",
        [
          Alcotest.test_case "roundtrip preserves keys" `Quick
            test_roundtrip_preserves_keys;
          Alcotest.test_case "encoding strips path" `Quick
            test_encoding_strips_path;
          Alcotest.test_case "parent dir is neutralised" `Quick
            test_parent_dir_is_neutralised;
          Alcotest.test_case "case-distinct keys stay distinct" `Quick
            test_case_distinct_keys_stay_distinct;
          Alcotest.test_case "decode rejects malformed" `Quick
            test_decode_rejects_malformed;
          Alcotest.test_case "decode accepts lowercase hex" `Quick
            test_decode_accepts_lowercase_hex;
        ] );
    ]

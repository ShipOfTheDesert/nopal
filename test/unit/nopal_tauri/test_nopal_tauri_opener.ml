(* [Nopal_tauri.Opener.open_url] against [tauri_shim.js].

   The shim records each opener invoke and PARKS its settlement until the case
   calls [__nopal_opener_flush], as a real promise settles on a later turn: each
   case asserts nothing has resolved when [open_url] returns, flushes, and reads
   back every outcome in order.

   The rejection strings are the host's own. tauri words an access-control
   refusal two ways (debug and release builds) and rejects a plugin that was
   never registered with one fixed sentence; the opener plugin's scope refusal
   names the URL it refused. *)

module Opener = Nopal_tauri.Opener

let url_text = "https://nopal-test-7Q2.example/"
let marker = "nopal-test-7Q2"

let url =
  match Nopal_element.Url.of_string url_text with
  | Ok url -> url
  | Error
      ( Nopal_element.Url.Missing_scheme _
      | Nopal_element.Url.Unsupported_scheme _
      | Nopal_element.Url.Control_character _ ) ->
      Alcotest.fail "fixture: the test URL is not accepted by Url.of_string"

let reset () = ignore (Jv.call Jv.global "__nopal_reset_subs" [||])
let flush () = ignore (Jv.call Jv.global "__nopal_opener_flush" [||])

let set_rejection reason =
  ignore
    (Jv.call Jv.global "__nopal_set_opener_rejection" [| Jv.of_string reason |])

let set_throw message =
  ignore
    (Jv.call Jv.global "__nopal_set_opener_throw" [| Jv.of_string message |])

let show_outcome : (unit, Nopal_element.Link.open_error) result -> string =
  function
  | Ok () -> "Ok ()"
  | Error Not_permitted -> "Error Not_permitted"
  | Error (Failed reason) -> Printf.sprintf "Error (Failed %S)" reason

let outcome =
  Alcotest.testable
    (fun fmt o -> Format.pp_print_string fmt (show_outcome o))
    ( = )

let outcomes_of_open () =
  (* mutable: collects the outcomes the opener reports through its callback. *)
  let seen = ref [] in
  Opener.open_url url (fun o -> seen := o :: !seen);
  Alcotest.(check int)
    "nothing resolved before the turn ends" 0 (List.length !seen);
  flush ();
  let after_flush = List.rev !seen in
  flush ();
  Alcotest.(check int)
    "a second drain delivers nothing more" (List.length after_flush)
    (List.length !seen);
  after_flush

let invokes () = Jv.to_list Fun.id (Jv.get Jv.global "__nopal_opener_invokes")

let arg_keys args =
  Jv.to_list Jv.to_string
    (Jv.call (Jv.get Jv.global "Object") "keys" [| args |])

let opener_invokes_open_url_with_url () =
  reset ();
  Alcotest.(check (list outcome))
    "the open resolves once, Ok" [ Ok () ] (outcomes_of_open ());
  match invokes () with
  | [ invoke ] ->
      Alcotest.(check string)
        "command" "plugin:opener|open_url"
        (Jv.to_string (Jv.get invoke "cmd"));
      let args = Jv.get invoke "args" in
      Alcotest.(check (list string)) "argument keys" [ "url" ] (arg_keys args);
      Alcotest.(check string)
        "url argument" url_text
        (Jv.to_string (Jv.get args "url"))
  | other ->
      Alcotest.failf "expected exactly one opener invoke, got %d"
        (List.length other)

let outcomes_of_rejection reason =
  reset ();
  set_rejection reason;
  outcomes_of_open ()

let check_rejection ~expect reason =
  Alcotest.(check (list outcome))
    reason [ expect ]
    (outcomes_of_rejection reason)

let opener_decode_maps_acl_and_scope_to_not_permitted () =
  let not_permitted = Error Nopal_element.Link.Not_permitted in
  List.iter
    (check_rejection ~expect:not_permitted)
    [
      "opener.open_url not allowed. Permissions associated with this command: \
       opener:allow-open-url, opener:default";
      "opener.open_url not allowed on window \"other\", webview \"other\", \
       URL: local\n\n\
       allowed on: [windows: \"main\", URL: local]\n\n\
       referenced by: capability: default, permission: opener:allow-open-url";
      "opener.open_url not allowed. Plugin not found";
      "opener.open_url explicitly denied on origin local\n\n\
       referenced by: capability: default, permission: opener:deny-open-url";
      "Command plugin:opener|open_url not allowed by ACL";
      "plugin opener not found";
      "Not allowed to open url " ^ url_text;
    ];
  let unrelated = "no application is registered for this kind of link" in
  check_rejection ~expect:(Error (Failed unrelated)) unrelated;
  reset ();
  Alcotest.(check (list outcome))
    "a resolved invoke is Ok" [ Ok () ] (outcomes_of_open ())

let opener_failed_redacts_url () =
  let rejection =
    Printf.sprintf "Launcher \"xdg-open\" \"%s\" failed with exit status 3 (%s)"
      url_text url_text
  in
  match outcomes_of_rejection rejection with
  | [ Error (Failed reason) ] ->
      Alcotest.(check bool)
        "the reason does not contain the URL" false
        (Test_util.string_contains reason ~sub:marker);
      Alcotest.(check string)
        "the rest of the host's message is kept"
        "Launcher \"xdg-open\" \"<url>\" failed with exit status 3 (<url>)"
        reason
  | other ->
      Alcotest.failf "expected one Error (Failed _), got [%s]"
        (String.concat "; " (List.map show_outcome other))

let opener_invoke_throws_resolves_failed_once () =
  reset ();
  let message = "invoke is broken" in
  set_throw message;
  (* A throw happens before [invoke] returns, so the outcome is in hand at
     once, and a later drain must add nothing. *)
  (* mutable: collects the outcomes the opener reports through its callback. *)
  let seen = ref [] in
  Opener.open_url url (fun o -> seen := o :: !seen);
  flush ();
  Alcotest.(check (list outcome))
    "one Failed outcome carrying the thrown message" [ Error (Failed message) ]
    (List.rev !seen)

let opener_invoke_throws_empty_message_resolves_no_reason () =
  reset ();
  set_throw "";
  (* mutable: collects the outcomes the opener reports through its callback. *)
  let seen = ref [] in
  Opener.open_url url (fun o -> seen := o :: !seen);
  flush ();
  Alcotest.(check (list outcome))
    "an empty thrown message becomes the fixed no-reason text"
    [ Error (Failed "opening the link failed and the platform gave no reason") ]
    (List.rev !seen)

let arb_url =
  let open QCheck in
  let host = Gen.(string_size ~gen:(char_range 'a' 'z') (int_range 4 12)) in
  let gen =
    Gen.(
      map2
        (fun scheme h -> scheme ^ h ^ ".example")
        (oneof_list [ "http://"; "https://"; "mailto:u@"; "tel:+1" ])
        host)
  in
  make ~print:Fun.id gen

let prop_failed_never_carries_url =
  QCheck.Test.make ~count:200
    ~name:"a rejection message embedding the URL never leaks it into Failed"
    QCheck.(triple arb_url string_printable string_printable)
    (fun (text, before, after) ->
      match Nopal_element.Url.of_string text with
      | Error _ -> QCheck.assume_fail ()
      | Ok u -> (
          reset ();
          set_rejection (before ^ text ^ after);
          let seen = ref [] in
          Opener.open_url u (fun o -> seen := o :: !seen);
          flush ();
          match List.rev !seen with
          | [ Error (Failed reason) ] ->
              not (Test_util.string_contains reason ~sub:text)
          | [ Error Not_permitted ] -> true
          | _ -> false))

let () =
  Alcotest.run "nopal_tauri_opener"
    [
      ( "open_url",
        [
          Alcotest.test_case "opener_invokes_open_url_with_url" `Quick
            opener_invokes_open_url_with_url;
          Alcotest.test_case "opener_decode_maps_acl_and_scope_to_not_permitted"
            `Quick opener_decode_maps_acl_and_scope_to_not_permitted;
          Alcotest.test_case "opener_failed_redacts_url" `Quick
            opener_failed_redacts_url;
          Alcotest.test_case "opener_invoke_throws_resolves_failed_once" `Quick
            opener_invoke_throws_resolves_failed_once;
          Alcotest.test_case
            "opener_invoke_throws_empty_message_resolves_no_reason" `Quick
            opener_invoke_throws_empty_message_resolves_no_reason;
        ] );
      ( "properties",
        [ QCheck_alcotest.to_alcotest prop_failed_never_carries_url ] );
    ]

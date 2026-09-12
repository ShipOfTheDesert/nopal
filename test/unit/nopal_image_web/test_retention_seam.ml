(* The browser release backend, reached through the seam application code
   actually calls.

   The pure seam has a suite of its own that drives [Retention.release] against a
   stub, and the blob store has one that drives [remove] directly. Neither
   exercises the join this package exists to provide - the browser
   implementation reached through [register_backend] and dispatched as a
   command - and a drift on either side of that join would compile, pass both
   suites, and surface first in an application, as a photograph that is never
   freed. The registration in the doc comment on [Nopal_image_web.release] is
   the expression under test here, so it is compiled truth rather than prose.

   This is also where releasing an entry is told apart from revoking a URL
   minted from it. Nothing in OCaml observes a live browser URL, so at this
   layer the distinction is pinned through the browser calls the release makes
   and does not make - a pin on the calls, never on the bytes. The complementary
   half is pinned in a real browser: the case in
   test/e2e/tests/kitchen-sink-receipt-flow.spec.ts that releases an entry and
   then asserts the picture minted from it still decodes, through that spec's
   [img.naturalWidth > 0] probe - the one observation in this repo that tells
   bytes still resident from bytes freed. Neither layer subsumes the other: this
   one cannot see the bytes, and that one cannot see which browser call was
   skipped. *)

open Nopal_image

(* The registration a mounting layer performs, undone afterwards however the
   case ends: the backend is module-level state, and a case that left the
   browser backend installed would change what every later case in this
   executable is testing. *)
let with_browser_backend f =
  Retention.register_backend { Retention.release = Nopal_image_web.release };
  Fun.protect
    ~finally:(fun () -> Retention.register_backend Retention.default_backend)
    f

(* Runs [f] against a substituted global URL object and puts the real one back
   afterwards, so a case that records the browser's minting and revocation
   cannot leave the rest of the executable without them. *)
let with_global_url replacement f =
  let saved = Jv.get Jv.global "URL" in
  Jv.set Jv.global "URL" replacement;
  Fun.protect ~finally:(fun () -> Jv.set Jv.global "URL" saved) f

let check_resolves ~context ~expected handle =
  Alcotest.(check bool)
    (Printf.sprintf "%s: the store resolves the handle %s" context handle)
    expected
    (Option.is_some (Nopal_blob_web.Blob_store.lookup handle))

(* The whole join in the direction that frees something: a handle the store
   issued resolves, and stops resolving once the browser backend has been asked
   to release it. The second handle is what tells "the named entry was freed"
   apart from "the store lost everything". *)
let test_released_handle_no_longer_resolves () =
  let handle = Image_web_test_helpers.stored_source () in
  let bystander = Image_web_test_helpers.stored_source () in
  check_resolves ~context:"a handle the store issued" ~expected:true handle;
  Nopal_image_web.release ~blob_id:handle;
  check_resolves ~context:"the released handle" ~expected:false handle;
  check_resolves ~context:"a handle nothing released" ~expected:true bystander;
  (* The entry is gone, not merely emptied: nothing can be minted from it
     again. *)
  Alcotest.(check bool)
    "the released entry mints no further URL" true
    (Option.is_none (Nopal_blob_web.Blob_store.object_url handle))

(* The distinction the seam exists to keep. Releasing an entry does not revoke
   a URL that was minted from it: the bytes stay pinned by the URL, and only
   revoking the URL releases them. A release implemented as "revoke, then
   remove" would free the displayed image out from under a view that is still
   showing it, and no OCaml-visible state would record that it had happened -
   so the browser call itself is what is asserted, both that it is absent here
   and that the recorder would have seen it. *)
let test_release_does_not_revoke_a_url_minted_from_the_entry () =
  let handle = Image_web_test_helpers.stored_source () in
  let minted = "blob:substituted/6c02-41d7" in
  let revoked = ref [] in
  let recording_url =
    Jv.obj
      [|
        ( "createObjectURL",
          Jv.callback ~arity:1 (fun _blob -> Jv.of_string minted) );
        ( "revokeObjectURL",
          Jv.callback ~arity:1 (fun url ->
              revoked := Jv.to_string url :: !revoked;
              Jv.undefined) );
      |]
  in
  with_global_url recording_url (fun () ->
      (match Nopal_blob_web.Blob_store.object_url handle with
      | None -> Alcotest.fail "the substituted platform minted no URL to test"
      | Some url ->
          Alcotest.(check string)
            "the substituted platform's URL reaches the caller unchanged" minted
            url);
      Nopal_image_web.release ~blob_id:handle;
      Alcotest.(check (list string))
        "releasing the entry revokes no URL" [] !revoked;
      (* The affirmative arm on the same recorder: the empty list above is a
         call that was not made, not a recorder that records nothing. *)
      Nopal_image_web.revoke_preview_url ~url:minted;
      Alcotest.(check (list string))
        "revoking the URL is what reaches the browser" [ minted ] !revoked)

(* Releasing is total, so a caller may release whatever it happens to hold
   without keeping a record of what it has already released. Both ways of
   holding nothing are driven: a handle whose entry is already gone, and the
   same handle released a second time. A raise from either would leave the
   caller with no outcome to respond to while abandoning whatever else it was
   doing, so a raise here fails the case by escaping it. *)
let test_releasing_an_unknown_handle_is_a_noop () =
  let live = Image_web_test_helpers.stored_source () in
  let already_released = Image_web_test_helpers.released_handle () in
  let twice = Image_web_test_helpers.stored_source () in
  Nopal_image_web.release ~blob_id:already_released;
  check_resolves ~context:"a handle whose entry was already gone"
    ~expected:false already_released;
  Nopal_image_web.release ~blob_id:twice;
  check_resolves ~context:"the handle released once" ~expected:false twice;
  Nopal_image_web.release ~blob_id:twice;
  check_resolves ~context:"the handle released twice" ~expected:false twice;
  (* The affirmative arm: the releases above disturbed nothing because they
     named nothing live, not because the store had stopped holding anything. *)
  check_resolves ~context:"a live handle none of them named" ~expected:true live

(* The seam end to end: a command built from the pure package, interpreted
   against the registered browser backend, frees the entry it names. The
   unregistered arm on the same fixture is what shows the freeing came from the
   registration - an unregistered seam retains silently, which is the failure
   this backend exists to remove. *)
let test_registered_backend_routes_release_to_the_browser () =
  let unregistered = Image_web_test_helpers.stored_source () in
  let registered = Image_web_test_helpers.stored_source () in
  let bystander = Image_web_test_helpers.stored_source () in
  let dispatches = ref 0 in
  let count_dispatch (_ : unit) = incr dispatches in
  let run ~blob_id =
    Nopal_mvu.Cmd.execute count_dispatch (Retention.release ~blob_id)
  in
  Retention.register_backend Retention.default_backend;
  run ~blob_id:unregistered;
  check_resolves ~context:"a handle released with no backend registered"
    ~expected:true unregistered;
  with_browser_backend (fun () -> run ~blob_id:registered);
  check_resolves ~context:"a handle released through the registered backend"
    ~expected:false registered;
  check_resolves ~context:"a handle no command named" ~expected:true bystander;
  Alcotest.(check int)
    "releasing a stored image dispatches no message into the application" 0
    !dispatches;
  (* The affirmative arm, on the same collector the releases above were run
     through: nothing else in this executable dispatches anything, so without it
     the zero is equally satisfied by a counter that could never leave zero. *)
  Nopal_mvu.Cmd.execute count_dispatch
    (Nopal_mvu.Cmd.perform (fun dispatch -> dispatch ()));
  Alcotest.(check int)
    "the collector counts a dispatch when a command makes one" 1 !dispatches

let tests =
  [
    Alcotest.test_case "a released handle no longer resolves" `Quick
      test_released_handle_no_longer_resolves;
    Alcotest.test_case "releasing an entry does not revoke a URL from it" `Quick
      test_release_does_not_revoke_a_url_minted_from_the_entry;
    Alcotest.test_case "releasing an unknown or released handle is a no-op"
      `Quick test_releasing_an_unknown_handle_is_a_noop;
    Alcotest.test_case "a registered backend releases through the browser"
      `Quick test_registered_backend_routes_release_to_the_browser;
  ]

let () = Alcotest.run "Retention seam" [ ("Retention seam", tests) ]

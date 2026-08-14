(* The browser preview backend reached through the seam application code
   actually calls.

   The pure seam has a suite of its own that drives [Preview.preview_url]
   against a stub, and the blob store has one that drives [object_url]
   directly. Neither exercises the join this package exists to provide - the
   browser implementation reached through [register_backend] and dispatched as
   a command - and a drift on either side of that join would compile, pass both
   suites, and surface first in an application. The registration in the doc
   comment on [Nopal_image_web.preview_url] is the exact expression under test
   here, so it is compiled truth rather than prose.

   This seam is also the single place where the store's untyped absence is told
   apart: [object_url] answers [None] both for a handle it holds nothing under
   and for an environment that mints no URL, and only here do those become
   different arms with different owners. Every arm of that collapse is pinned
   below, in this package's own suite, rather than transitively somewhere
   else. *)

open Nopal_image

let photo () =
  Brr.Blob.of_jstr
    ~init:(Brr.Blob.init ~type':(Jstr.v "image/jpeg") ())
    (Jstr.v "receipt photo bytes")

let stored_photo () = Nopal_blob_web.Blob_store.store (photo ())

let released_handle () =
  let handle = stored_photo () in
  Nopal_blob_web.Blob_store.remove handle;
  handle

(* The registration a mounting layer performs, undone afterwards however the
   case ends: the backend is module-level state, and a case that left the
   browser backend installed would change what every later case in this
   executable is testing. *)
let with_browser_backend f =
  Preview.register_backend
    {
      Preview.url = Nopal_image_web.preview_url;
      revoke = Nopal_image_web.revoke_preview_url;
    };
  Fun.protect
    ~finally:(fun () -> Preview.register_backend Preview.default_backend)
    f

(* Runs [f] against a substituted global URL object and puts the real one back
   afterwards, so a case that removes or fakes the browser's minting capability
   cannot leave the rest of the executable without it. *)
let with_global_url replacement f =
  let saved = Jv.get Jv.global "URL" in
  Jv.set Jv.global "URL" replacement;
  Fun.protect ~finally:(fun () -> Jv.set Jv.global "URL" saved) f

(* Drives the seam's command and answers every message it dispatched. A list
   rather than an option because a seam that dispatched twice is invisible to
   an option that simply overwrites. *)
let dispatched ~blob_id =
  let messages = ref [] in
  Nopal_mvu.Cmd.execute
    (fun outcome -> messages := outcome :: !messages)
    (Preview.preview_url ~blob_id Fun.id);
  List.rev !messages

let single ~context messages =
  match messages with
  | [ message ] -> message
  | [] ->
      Alcotest.failf "%s: the command dispatched nothing, expected one message"
        context
  | _ :: _ :: _ ->
      Alcotest.failf "%s: the command dispatched %d messages, expected one"
        context (List.length messages)

let outcome ~context ~blob_id = single ~context (dispatched ~blob_id)

(* Names the constructor without its detail, so a case pins which arm a failure
   was attributed to without also pinning the sentence. Bare [function] so a
   fourth constructor is a compile error here as well as in the library. *)
let arm_of_error = function
  | Preview.Blob_not_found _ -> "Blob_not_found"
  | Preview.Url_unavailable _ -> "Url_unavailable"
  | Preview.Backend_unregistered _ -> "Backend_unregistered"

let detail_of_error = function
  | Preview.Blob_not_found detail
  | Preview.Url_unavailable detail
  | Preview.Backend_unregistered detail ->
      detail

let check_arm ~context ~expected result =
  match result with
  | Ok url ->
      Alcotest.failf "%s: expected the %s arm, got the URL %s" context expected
        url
  | Error error ->
      Alcotest.(check string)
        (context ^ " is attributed to its own arm")
        expected (arm_of_error error);
      let detail = detail_of_error error in
      Alcotest.(check bool)
        (context ^ " explains itself in a sentence, not a token")
        true
        (String.length detail > 0 && String.contains detail ' ')

(* The minted string is the environment's to choose - a browser issues
   blob:<origin>/<uuid>, Node issues blob:nodedata:<uuid> - so the scheme is
   what a case asserts on, never the opaque part. *)
let check_minted ~context result =
  match result with
  | Error error ->
      Alcotest.failf "%s: expected a URL, got %s" context
        (Preview.message error)
  | Ok url ->
      Alcotest.(check bool)
        (Printf.sprintf "%s: %S is a blob: URL" context url)
        true
        (String.starts_with ~prefix:"blob:" url);
      url

(* The whole join in its succeeding direction: a command built from the
   registered backend reaches the real browser mint, and what comes back out of
   the command is a URL the platform issued. The default backend answers every
   call with its own arm, so an [Ok] here can only have come from the
   registration. *)
let test_seam_delivers_object_url () =
  let handle = stored_photo () in
  let url =
    with_browser_backend (fun () ->
        check_minted ~context:"the registered browser backend"
          (outcome ~context:"the registered browser backend" ~blob_id:handle))
  in
  Nopal_blob_web.Blob_store.revoke_url url

(* A handle the store resolves to nothing is the application's failure, not the
   platform's, and it keeps an arm of its own across the seam. Both ways of
   being unknown are covered: a handle that was never issued, and one whose
   entry has since been released. *)
let test_seam_missing_blob_is_blob_not_found () =
  let issued = stored_photo () in
  with_browser_backend (fun () ->
      check_arm ~context:"a handle the store never issued"
        ~expected:"Blob_not_found"
        (outcome ~context:"a fabricated handle" ~blob_id:(issued ^ "-forged"));
      check_arm ~context:"a handle whose entry was released"
        ~expected:"Blob_not_found"
        (outcome ~context:"a released handle" ~blob_id:(released_handle ()));
      (* The affirmative arm on the same fixture: the misses above are misses
         because the handle resolves to nothing, not because the seam answers
         every call with a failure. *)
      let url =
        check_minted ~context:"the issued handle"
          (outcome ~context:"the issued handle" ~blob_id:issued)
      in
      Nopal_blob_web.Blob_store.revoke_url url)

(* The other half of the collapse: the store holds the image, and the platform
   is what produced no URL. Two ways for that to happen - an environment with
   no minting capability at all, and one that refuses the call outright - and
   both belong to the platform's arm rather than to the missing-handle one. *)
let test_seam_stored_blob_without_url_is_url_unavailable () =
  let handle = stored_photo () in
  with_browser_backend (fun () ->
      with_global_url Jv.undefined (fun () ->
          check_arm ~context:"an environment that mints no URLs at all"
            ~expected:"Url_unavailable"
            (outcome ~context:"no URL object" ~blob_id:handle));
      with_global_url
        (Jv.obj
           [|
             ( "createObjectURL",
               Jv.callback ~arity:1 (fun _blob ->
                   Jv.throw (Jstr.v "the browser refused to mint a URL")) );
           |])
        (fun () ->
          check_arm ~context:"a mint the browser refuses outright"
            ~expected:"Url_unavailable"
            (outcome ~context:"a refusing createObjectURL" ~blob_id:handle));
      (* The affirmative arm: the substitutions were what suppressed the URL,
         not a handle that had gone stale between them. *)
      let url =
        check_minted ~context:"the handle once the platform is back"
          (outcome ~context:"the restored platform" ~blob_id:handle)
      in
      Nopal_blob_web.Blob_store.revoke_url url)

exception Dispatch_refused

(* Drives the seam with a delivery that raises, and answers both what it was
   handed and whatever escaped the command.

   An application's update is arbitrary code. A raise out of it must not be
   answered with a second outcome - a platform failure invented out of an
   application bug - and must not escape either, because an exception leaving
   the command strands the caller with no way to tell the effect ever ran. *)
let deliveries_when_dispatch_raises ~blob_id =
  let delivered = ref [] in
  let escaped =
    match
      Nopal_mvu.Cmd.execute
        (fun outcome ->
          delivered := outcome :: !delivered;
          raise Dispatch_refused)
        (Preview.preview_url ~blob_id Fun.id)
    with
    | () -> None
    | exception escaped -> Some escaped
  in
  (List.rev !delivered, escaped)

(* Both halves are reported in one message, and the count is carried into it,
   because the two failing shapes are told apart by that number: an unlatched
   handler answers a second time and only then escapes, while a body that
   raised before delivering anything escapes with nothing delivered at all. *)
let delivered_once ~context (outcomes, escaped) =
  (match escaped with
  | None -> ()
  | Some escaped ->
      Alcotest.failf
        "%s: %d outcome(s) were delivered and then an exception escaped the \
         command instead of being absorbed: %s"
        context (List.length outcomes)
        (Printexc.to_string escaped));
  single ~context outcomes

(* The delivery itself raising, which is the interleaving no other case here
   reaches. Every arm of this seam answers synchronously, inside the guard the
   command builder installs, so a raise out of the dispatch leaves the body and
   lands in that guard's own handler - which closes over a resolver of its own.
   A handler holding an unlatched resolver answers the raise with a second
   outcome; a handler reached only through a resolver latched before it was
   installed cannot. Nothing about that difference is visible to a case whose
   dispatch returns normally, which is every other case in this file.

   Both synchronous arms are driven, because the handler does not know which of
   them ran: the mint the platform answered, and the handle the store resolves
   to nothing. The arm each one delivered is asserted as well as the count, so
   "exactly one" cannot pass against a seam that stopped reaching the store. *)
let test_seam_delivers_once_when_dispatch_raises () =
  with_browser_backend (fun () ->
      let context = "a dispatch that raises on the minted URL" in
      let url =
        check_minted ~context
          (delivered_once ~context
             (deliveries_when_dispatch_raises ~blob_id:(stored_photo ())))
      in
      Nopal_blob_web.Blob_store.revoke_url url;
      let context = "a dispatch that raises on an unresolvable handle" in
      check_arm ~context ~expected:"Blob_not_found"
        (delivered_once ~context
           (deliveries_when_dispatch_raises ~blob_id:(released_handle ()))))

(* Releasing crosses the seam too, and it is the half nothing else can observe:
   no OCaml-visible state changes when a URL is revoked, so a backend that
   released nothing at all would pass every case above. The substituted URL
   object is what makes the call observable, and minting through the same
   object is what proves the string released is the string that was minted. *)
let test_seam_revoke_reaches_the_browser () =
  let handle = stored_photo () in
  let minted = "blob:substituted/9f31-4a08" in
  let released = ref [] in
  let recording_url =
    Jv.obj
      [|
        ( "createObjectURL",
          Jv.callback ~arity:1 (fun _blob -> Jv.of_string minted) );
        ( "revokeObjectURL",
          Jv.callback ~arity:1 (fun url ->
              released := Jv.to_string url :: !released;
              Jv.undefined) );
      |]
  in
  let dispatches = ref 0 in
  with_browser_backend (fun () ->
      with_global_url recording_url (fun () ->
          (match outcome ~context:"the recording platform" ~blob_id:handle with
          | Error error ->
              Alcotest.failf "expected the substituted mint, got %s"
                (Preview.message error)
          | Ok url ->
              Alcotest.(check string)
                "the platform's URL reaches the caller unchanged" minted url);
          Nopal_mvu.Cmd.execute
            (fun (_ : unit) -> incr dispatches)
            (Preview.revoke ~url:minted)));
  (match List.rev !released with
  | [] -> Alcotest.fail "the browser was never asked to release the URL"
  | _ :: _ :: _ ->
      Alcotest.failf "the browser was asked to release %d URLs, expected one"
        (List.length !released)
  | [ seen ] ->
      Alcotest.(check string)
        "the URL the caller released reaches the browser unmodified" minted seen);
  Alcotest.(check int)
    "releasing a URL dispatches no message into the application" 0 !dispatches

let tests =
  [
    Alcotest.test_case "a registered backend mints a browser URL" `Quick
      test_seam_delivers_object_url;
    Alcotest.test_case "an unresolvable handle keeps its own arm" `Quick
      test_seam_missing_blob_is_blob_not_found;
    Alcotest.test_case "a stored image with no mintable URL keeps its own arm"
      `Quick test_seam_stored_blob_without_url_is_url_unavailable;
    Alcotest.test_case "the outcome is delivered once when delivery raises"
      `Quick test_seam_delivers_once_when_dispatch_raises;
    Alcotest.test_case "releasing reaches the browser without dispatching"
      `Quick test_seam_revoke_reaches_the_browser;
  ]

let () = Alcotest.run "Preview seam" [ ("Preview seam", tests) ]

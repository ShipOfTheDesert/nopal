(* Behavioural tests for the session-local blob store.

   The store is module-level state shared by every case in this executable, so
   each case seeds the blobs it needs and identifies entries by identity rather
   than by an assumed empty starting point — no case may assume it runs first.

   Blobs are compared by JavaScript object identity ([Brr.Blob.to_jv] + [==]),
   not by size or MIME type: two distinct blobs can agree on both, and the
   contract under test is that [lookup] returns *the* registered blob. *)

module Blob_store = Nopal_blob_web.Blob_store

let blob ~text ~mime =
  Brr.Blob.of_jstr ~init:(Brr.Blob.init ~type':(Jstr.v mime) ()) (Jstr.v text)

let same_blob a b = Brr.Blob.to_jv a == Brr.Blob.to_jv b

let blob_testable =
  Alcotest.testable
    (fun fmt b ->
      Format.fprintf fmt "<blob %d bytes %s>" (Brr.Blob.byte_length b)
        (Jstr.to_string (Brr.Blob.type' b)))
    same_blob

(* Every handle the store has issued in this executable. [store_tracked] checks
   each new handle against it, so "a handle is never reused within the page
   session" is enforced at every store — after a [remove], after a [clear], or
   anywhere else — without a case needing to know how many handles preceded it.
   Comparing against absolute handle values instead would only catch a recycling
   bug when the recycled range happened to overlap the current case's. *)
let issued = ref []

let store_tracked blob =
  let handle = Blob_store.store blob in
  Alcotest.(check bool)
    (Printf.sprintf "handle %S has not been issued before" handle)
    false (List.mem handle !issued);
  issued := handle :: !issued;
  handle

let check_resolves label expected handle =
  Alcotest.(check (option blob_testable))
    label (Some expected) (Blob_store.lookup handle)

let check_absent label handle =
  Alcotest.(check (option blob_testable)) label None (Blob_store.lookup handle)

let test_round_trip () =
  let receipt = blob ~text:"receipt bytes" ~mime:"text/plain" in
  let handle = store_tracked receipt in
  check_resolves "handle resolves to the blob that was stored" receipt handle

let test_unknown_handle () =
  (* Seeded so the store is non-empty: an unknown handle must miss because it
     was never issued, not because there is nothing to find. *)
  let stored = blob ~text:"present" ~mime:"text/plain" in
  let issued_handle = store_tracked stored in
  check_resolves "the seeded handle resolves" stored issued_handle;
  check_absent "a never-issued handle resolves to None"
    (issued_handle ^ "-forged")

let test_removed_handle () =
  let doomed = blob ~text:"to be released" ~mime:"application/pdf" in
  let handle = store_tracked doomed in
  check_resolves "resolves before removal" doomed handle;
  Blob_store.remove handle;
  check_absent "resolves to None after removal" handle

let test_handles_are_unique () =
  let shared = blob ~text:"stored three times" ~mime:"image/png" in
  let first = store_tracked shared in
  let second = store_tracked shared in
  let third = store_tracked shared in
  Alcotest.(check bool)
    "storing the same blob yields distinct handles" true
    (first <> second && second <> third && first <> third);
  check_resolves "first handle resolves" shared first;
  check_resolves "second handle resolves" shared second;
  check_resolves "third handle resolves" shared third;
  (* Distinct handles are distinct entries: releasing one leaves the others. *)
  Blob_store.remove second;
  check_absent "the released handle is gone" second;
  check_resolves "the first handle survives its sibling's removal" shared first;
  check_resolves "the third handle survives its sibling's removal" shared third;
  (* A later entry answers to its own handle only — [store_tracked] is what
     rules out the released handle being reissued to it. *)
  let other = blob ~text:"a different blob" ~mime:"image/jpeg" in
  let fourth = store_tracked other in
  check_resolves "the later handle resolves to its own blob" other fourth;
  check_absent "the released handle stays released" second

(* The counter is the uniqueness mechanism, so an index-only handle would be
   guessable and a fabricated literal would resolve to a live entry. This pins
   the property that closes that — a handle built from a plausible index alone
   misses — without pinning the handle's shape, which is not part of the
   interface. *)
let test_handles_are_not_index_guessable () =
  let secret = blob ~text:"not to be guessed" ~mime:"text/plain" in
  let handle = store_tracked secret in
  check_resolves "the issued handle resolves" secret handle;
  List.iter
    (fun index ->
      check_absent
        (Printf.sprintf "an index-only handle for %d does not resolve" index)
        (Printf.sprintf "nopal-blob-%d" index))
    [ 0; 1; 2; 3; 4; 5 ]

let test_clear_empties_the_store () =
  let alpha = blob ~text:"alpha" ~mime:"text/plain" in
  let beta = blob ~text:"beta" ~mime:"text/plain" in
  let a = store_tracked alpha in
  let b = store_tracked beta in
  check_resolves "alpha resolves before clear" alpha a;
  check_resolves "beta resolves before clear" beta b;
  Blob_store.clear ();
  check_absent "alpha is gone after clear" a;
  check_absent "beta is gone after clear" b;
  (* [clear] releases entries; it does not disable the store, and it does not
     rewind handle issuance ([store_tracked] enforces the latter). *)
  let gamma = blob ~text:"gamma" ~mime:"text/plain" in
  let c = store_tracked gamma in
  check_resolves "a blob stored after clear resolves" gamma c;
  check_absent "a cleared handle stays cleared once the store is in use again" a

let test_remove_is_idempotent () =
  let target = blob ~text:"target" ~mime:"text/plain" in
  let bystander = blob ~text:"bystander" ~mime:"text/plain" in
  let handle = store_tracked target in
  let untouched = store_tracked bystander in
  Blob_store.remove handle;
  Blob_store.remove handle;
  check_absent "the twice-removed handle resolves to None" handle;
  check_resolves "an unrelated entry is untouched by the repeat removal"
    bystander untouched;
  (* Removing a handle the store never issued is equally inert. *)
  Blob_store.remove (handle ^ "-forged");
  check_resolves "removing an unknown handle leaves the store intact" bystander
    untouched

(* An object URL is minted by the browser, so the assertion is on the scheme
   rather than on the rest of the string: the opaque part is the environment's
   to choose (a browser issues blob:<origin>/<uuid>, Node issues
   blob:nodedata:<uuid>), and pinning it would pin the runtime instead of the
   contract. *)
let starts_with_blob_scheme url = String.starts_with ~prefix:"blob:" url

let check_minted label handle =
  match Blob_store.object_url handle with
  | None -> Alcotest.failf "%s: expected a URL, got None" label
  | Some url ->
      Alcotest.(check bool)
        (Printf.sprintf "%s: %S is a blob: URL" label url)
        true
        (starts_with_blob_scheme url);
      url

let check_no_url label handle =
  Alcotest.(check (option string)) label None (Blob_store.object_url handle)

let test_object_url_of_stored_blob () =
  let photo = blob ~text:"receipt photo bytes" ~mime:"image/jpeg" in
  let handle = store_tracked photo in
  let url = check_minted "a stored handle mints a URL" handle in
  (* Each mint is its own resource: the store hands out a second URL for the
     same blob rather than recycling the first, which is why revoking one URL
     cannot be assumed to release another. *)
  let again = check_minted "the same handle mints again" handle in
  Alcotest.(check bool)
    "a second mint is a distinct URL" true
    (not (String.equal url again));
  Blob_store.revoke_url url;
  Blob_store.revoke_url again

let test_object_url_unknown_handle () =
  (* Seeded so the store is non-empty: the misses below must be misses because
     the handle was never issued, not because there is nothing to find. *)
  let present = blob ~text:"present" ~mime:"text/plain" in
  let issued_handle = store_tracked present in
  let url = check_minted "the seeded handle mints" issued_handle in
  Blob_store.revoke_url url;
  check_no_url "a never-issued handle mints no URL" (issued_handle ^ "-forged");
  (* A released entry is as unknown as one that never existed. *)
  let doomed = blob ~text:"to be released" ~mime:"application/pdf" in
  let removed_handle = store_tracked doomed in
  let doomed_url =
    check_minted "the handle mints before removal" removed_handle
  in
  Blob_store.revoke_url doomed_url;
  Blob_store.remove removed_handle;
  check_no_url "a removed handle mints no URL" removed_handle

(* Runs [f] against a substituted global URL object and puts the real one back
   afterwards, so a case that removes or fakes the browser's minting capability
   cannot leave the rest of the executable without it. *)
let with_global_url replacement f =
  let saved = Jv.get Jv.global "URL" in
  Jv.set Jv.global "URL" replacement;
  Fun.protect ~finally:(fun () -> Jv.set Jv.global "URL" saved) f

(* Releasing changes nothing this suite can read afterwards: [object_url] mints
   from the entries table, which [revoke_url] never touches, so the handle goes
   on minting whether the release happened or not. A case asserting only that no
   exception escaped - or that the entry survived - would pass against a
   [revoke_url] with an empty body. The substituted URL object is what makes the
   call observable: every string handed to revokeObjectURL is recorded, and
   minting through the same object is what proves the string released is the
   string that was minted.

   Idempotence and tolerance of an unrecognised string are the platform's rather
   than this module's, so what is pinned here is that each release reaches the
   platform once and unmodified - four calls, four recorded strings - rather
   than that the fourth of them did nothing. *)
let test_revoke_url_idempotent () =
  let target = blob ~text:"target" ~mime:"image/png" in
  let handle = store_tracked target in
  let minted = "blob:substituted/6b21-47e0" in
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
  with_global_url recording_url (fun () ->
      let url = check_minted "the handle mints" handle in
      Alcotest.(check string)
        "the platform's URL reaches the caller unchanged" minted url;
      Blob_store.revoke_url url;
      Blob_store.revoke_url url;
      (* Revoking a string the store never minted is equally inert. A URL is not
         a handle, so this also covers the caller who passes the wrong one. *)
      Blob_store.revoke_url "blob:never-minted-by-this-store";
      Blob_store.revoke_url handle);
  Alcotest.(check (list string))
    "every release reaches the browser, in order and unmodified"
    [ minted; minted; "blob:never-minted-by-this-store"; handle ]
    (List.rev !released);
  (* The affirmative arm, against the real platform: revocation releases the URL
     that was revoked, never the entry behind it. *)
  let after =
    check_minted "the blob still mints after its URL was revoked" handle
  in
  Blob_store.revoke_url after

(* The store is the single place where "this environment can mint object URLs"
   collapses into [Some]/[None], and the platform is what decides it — so the
   absent arm is pinned here, at the boundary that owns the collapse, rather
   than left to a runtime nobody tests on. Each substitution below is a
   different way for the capability to be missing. *)
let test_object_url_without_platform_support () =
  let photo = blob ~text:"receipt photo bytes" ~mime:"image/jpeg" in
  let handle = store_tracked photo in
  with_global_url Jv.undefined (fun () ->
      check_no_url "no URL object mints nothing" handle;
      (* Inert rather than raising: the caller releasing whatever it holds has
         no way to know the environment lost the capability. *)
      Blob_store.revoke_url "blob:whatever");
  with_global_url (Jv.obj [||]) (fun () ->
      check_no_url "a URL object without createObjectURL mints nothing" handle;
      Blob_store.revoke_url "blob:whatever");
  with_global_url
    (Jv.obj
       [|
         ("createObjectURL", Jv.callback ~arity:1 (fun _blob -> Jv.of_int 42));
       |])
    (fun () -> check_no_url "a mint that is not a string is no URL" handle);
  (* The affirmative arm: the substitutions were what suppressed the URL, not a
     handle that had gone stale. *)
  let restored =
    check_minted "the handle mints again once URL is back" handle
  in
  Blob_store.revoke_url restored

(* Refusal is the other way for the platform to produce no URL, and it is not
   the same as absence: both methods are present and callable, and both throw
   when called - a quota, a hardened or proxied global, a blocked call. A JS
   throw crosses [Jv.call] as [Jv.Error], so an unguarded call would raise out
   of two functions this package documents as answering an absence and never an
   exception. Releasing is covered here too, and for a sharper reason: it
   reports no outcome at all, so a caller has nothing to inspect and a raise
   would escape into whatever batch of effects the release was part of. *)
let test_object_url_when_the_platform_refuses () =
  let photo = blob ~text:"receipt photo bytes" ~mime:"image/jpeg" in
  let handle = store_tracked photo in
  let refusing_url =
    Jv.obj
      [|
        ( "createObjectURL",
          Jv.callback ~arity:1 (fun _blob ->
              Jv.throw (Jstr.v "the browser refused to mint a URL")) );
        ( "revokeObjectURL",
          Jv.callback ~arity:1 (fun _url ->
              Jv.throw (Jstr.v "the browser refused to release a URL")) );
      |]
  in
  with_global_url refusing_url (fun () ->
      check_no_url "a mint the platform refuses is no URL" handle;
      Blob_store.revoke_url "blob:whatever");
  (* The affirmative arm: the refusal was what suppressed the URL, not a handle
     that had gone stale. *)
  let restored =
    check_minted "the handle mints again once URL stops refusing" handle
  in
  Blob_store.revoke_url restored

let () =
  Alcotest.run "blob_store"
    [
      ( "blob_store",
        [
          Alcotest.test_case "stored blob round-trips by handle" `Quick
            test_round_trip;
          Alcotest.test_case "unknown handle returns None" `Quick
            test_unknown_handle;
          Alcotest.test_case "removed handle returns None" `Quick
            test_removed_handle;
          Alcotest.test_case "handles are unique across stores" `Quick
            test_handles_are_unique;
          Alcotest.test_case "handles are not index-guessable" `Quick
            test_handles_are_not_index_guessable;
          Alcotest.test_case "clear empties the store" `Quick
            test_clear_empties_the_store;
          Alcotest.test_case "remove is idempotent" `Quick
            test_remove_is_idempotent;
          Alcotest.test_case "stored blob mints an object URL" `Quick
            test_object_url_of_stored_blob;
          Alcotest.test_case "unknown handle mints no object URL" `Quick
            test_object_url_unknown_handle;
          Alcotest.test_case "revoking a URL is idempotent" `Quick
            test_revoke_url_idempotent;
          Alcotest.test_case "no platform support mints no object URL" `Quick
            test_object_url_without_platform_support;
          Alcotest.test_case "a refusing platform mints no object URL" `Quick
            test_object_url_when_the_platform_refuses;
        ] );
    ]

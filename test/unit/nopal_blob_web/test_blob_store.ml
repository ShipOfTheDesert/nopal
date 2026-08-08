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
        ] );
    ]

(* Behavioural tests for the hand-written canvas bindings, against the fake in
   image_pipeline_shim.js.

   Each case states its whole fixture after [reset]: the shim's decoded-image
   size starts at 0 x 0 and every failure switch starts off, so nothing here
   inherits a plausible-looking default from a previous case or from the shim.

   Every case pairs the behaviour under test with the way the platform fails it,
   on the same fixture. That pairing is what keeps the success arms honest — a
   [decode] that never called its continuation, or a [context_2d] that answered
   [Some] unconditionally, would pass one arm and fail the other. Mapping these
   failures onto typed error constructors is the pipeline's contract, not this
   module's, and is tested separately. *)

module Canvas_ffi = Nopal_image_web_internal.Canvas_ffi
open Image_web_test_helpers

(* Whether [f] refused rather than returned. The returned value is discarded
   inside the helper rather than at the call site: what is under assertion is
   the refusal, and a call that returns anything at all has already falsified
   it. *)
let refuses f =
  match f () with
  | exception Jv.Error _ -> true
  | _returned -> false

(* A blob stands in for the encoded bytes a file input would hand over. Its
   contents are never decoded — the shim's [source] is what the decode yields —
   so any bytes will do. *)
let some_encoded_image () = Brr.Blob.of_jstr (Jstr.v "pretend this is a JPEG")

(* Starts a decode and answers everything its continuation received, having
   first asserted that it received nothing before the queue was drained.

   That assertion is the point: a browser answers a decode on a later turn, and
   a binding that called its continuation before returning would let every
   caller's delivery happen inside whatever guard was still on the stack. *)
let decode_outcomes blob =
  let outcomes = ref [] in
  Canvas_ffi.decode blob (fun outcome -> outcomes := outcome :: !outcomes);
  Alcotest.(check int)
    "the decode had not answered before the later turn arrived" 0
    (List.length !outcomes);
  flush ();
  List.rev !outcomes

let test_decode_resolves_bitmap () =
  reset ();
  set_source ~width:640 ~height:480;
  (match decode_outcomes (some_encoded_image ()) with
  | [ Ok bitmap ] ->
      Alcotest.(check int)
        "the decoded bitmap reports the source width" 640
        (Canvas_ffi.bitmap_width bitmap);
      Alcotest.(check int)
        "the decoded bitmap reports the source height" 480
        (Canvas_ffi.bitmap_height bitmap);
      Canvas_ffi.release bitmap;
      Alcotest.(check int) "release closes the decoded bitmap" 1 (releases ());
      (* The signature promises that releasing twice is harmless. Nothing else
         asserts it, and the pipeline's release count is used as a correctness
         signal, so the claim is pinned here rather than taken on trust. *)
      Canvas_ffi.release bitmap;
      Alcotest.(check bool)
        "releasing an already-released bitmap does not raise" true true
  | [ Error msg ] ->
      Alcotest.failf "expected a decoded bitmap, got the failure %S" msg
  | delivered ->
      Alcotest.failf "expected exactly one decode outcome, got %d"
        (List.length delivered));
  (* The rejection arm. A browser that cannot decode the bytes rejects the
     promise; the caller must be told rather than left waiting. *)
  reset ();
  set_source ~width:640 ~height:480;
  inject_failure "decode";
  match decode_outcomes (some_encoded_image ()) with
  | [ Error msg ] ->
      Alcotest.(check bool)
        "the words the rejection carried reach the caller" true
        (Test_util.string_contains msg ~sub:(rejection ()))
  | [ Ok _ ] ->
      Alcotest.fail "expected the injected decode rejection to surface"
  | delivered ->
      Alcotest.failf "expected exactly one decode outcome, got %d"
        (List.length delivered)

(* A rejected promise carries whatever the rejecting code passed, and that is
   not required to be an [Error]. Three shapes reach three different arms of the
   binding, and each must still produce a sentence for a reader.

   The last two are what an unchecked cast gets wrong: a [message] property that
   exists but is not a string would be read as one, producing a value typed
   [string] that the runtime never laid out that way. *)
let test_decode_rejection_shapes_all_describe_themselves () =
  let message_when shape =
    reset ();
    set_source ~width:640 ~height:480;
    inject_failure "decode";
    reject_decode_with shape;
    match decode_outcomes (some_encoded_image ()) with
    | [ Error msg ] -> msg
    | [ Ok _ ] ->
        Alcotest.failf "expected the %s rejection to surface as a failure" shape
    | delivered ->
        Alcotest.failf "expected exactly one decode outcome, got %d"
          (List.length delivered)
  in
  let nothing = message_when "nothing" in
  Alcotest.(check bool)
    "a rejection carrying nothing still explains itself in a sentence" true
    (String.length nothing > 0 && String.contains nothing ' ');
  Alcotest.(check bool)
    "a rejection carrying a bare string carries its words through" true
    (Test_util.string_contains (message_when "bare-string") ~sub:(rejection ()));
  Alcotest.(check bool)
    "a rejection whose message is not a string falls back to describing it" true
    (Test_util.string_contains
       (message_when "nonstring-message")
       ~sub:(rejection ()))

let test_context_absent_is_none () =
  reset ();
  let served = Canvas_ffi.create_canvas ~width:4 ~height:3 in
  Alcotest.(check bool)
    "a canvas the platform can serve yields a context" true
    (Option.is_some (Canvas_ffi.context_2d served));
  (* An environment that cannot hand out a 2D context returns null rather than
     throwing, which is why the binding is an option rather than a raise. *)
  reset ();
  inject_failure "context";
  let starved = Canvas_ffi.create_canvas ~width:4 ~height:3 in
  Alcotest.(check bool)
    "a canvas that yields no 2D context is None" true
    (Option.is_none (Canvas_ffi.context_2d starved));
  (* Starving one width leaves every other canvas served, which is what lets a
     case reach the second of the pipeline's two passes. *)
  reset ();
  starve_context_for_width 4;
  let narrow = Canvas_ffi.create_canvas ~width:4 ~height:3 in
  let wide = Canvas_ffi.create_canvas ~width:9 ~height:3 in
  Alcotest.(check bool)
    "the starved width yields no context" true
    (Option.is_none (Canvas_ffi.context_2d narrow));
  Alcotest.(check bool)
    "every other width is still served" true
    (Option.is_some (Canvas_ffi.context_2d wide))

let test_encode_passes_mime_and_quality () =
  reset ();
  let canvas = Canvas_ffi.create_canvas ~width:11 ~height:7 in
  let outcomes = ref [] in
  (* Neither value is the recommended configuration's, so an encode that
     hardcodes a format or a quality cannot pass. *)
  Canvas_ffi.encode canvas ~mime:"image/webp" ~quality:0.42 (fun outcome ->
      outcomes := outcome :: !outcomes);
  Alcotest.(check string)
    "the encoder receives the media type it was given" "image/webp"
    (Jv.to_string (first_encode "mime"));
  Alcotest.(check (float 1e-9))
    "the encoder receives the quality it was given" 0.42
    (Jv.to_float (first_encode "quality"));
  (* A quality passed as a string is ignored by the real encoder, silently
     falling back to its default. *)
  Alcotest.(check string)
    "the quality reaches the encoder as a number" "number"
    (Jv.to_string (first_encode "qualityType"));
  Alcotest.(check int)
    "the encoder had not answered before the later turn arrived" 0
    (List.length !outcomes);
  flush ();
  (match !outcomes with
  | [ Ok blob ] ->
      Alcotest.(check string)
        "the encoded blob is the one the encoder produced" "image/webp"
        (Jstr.to_string (Brr.Blob.type' blob));
      Alcotest.(check bool)
        "the encoded blob carries bytes" true
        (Brr.Blob.byte_length blob > 0)
  | [ Error msg ] ->
      Alcotest.failf "expected an encoded blob, got the failure %S" msg
  | delivered ->
      Alcotest.failf "expected exactly one encode outcome, got %d"
        (List.length delivered));
  (* The failure arm. A browser that cannot encode calls back with null. *)
  reset ();
  inject_failure "encode";
  let canvas = Canvas_ffi.create_canvas ~width:11 ~height:7 in
  let failed = ref [] in
  Canvas_ffi.encode canvas ~mime:"image/webp" ~quality:0.42 (fun outcome ->
      failed := outcome :: !failed);
  flush ();
  match !failed with
  | [ Error msg ] ->
      Alcotest.(check bool)
        "a failed encode reports a non-empty message" true
        (String.length msg > 0)
  | [ Ok _ ] -> Alcotest.fail "expected the injected encode failure to surface"
  | delivered ->
      Alcotest.failf "expected exactly one encode outcome, got %d"
        (List.length delivered)

let test_pixel_read_returns_expected_length () =
  reset ();
  (* 7 x 5 is neither the shim's 300 x 150 default backing store nor a square,
     so a create_canvas that never wrote the size, or a read that took the
     dimensions from somewhere other than the canvas, lands on a different
     length. *)
  let canvas = Canvas_ffi.create_canvas ~width:7 ~height:5 in
  (match Canvas_ffi.context_2d canvas with
  | None -> Alcotest.fail "expected a context from a canvas the shim can serve"
  | Some context ->
      Alcotest.(check int)
        "four bytes per pixel of the canvas backing store"
        (7 * 5 * 4)
        (Brr.Tarray.length (Canvas_ffi.read_pixels context));
      Alcotest.(check int) "exactly one pixel read crossed" 1 (pixel_reads ()));
  (* The propagation arm. A read the browser refuses throws synchronously; the
     binding lets it escape so the caller can attribute it to this stage. *)
  reset ();
  inject_failure "pixels";
  let canvas = Canvas_ffi.create_canvas ~width:7 ~height:5 in
  match Canvas_ffi.context_2d canvas with
  | None -> Alcotest.fail "expected a context from a canvas the shim can serve"
  | Some context ->
      Alcotest.(check bool)
        "a refused pixel read escapes to the caller" true
        (refuses (fun () -> Canvas_ffi.read_pixels context));
      Alcotest.(check int)
        "a refused pixel read crosses no pixels" 0 (pixel_reads ())

let tests =
  [
    Alcotest.test_case "decode resolves a bitmap" `Quick
      test_decode_resolves_bitmap;
    Alcotest.test_case "every rejection shape describes itself" `Quick
      test_decode_rejection_shapes_all_describe_themselves;
    Alcotest.test_case "an absent 2D context is None" `Quick
      test_context_absent_is_none;
    Alcotest.test_case "encode passes the mime and quality" `Quick
      test_encode_passes_mime_and_quality;
    Alcotest.test_case "a pixel read returns the expected length" `Quick
      test_pixel_read_returns_expected_length;
  ]

let () = Alcotest.run "Canvas_ffi" [ ("Canvas_ffi", tests) ]

(* Behavioural tests for the browser pipeline's failing paths, against the fake
   in image_pipeline_shim.js.

   Four separate contracts are under test here, and they are separate on
   purpose:

   - Every stage that can fail surfaces as its own constructor. Each arm case
     runs the SAME fixture twice, once with the stage's failure injected and
     once without, and asserts the injected run yields that arm while the clean
     run yields a processed image. A pipeline that always failed would pass
     neither half.
   - The constructor is chosen by which stage refused, never by reading the
     message. The classification case injects a synchronous refusal at five
     stages carrying one identical sentence that names nothing, so the arms it
     produces out of one message are the proof.
   - The decoded bitmap is freed on the failing paths, not only on the
     successful one, and freed once however many times the pipeline reaches its
     exit.
   - Whatever happens, the caller receives exactly one outcome - including when
     delivering that outcome raises, which is the shape a guard that does not
     deduplicate answers with a second, invented failure.

   The shim answers the decode and the encode on a later turn, as a browser
   does, so the deliveries below happen after the task body has returned. That
   is the interleaving a synchronous fake cannot produce, and it is why the
   resolve-once cases here mean something. *)

open Nopal_image
open Image_web_test_helpers

(* Runs one arm: the fixture with the stage's platform failure injected, then
   the same fixture clean. Asserts the injected run blames [stage] and the
   clean run produces an image, so an arm cannot pass against a pipeline that
   fails everything or against one that fails nothing. *)
let check_arm ~inject ~expected_stage ~description =
  let config = fixture_config () in
  reset ();
  set_source ~width:1000 ~height:750;
  let blob_id = inject () in
  let err = failure_of (run_pipeline ~blob_id ~config) in
  Alcotest.(check string) description expected_stage (stage_of_error err);
  Alcotest.(check bool)
    "the failure carries a description for a reader" true
    (String.length (detail_of_error err) > 0);
  reset ();
  set_source ~width:1000 ~height:750;
  let clean = processed (run_pipeline ~blob_id:(stored_source ()) ~config) in
  Alcotest.(check bool)
    "the same fixture succeeds with nothing injected" true
    (String.length clean.Processing.blob_id > 0)

let test_missing_blob_is_error () =
  check_arm
    ~inject:(fun () -> released_handle ())
    ~expected_stage:"blob lookup"
    ~description:"a handle the store no longer holds blames the lookup"

let test_decode_failure_is_error () =
  check_arm
    ~inject:(fun () ->
      inject_failure "decode";
      stored_source ())
    ~expected_stage:"decode"
    ~description:"bytes the browser will not decode blame the decode"

let test_canvas_unavailable_is_error () =
  check_arm
    ~inject:(fun () ->
      inject_failure "context";
      stored_source ())
    ~expected_stage:"canvas"
    ~description:"an environment that hands out no drawing context blames it"

let test_encode_failure_is_error () =
  check_arm
    ~inject:(fun () ->
      inject_failure "encode";
      stored_source ())
    ~expected_stage:"encode"
    ~description:"an encoder that produces nothing blames the encode"

let test_pixel_read_failure_is_error () =
  check_arm
    ~inject:(fun () ->
      inject_failure "pixels";
      stored_source ())
    ~expected_stage:"pixel read"
    ~description:"a refused pixel read blames the read rather than escaping"

(* The two downscales fail independently, and each says which one it was.

   The pipeline allocates the upload canvas first, so a switch that starved
   every canvas could only ever reach the upload pass and the sharpness pass's
   name would be unreachable - a wrong name there would read as a sentence about
   a pass that never ran, and nothing would catch it. Starving one width at a
   time is what separates them: 900 is the upload canvas under this fixture, 100
   is the metric one. *)
let test_each_pass_names_itself_when_starved () =
  let config = fixture_config () in
  let detail_when_starving width =
    reset ();
    set_source ~width:1000 ~height:750;
    starve_context_for_width width;
    let err = failure_of (run_pipeline ~blob_id:(stored_source ()) ~config) in
    Alcotest.(check string)
      "a starved canvas blames the canvas" "canvas" (stage_of_error err);
    detail_of_error err
  in
  Alcotest.(check bool)
    "starving the upload canvas names the upload pass" true
    (Test_util.string_contains (detail_when_starving 900) ~sub:"upload");
  Alcotest.(check bool)
    "starving the metric canvas names the sharpness pass" true
    (Test_util.string_contains (detail_when_starving 100) ~sub:"sharpness")

(* The stage that refused names the arm; the text of the refusal never does.

   All five injections raise one identical sentence, published by the shim so
   the two cannot drift apart, and that sentence names no stage, no API and no
   failure kind. Different arms out of one message is the whole assertion: an
   implementation that classified by substring could not produce it. The message
   is still carried through, so a developer reading the failure sees what the
   browser actually said.

   The "bitmap" injection is the one with no canvas in play: it refuses the
   decoded image's own dimensions. It belongs to the decode, because what
   refused is the decoded image, and a pipeline that read those dimensions
   inside its first canvas region would blame the canvas instead. *)
let test_error_mapper_classifies_by_stage () =
  let config = fixture_config () in
  let stage_blamed_when_refusing at =
    reset ();
    set_source ~width:1000 ~height:750;
    inject_refusal at;
    let err = failure_of (run_pipeline ~blob_id:(stored_source ()) ~config) in
    Alcotest.(check bool)
      "the browser's own words reach the caller" true
      (Test_util.string_contains (detail_of_error err) ~sub:(refusal ()));
    stage_of_error err
  in
  Alcotest.(check string)
    "a decoder that refuses blames the decode" "decode"
    (stage_blamed_when_refusing "decode");
  Alcotest.(check string)
    "a decoded image that refuses its own size blames the decode" "decode"
    (stage_blamed_when_refusing "bitmap");
  Alcotest.(check string)
    "a context that refuses blames the canvas" "canvas"
    (stage_blamed_when_refusing "context");
  Alcotest.(check string)
    "an encoder that refuses blames the encode" "encode"
    (stage_blamed_when_refusing "encode");
  Alcotest.(check string)
    "a pixel read that refuses blames the read" "pixel read"
    (stage_blamed_when_refusing "pixels")

(* A decoded full-resolution image is the largest thing this pipeline holds and
   re-selecting a photo is expected behaviour, so every path that decodes one
   frees it - the failing paths included.

   The three post-decode stages are each driven to failure and each must report
   one release. The decode failure is the contrast: nothing was decoded there,
   so releasing anything would mean releasing something the pipeline never
   obtained. *)
let test_bitmap_released_on_failure () =
  let config = fixture_config () in
  let blamed_and_released stage =
    reset ();
    set_source ~width:1000 ~height:750;
    inject_failure stage;
    let err = failure_of (run_pipeline ~blob_id:(stored_source ()) ~config) in
    (stage_of_error err, releases ())
  in
  Alcotest.(check (pair string int))
    "a canvas failure after the decode still frees the decoded image"
    ("canvas", 1)
    (blamed_and_released "context");
  Alcotest.(check (pair string int))
    "an encode failure after the decode still frees the decoded image"
    ("encode", 1)
    (blamed_and_released "encode");
  Alcotest.(check (pair string int))
    "a pixel read failure after the decode still frees the decoded image"
    ("pixel read", 1)
    (blamed_and_released "pixels");
  Alcotest.(check (pair string int))
    "a decode that never produced an image frees nothing" ("decode", 0)
    (blamed_and_released "decode")

exception Dispatch_refused

(* Starts the pipeline with a delivery that raises, drains the deferred stages,
   and answers how many outcomes were delivered together with whatever escaped.

   An application's update is arbitrary code. A raise from it must not become a
   second outcome - a browser failure invented out of an application bug - and
   must not escape either: an exception leaving the task strands the caller with
   no way to tell it ever ran. *)
let deliveries_when_dispatch_raises ~blob_id =
  let config = fixture_config () in
  let deliveries = ref 0 in
  let deliver _outcome =
    incr deliveries;
    raise Dispatch_refused
  in
  let escaped =
    match
      Nopal_mvu.Task.run (Nopal_image_web.process ~blob_id ~config) deliver;
      flush ()
    with
    | () -> None
    | exception escaped -> Some escaped
  in
  (!deliveries, escaped)

let check_delivered_once ~context (deliveries, escaped) =
  Alcotest.(check int)
    (context ^ ": the outcome was delivered exactly once")
    1 deliveries;
  match escaped with
  | None -> ()
  | Some escaped ->
      Alcotest.failf
        "%s: a raising delivery escaped the task instead of being absorbed: %s"
        context
        (Printexc.to_string escaped)

(* The successful exit. The delivery happens inside the region that surrounds
   the encode continuation, so that region catches the raise and answers by
   finishing again - which must free nothing further and deliver nothing
   further. *)
let test_resolves_once_when_dispatch_raises () =
  reset ();
  set_source ~width:1000 ~height:750;
  check_delivered_once ~context:"a processed image"
    (deliveries_when_dispatch_raises ~blob_id:(stored_source ()));
  Alcotest.(check int)
    "the decoded image was freed exactly once even so" 1 (releases ())

(* The handle lookup, which is the one delivery that happens synchronously,
   inside the task body's own exception guard. A guard holding the raw resolver
   answers the raise with a second outcome; a guard holding a latched one
   cannot. This is the arm that distinguishes the two, and it is unreachable
   from the successful exit above. *)
let test_missing_handle_resolves_once_when_dispatch_raises () =
  reset ();
  set_source ~width:1000 ~height:750;
  check_delivered_once ~context:"an unresolvable handle"
    (deliveries_when_dispatch_raises ~blob_id:(released_handle ()))

(* The decode rejection, which is delivered from a continuation the browser
   calls on a later turn - after the task body returned and its guard came off
   the stack. Nothing but the region around that continuation can absorb a raise
   there. *)
let test_rejected_decode_resolves_once_when_dispatch_raises () =
  reset ();
  set_source ~width:1000 ~height:750;
  inject_failure "decode";
  check_delivered_once ~context:"a rejected decode"
    (deliveries_when_dispatch_raises ~blob_id:(stored_source ()))

let tests =
  [
    Alcotest.test_case "an unresolvable handle is an error" `Quick
      test_missing_blob_is_error;
    Alcotest.test_case "a failed decode is an error" `Quick
      test_decode_failure_is_error;
    Alcotest.test_case "an absent drawing context is an error" `Quick
      test_canvas_unavailable_is_error;
    Alcotest.test_case "a failed encode is an error" `Quick
      test_encode_failure_is_error;
    Alcotest.test_case "a refused pixel read is an error" `Quick
      test_pixel_read_failure_is_error;
    Alcotest.test_case "each downscale names itself when starved" `Quick
      test_each_pass_names_itself_when_starved;
    Alcotest.test_case "a refusal is classified by the stage that raised it"
      `Quick test_error_mapper_classifies_by_stage;
    Alcotest.test_case "the decoded image is freed on a failing path" `Quick
      test_bitmap_released_on_failure;
    Alcotest.test_case "the outcome is delivered once when delivery raises"
      `Quick test_resolves_once_when_dispatch_raises;
    Alcotest.test_case
      "an unresolvable handle delivers once when delivery raises" `Quick
      test_missing_handle_resolves_once_when_dispatch_raises;
    Alcotest.test_case "a rejected decode delivers once when delivery raises"
      `Quick test_rejected_decode_resolves_once_when_dispatch_raises;
  ]

let () = Alcotest.run "Pipeline errors" [ ("Pipeline errors", tests) ]

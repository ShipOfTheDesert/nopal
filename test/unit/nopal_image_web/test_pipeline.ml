(* Behavioural tests for the browser pipeline's successful pass, against the
   fake in image_pipeline_shim.js.

   Each case states its whole fixture after [reset]: the shim's decoded-image
   size starts at 0 x 0 and every failure switch starts off, so nothing here
   inherits a plausible-looking size from a previous case or from the shim.

   Two properties the fixtures are chosen for, because they are what keeps the
   assertions from passing for the wrong reason:

   - The decoded size comes from the shim's [source], which the pipeline never
     supplies, so a pipeline echoing its own configuration cannot match it.
   - The encoded blob's length tracks the canvas the encoder ran on and matches
     no configuration number, so a byte size copied out of the request cannot
     match it either.

   The failing stages, the resolve-once latch and the release-on-failure
   guarantee are a separate concern and are tested separately. *)

open Nopal_image
open Image_web_test_helpers

(* 1000 x 750 capped at a 900 pixel long edge downscales to 900 x 675; the
   sharpness pass, capped at 100, draws the same source at 100 x 75. Neither
   pass reuses the other's size, so a pipeline that measured the upload canvas
   instead of allocating a second one is visible. *)
let test_pipeline_call_sequence () =
  reset ();
  set_source ~width:1000 ~height:750;
  let config =
    capture_config ~max_edge:900 ~metric_edge:100 ~quality:0.55
      ~format:Config.Webp
  in
  let info = processed (run_pipeline ~blob_id:(stored_source ()) ~config) in
  Alcotest.(check (list string))
    "decode, the upload draw, encode, the metric draw, one pixel read, release"
    [ "decode"; "draw"; "encode"; "draw"; "pixels"; "release" ]
    (calls ());
  Alcotest.(check (list (pair int int)))
    "the upload pass and the sharpness pass draw at different target sizes"
    [ (900, 675); (100, 75) ]
    (draws ());
  Alcotest.(check int)
    "the stored image is the one the upload pass drew" 900 info.Processing.width

(* The pixels cross into OCaml exactly once per processed image, and on the
   sharpness canvas rather than the upload one. A pipeline that read the upload
   canvas as well would carry the full stored image across the boundary. *)
let test_single_pixel_read () =
  reset ();
  set_source ~width:1000 ~height:750;
  let config =
    capture_config ~max_edge:900 ~metric_edge:100 ~quality:0.55
      ~format:Config.Webp
  in
  let info = processed (run_pipeline ~blob_id:(stored_source ()) ~config) in
  Alcotest.(check bool)
    "the pass produced a stored handle" true
    (String.length info.Processing.blob_id > 0);
  Alcotest.(check int) "exactly one pixel read crossed" 1 (pixel_reads ())

(* The encoder is asked for the media type naming the configured format, for
   every format the configuration can carry - a pipeline hardcoding one of them
   passes for the other two and fails here. The expected media types are written
   out rather than derived from [Config.format_to_mime], so a wrong mapping is a
   failure rather than a tautology. *)
let test_encode_uses_typed_format () =
  let check_format format expected_mime =
    reset ();
    set_source ~width:1000 ~height:750;
    let config =
      capture_config ~max_edge:900 ~metric_edge:100 ~quality:0.55 ~format
    in
    let info = processed (run_pipeline ~blob_id:(stored_source ()) ~config) in
    Alcotest.(check (list string))
      "the encoder is asked for the configured format" [ expected_mime ]
      (encode_mimes ());
    Alcotest.(check string)
      "the stored blob carries the media type it was encoded as" expected_mime
      (Jstr.to_string (Brr.Blob.type' (blob_under info.Processing.blob_id)))
  in
  check_format Config.Jpeg "image/jpeg";
  check_format Config.Png "image/png";
  check_format Config.Webp "image/webp"

(* Every reported size describes what was produced, never what was asked for.

   The first fixture's source sits under the cap, so nothing is downscaled and
   all three reported numbers - 640, 512 and 1927 bytes - are unrelated to the
   900 and 100 in the configuration. The second downscales, which necessarily
   puts the configured cap on the long edge; there the height and the byte size
   carry the discrimination. Together the two exclude both a result echoed from
   the configuration and one echoed from the source. *)
let test_result_reports_observed_output () =
  let config =
    capture_config ~max_edge:900 ~metric_edge:100 ~quality:0.55
      ~format:Config.Webp
  in
  reset ();
  set_source ~width:640 ~height:512;
  let unscaled = processed (run_pipeline ~blob_id:(stored_source ()) ~config) in
  Alcotest.(check int)
    "a source under the cap is stored at its own width" 640
    unscaled.Processing.width;
  Alcotest.(check int)
    "a source under the cap is stored at its own height" 512
    unscaled.Processing.height;
  Alcotest.(check int)
    "the reported byte size is the encoded blob's own length" 1927
    unscaled.Processing.byte_size;
  Alcotest.(check int)
    "the reported byte size is the length of the blob that was stored"
    (Brr.Blob.byte_length (blob_under unscaled.Processing.blob_id))
    unscaled.Processing.byte_size;
  reset ();
  set_source ~width:1000 ~height:750;
  let scaled = processed (run_pipeline ~blob_id:(stored_source ()) ~config) in
  Alcotest.(check int)
    "a downscaled source is stored at the capped long edge" 900
    scaled.Processing.width;
  Alcotest.(check int)
    "a downscaled source keeps its aspect ratio in the short edge" 675
    scaled.Processing.height;
  Alcotest.(check int)
    "the byte size follows the canvas that was encoded" 2707
    scaled.Processing.byte_size

(* The processed image is written back under a handle of its own and the handle
   that was processed keeps its entry, so a caller can still show or discard the
   original after uploading the processed one. *)
let test_processed_blob_is_new_handle () =
  reset ();
  set_source ~width:1000 ~height:750;
  let config =
    capture_config ~max_edge:900 ~metric_edge:100 ~quality:0.55
      ~format:Config.Webp
  in
  let source_id = stored_source () in
  let info = processed (run_pipeline ~blob_id:source_id ~config) in
  Alcotest.(check bool)
    "the processed image is stored under a different handle" true
    (not (String.equal info.Processing.blob_id source_id));
  Alcotest.(check int)
    "the processed handle resolves to the bytes the result reports"
    info.Processing.byte_size
    (Brr.Blob.byte_length (blob_under info.Processing.blob_id));
  Alcotest.(check bool)
    "the handle that was processed still resolves" true
    (Brr.Blob.byte_length (blob_under source_id) > 0)

let tests =
  [
    Alcotest.test_case "the pipeline runs its stages in order" `Quick
      test_pipeline_call_sequence;
    Alcotest.test_case "pixels cross exactly once" `Quick test_single_pixel_read;
    Alcotest.test_case "the encode uses the configured format" `Quick
      test_encode_uses_typed_format;
    Alcotest.test_case "the result reports the observed output" `Quick
      test_result_reports_observed_output;
    Alcotest.test_case "the processed image gets a new handle" `Quick
      test_processed_blob_is_new_handle;
  ]

let () = Alcotest.run "Pipeline" [ ("Pipeline", tests) ]

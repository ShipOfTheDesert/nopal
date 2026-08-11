open Nopal_image

(* The shim is reached through the global it installs rather than through a Brr
   module, because none of what it fakes is bound by Brr. *)
let shim () = Jv.get Jv.global "__imagePipeline"
let reset () = ignore (Jv.call (shim ()) "reset" [||])
let flush () = ignore (Jv.call (shim ()) "flush" [||])

let set_source ~width ~height =
  Jv.set (shim ()) "source"
    (Jv.obj [| ("width", Jv.of_int width); ("height", Jv.of_int height) |])

let inject_failure stage =
  Jv.set (Jv.get (shim ()) "fail") stage (Jv.of_bool true)

let inject_refusal stage =
  Jv.set (Jv.get (shim ()) "throws") stage (Jv.of_bool true)

let starve_context_for_width width =
  Jv.set (Jv.get (shim ()) "fail") "contextForWidth" (Jv.of_int width)

let reject_decode_with shape =
  Jv.set (shim ()) "rejectWith" (Jv.of_string shape)

let refusal () = Jv.to_string (Jv.get (shim ()) "refusal")
let rejection () = Jv.to_string (Jv.get (shim ()) "rejection")
let calls () = List.map Jv.to_string (Jv.to_jv_list (Jv.get (shim ()) "calls"))

let draws () =
  List.map
    (fun draw ->
      (Jv.to_int (Jv.get draw "width"), Jv.to_int (Jv.get draw "height")))
    (Jv.to_jv_list (Jv.get (shim ()) "draws"))

let encode_mimes () =
  List.map
    (fun encode -> Jv.to_string (Jv.get encode "mime"))
    (Jv.to_jv_list (Jv.get (shim ()) "encodes"))

let first_encode field =
  match Jv.to_jv_list (Jv.get (shim ()) "encodes") with
  | [] -> Alcotest.fail "the shim recorded no encode call"
  | encode :: _ -> Jv.get encode field

let pixel_reads () = Jv.to_int (Jv.get (shim ()) "pixelReads")
let releases () = Jv.to_int (Jv.get (shim ()) "releases")

let capture_config ~max_edge ~metric_edge ~quality ~format =
  match Config.make ~max_edge ~metric_edge ~quality ~format with
  | Ok config -> config
  | Error err ->
      Alcotest.failf "the fixture configuration was rejected: %s"
        (Image_error.message err)

let fixture_config () =
  capture_config ~max_edge:900 ~metric_edge:100 ~quality:0.55
    ~format:Config.Webp

let stored_source () =
  Nopal_blob_web.Blob_store.store
    (Brr.Blob.of_jstr (Jstr.v "pretend this is a JPEG"))

let released_handle () =
  let handle = stored_source () in
  Nopal_blob_web.Blob_store.remove handle;
  handle

let blob_under handle =
  match Nopal_blob_web.Blob_store.lookup handle with
  | Some blob -> blob
  | None ->
      Alcotest.failf "the blob store holds nothing under the handle %s" handle

(* Outcomes are collected into a list rather than an option so a task that
   resolved twice reads differently from one that resolved once, and one that
   never resolved reads differently from both. The drain happens before the
   count is read, because both of the shim's asynchronous stages answer on a
   later turn. *)
let run_pipeline ~blob_id ~config =
  let outcomes = ref [] in
  Nopal_mvu.Task.run (Nopal_image_web.process ~blob_id ~config) (fun outcome ->
      outcomes := outcome :: !outcomes);
  flush ();
  match !outcomes with
  | [ outcome ] -> outcome
  | [] -> Alcotest.fail "the pipeline task resolved no outcome"
  | delivered ->
      Alcotest.failf "the pipeline task resolved %d times, expected one"
        (List.length delivered)

let processed = function
  | Ok info -> info
  | Error err ->
      Alcotest.failf "expected a processed image, got the failure: %s"
        (Processing.message err)

let failure_of = function
  | Error err -> err
  | Ok info ->
      Alcotest.failf "expected a failure, got a processed image under %s"
        info.Processing.blob_id

(* A bare [function] with one arm per constructor: a sixth constructor makes
   this a compile error here as well as in the library, so a new stage cannot
   ship with no case asserting what it reports. *)
let stage_of_error = function
  | Processing.Blob_not_found _ -> "blob lookup"
  | Processing.Decode_failed _ -> "decode"
  | Processing.Canvas_unavailable _ -> "canvas"
  | Processing.Pixel_read_failed _ -> "pixel read"
  | Processing.Encode_failed _ -> "encode"

let detail_of_error = function
  | Processing.Blob_not_found detail
  | Processing.Decode_failed detail
  | Processing.Canvas_unavailable detail
  | Processing.Pixel_read_failed detail
  | Processing.Encode_failed detail ->
      detail

module Dimensions = Nopal_image_web_internal.Dimensions
module Canvas_ffi = Nopal_image_web_internal.Canvas_ffi
module Once = Nopal_image_web_internal.Once

(* [Buffer] below is the pixel buffer, not the byte buffer of the standard
   library; the standard one is not used here. *)
open Nopal_image

(* Which of the two downscales was running. Both draw the same decoded image at
   a size of their own, and only the size and the purpose differ, so the pass is
   what a failure message needs to name. A variant rather than a string because
   the set is closed and a mistyped name would otherwise reach a reader as a
   sentence about a pass that does not exist. *)
type pass = Upload | Sharpness

let pass_name = function
  | Upload -> "upload"
  | Sharpness -> "sharpness"

(* Which part of the pipeline was running when the browser refused a call.

   A refusal arrives as an exception carrying a message written for a human: it
   differs between engines, it is localised, and it names no stage. So the arm
   a refusal is reported under is decided by what was running, never by reading
   what it said.

   Allocating a canvas, asking it for a drawing context and painting onto it
   are one stage rather than three: they are the same piece of canvas work, and
   the error type names the canvas rather than any single call. Questioning the
   decoded image itself belongs to the decode instead, because what refused
   there is the decoded image and not any canvas. *)
type stage = Decoding | Painting of pass | Encoding | Reading

(* Describes an exception for a human reader. A refusing browser call raises a
   [Jv.Error]; every other exception is described by the runtime, so this is
   total over the whole exception type. *)
let description_of_exn = function
  | Jv.Error err -> Jstr.to_string (Jv.Error.message err)
  | other -> Printexc.to_string other

(* The typed failure a refusal during [stage] is reported as. The browser's own
   words are carried through rather than replaced, so a developer reading the
   failure still sees what the platform said - but they decide nothing. *)
let error_of_exn stage exn =
  let description = description_of_exn exn in
  match stage with
  | Decoding ->
      Processing.Decode_failed
        (Printf.sprintf "the browser refused to decode the stored image: %s"
           description)
  | Painting pass ->
      Processing.Canvas_unavailable
        (Printf.sprintf
           "the browser refused the canvas work for the %s pass: %s"
           (pass_name pass) description)
  | Encoding ->
      Processing.Encode_failed
        (Printf.sprintf "the browser refused to encode the processed image: %s"
           description)
  | Reading ->
      Processing.Pixel_read_failed
        (Printf.sprintf "the browser refused to read the drawn pixels back: %s"
           description)

(* Runs [f], turning a refusal into the failure of the stage that was running
   rather than letting it escape. *)
let attempt ~stage f =
  match f () with
  | value -> Ok value
  | exception refusal -> Error (error_of_exn stage refusal)

(* Runs one region of the pipeline, resolving the region's own failure if the
   browser refuses inside it.

   Every region that runs outside the guard [process] installs is entered
   through here, including the two continuations a browser calls back on: the
   decoded image and the encoded blob both arrive on later turns of the event
   loop, so a refusal inside one of them is not caught by the guard around the
   task body. Unhandled, it would escape into the event loop and leave the task
   pending forever, which is the one thing an effect that can fail must never
   do. Delivering an outcome runs application code, so a region's [finish] is
   also where a raising delivery lands; the latches on both sides of it are what
   keep that from becoming a second outcome. *)
let run_stage ~finish ~stage f =
  match attempt ~stage f with
  | Ok () -> ()
  | Error err -> finish (Error err)

(* A detached canvas of a stated size with [bitmap] painted onto it at exactly
   that size, or the failure of an environment that cannot supply one. An
   environment with no drawing context reports its absence as a value, which is
   how the platform reports it; a refusal at any of the three calls is reported
   under the same stage. *)
let painted_canvas ~pass ~bitmap ~width ~height =
  Result.join
    (attempt ~stage:(Painting pass) (fun () ->
         let canvas = Canvas_ffi.create_canvas ~width ~height in
         match Canvas_ffi.context_2d canvas with
         | None ->
             Error
               (Processing.Canvas_unavailable
                  (Printf.sprintf
                     "the browser handed out no 2D drawing context for the %s \
                      pass"
                     (pass_name pass)))
         | Some context ->
             Canvas_ffi.draw context bitmap ~width ~height;
             Ok (canvas, context)))

(* Copies the packed RGBA bytes of a pixel read into the OCaml heap. This is the
   one point at which pixels come within reach of OCaml, which is why the
   pipeline runs it once and on the smaller of its two canvases. Each channel is
   written with [Bytes.set_uint8], which is total over the whole int range,
   rather than through a character conversion that raises outside 0 to 255. *)
let rgba_of_pixels pixels =
  let rgba = Bytes.create (Brr.Tarray.length pixels) in
  Brr.Tarray.iter
    (fun index channel -> Bytes.set_uint8 rgba index channel)
    pixels;
  rgba

(* The sharpness pass: draws [bitmap] down to its own long edge on a canvas of
   its own, reads those pixels back once, and scores them.

   It is a second canvas rather than a second measurement of the upload one
   because the two have different long edges, and drawing the metric at its own
   smaller size is what keeps the stored image's pixels off this boundary
   entirely. The buffer is built from the canvas's own dimensions, which is what
   the pixel read used, so the two describe the same rectangle by construction;
   a buffer the metric package rejects is reported against the stage that
   produced the bytes. *)
let measure ~bitmap ~src_width ~src_height ~metric_edge =
  let ( let* ) = Result.bind in
  let width, height =
    Dimensions.fit ~src_width ~src_height ~max_edge:metric_edge
  in
  let* canvas, context =
    painted_canvas ~pass:Sharpness ~bitmap ~width ~height
  in
  let* rgba =
    attempt ~stage:Reading (fun () ->
        rgba_of_pixels (Canvas_ffi.read_pixels context))
  in
  let* buffer =
    Result.map_error
      (fun err -> Processing.Pixel_read_failed (Image_error.message err))
      (Buffer.create
         ~width:(Canvas_ffi.canvas_width canvas)
         ~height:(Canvas_ffi.canvas_height canvas)
         ~rgba)
  in
  Ok (Sharpness.score buffer)

(* Everything after the image has been decoded: the upload downscale, the
   encode, the store, and the sharpness pass.

   Split out of [process] because in a browser it runs on a later turn of the
   event loop, outside the guard [process] installs, so it carries guards of
   its own. Every exit goes through [finish], which frees the decoded image
   before delivering, so the failing paths release it as well as the successful
   one - re-selecting a photo is expected user behaviour, and a decoded
   full-resolution image is the largest thing this pipeline holds. *)
let process_bitmap ~config ~bitmap ~finish =
  (* Asking the decoded image for its own dimensions is the decode's business,
     not any canvas's: no canvas exists yet, and what would refuse is the
     decoded image. It is a region of its own so that a refusal there is not
     attributed to a pass that never started. *)
  run_stage ~finish ~stage:Decoding (fun () ->
      let src_width = Canvas_ffi.bitmap_width bitmap in
      let src_height = Canvas_ffi.bitmap_height bitmap in
      let upload_width, upload_height =
        Dimensions.fit ~src_width ~src_height ~max_edge:(Config.max_edge config)
      in
      run_stage ~finish ~stage:(Painting Upload) (fun () ->
          match
            painted_canvas ~pass:Upload ~bitmap ~width:upload_width
              ~height:upload_height
          with
          | Error err -> finish (Error err)
          | Ok (upload_canvas, _upload_context) ->
              run_stage ~finish ~stage:Encoding (fun () ->
                  Canvas_ffi.encode upload_canvas
                    ~mime:(Config.format_to_mime (Config.format config))
                    ~quality:(Config.quality config)
                    (fun encoded ->
                      (* The encoder calls back on a later turn of the event
                         loop, so this whole continuation - both of its arms -
                         is a region of its own. *)
                      run_stage ~finish ~stage:Encoding (fun () ->
                          match encoded with
                          | Error message ->
                              finish (Error (Processing.Encode_failed message))
                          | Ok encoded -> (
                              (* The processed handle comes from the store,
                                 which is the only thing that issues one, and
                                 the encoded bytes stay on the JavaScript side
                                 behind it. The handle that was processed keeps
                                 its own entry. *)
                              let stored =
                                Nopal_blob_web.Blob_store.store encoded
                              in
                              match
                                measure ~bitmap ~src_width ~src_height
                                  ~metric_edge:(Config.metric_edge config)
                              with
                              | Error err -> finish (Error err)
                              | Ok sharpness ->
                                  (* Every reported number is measured off what
                                     was produced: the canvas the encoder ran on
                                     and the blob it produced, never the sizes
                                     the configuration asked for. *)
                                  finish
                                    (Ok
                                       {
                                         Processing.blob_id = stored;
                                         width =
                                           Canvas_ffi.canvas_width upload_canvas;
                                         height =
                                           Canvas_ffi.canvas_height
                                             upload_canvas;
                                         byte_size =
                                           Brr.Blob.byte_length encoded;
                                         sharpness;
                                       })))))))

(* The store is asked twice on purpose. [object_url] answers [None] both for a
   handle it holds nothing under and for an environment that minted no URL, and
   those are different failures with different owners - a stale handle belongs
   to the application, an absent minting capability to the platform. [lookup] is
   what separates them, and it reads the same registry [object_url] consults, so
   the two answers cannot disagree about whether the image is there.

   [guard_once] rather than a bare [Task.return] of the match: everything here
   runs synchronously inside [update], and delivering an outcome runs the
   application's own dispatch, which is arbitrary code. A raise out of that
   dispatch leaves the body and lands in the exception handler the combinator
   installs - a handler closing over a resolver of its own. Reached through a
   resolver latched before it was installed, the raise is absorbed and the
   caller keeps the outcome it already has; reached through an unlatched one,
   the handler answers a second time and blames the browser for an application
   bug.

   Neither call in the body reports a refusal as an exception: the store answers
   an unknown handle and a platform that mints nothing with the same [None], a
   platform that refuses the call outright included, and telling those apart is
   what the paragraph above is about. So [on_exn] describes nothing this body
   can produce today. It names the mint because that is the only call here that
   reaches the platform at all, and it stands against a store that stopped being
   total rather than against a browser that declined. *)
let preview_url ~blob_id =
  Nopal_mvu.Task.guard_once
    ~on_exn:(fun refusal ->
      Preview.Url_unavailable
        (Printf.sprintf
           "the browser refused to mint a displayable URL for the stored image \
            %s: %s"
           blob_id
           (description_of_exn refusal)))
    (fun resolve ->
      match Nopal_blob_web.Blob_store.lookup blob_id with
      | None ->
          resolve
            (Error
               (Preview.Blob_not_found
                  (Printf.sprintf
                     "the blob store holds no image under the handle %s" blob_id)))
      | Some _stored -> (
          match Nopal_blob_web.Blob_store.object_url blob_id with
          | Some url -> resolve (Ok url)
          | None ->
              resolve
                (Error
                   (Preview.Url_unavailable
                      (Printf.sprintf
                         "this browser minted no displayable URL for the \
                          stored image %s"
                         blob_id)))))

(* Releasing cannot fail, which is the seam's contract as well as the store's:
   the platform is specified to ignore a string that names no live URL, and the
   store answers an environment with no revocation capability by doing nothing.
   So there is no outcome to report and nothing to guard. *)
let revoke_preview_url ~url = Nopal_blob_web.Blob_store.revoke_url url

let process ~blob_id ~config =
  (* [guard_once] rather than [guard]: the handle lookup below delivers
     synchronously, inside the guard's own [try], and delivering runs the
     application's dispatch. A guard that did not deduplicate would catch a
     raise from that dispatch and answer it with a second outcome, blaming the
     browser for an application bug. The guard itself covers what runs
     synchronously: resolving the handle, which the blob store answers with an
     absence rather than an exception, and starting the decode, which a browser
     without an image decoder refuses outright. Both belong to the decode.
     Everything past the decode runs on a later turn of the event loop and
     carries its own regions. *)
  Nopal_mvu.Task.guard_once ~on_exn:(error_of_exn Decoding) (fun resolve ->
      match Nopal_blob_web.Blob_store.lookup blob_id with
      | None ->
          resolve
            (Error
               (Processing.Blob_not_found
                  (Printf.sprintf
                     "the blob store holds no image under the handle %s" blob_id)))
      | Some source ->
          Canvas_ffi.decode source (fun decoded ->
              run_stage ~finish:resolve ~stage:Decoding (fun () ->
                  match decoded with
                  | Error message ->
                      resolve (Error (Processing.Decode_failed message))
                  | Ok bitmap ->
                      (* Freeing the decoded image and delivering the outcome
                         are one action, and it happens once. Both halves are
                         reachable twice: a delivery that raises is caught by
                         the region around it, which answers by finishing again.
                         Latching the delivery alone would still free the image
                         twice and leave a release count that the code does not
                         actually guarantee. *)
                      let finish =
                        Once.wrap (fun outcome ->
                            Canvas_ffi.release bitmap;
                            resolve outcome)
                      in
                      process_bitmap ~config ~bitmap ~finish)))

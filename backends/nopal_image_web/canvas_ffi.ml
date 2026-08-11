(* Every type here is the JavaScript object itself. The [.mli] keeps them
   abstract so a caller cannot hand one binding another's object — a context
   where a canvas belongs would otherwise typecheck and fail at run time. *)
type bitmap = Jv.t
type canvas = Jv.t
type context = Jv.t

(* Every global below is read inside the call that needs it rather than once at
   module initialisation: an environment missing one would otherwise throw while
   the module is being linked, taking the whole bundle down instead of failing
   the single call that wanted the capability. *)

(* Whether [value] is a JavaScript string. [Jv.to_string] is an unchecked cast,
   so a property that merely exists is not enough to justify one: an object
   carrying a numeric or nested [message] would otherwise produce a value typed
   [string] that is not one, and every later [String.length] on it would be
   reading a shape the runtime never laid out. *)
let is_string value = String.equal (Jstr.to_string (Jv.typeof value)) "string"

(* Describes a rejected promise for a human reader. A rejection is not
   guaranteed to be an [Error], and neither is its [message]: the property is
   read only when it is a string, and [String] is total over every other
   shape. *)
let message_of_rejection err =
  match Jv.is_none err with
  | true -> "the browser rejected the call without stating a reason"
  | false -> (
      match Jv.find err "message" with
      | Some message when is_string message -> Jv.to_string message
      | Some _
      | None ->
          Jv.to_string (Jv.apply (Jv.get Jv.global "String") [| err |]))

let decode blob k =
  let decoded =
    Jv.apply (Jv.get Jv.global "createImageBitmap") [| Brr.Blob.to_jv blob |]
  in
  (* A single [then'] hop directly on the decode promise, not [Fut.of_promise]
     followed by [Fut.await], whose second hop is microtask deferred regardless.
     One hop settles as soon as the promise does, which lets a test shim settle
     it synchronously through a thenable; against a real browser it is an
     ordinary async resolution. Same reasoning as the Tauri IPC bridge. Both
     continuations call [k], so a rejected decode reports instead of leaving the
     caller waiting forever. *)
  ignore
    (Jv.Promise.then' decoded
       (fun decoded_bitmap ->
         (* The fulfilment value of createImageBitmap is specified to be an
            ImageBitmap, which is what [bitmap] denotes. *)
         k (Ok decoded_bitmap);
         Jv.Promise.resolve Jv.null)
       (fun err ->
         k (Error (message_of_rejection err));
         Jv.Promise.resolve Jv.null))

let bitmap_width bitmap = Jv.to_int (Jv.get bitmap "width")
let bitmap_height bitmap = Jv.to_int (Jv.get bitmap "height")
let release bitmap = ignore (Jv.call bitmap "close" [||])

let create_canvas ~width ~height =
  let canvas =
    Jv.call
      (Jv.get Jv.global "document")
      "createElement"
      [| Jv.of_string "canvas" |]
  in
  (* Both writes are required: a fresh canvas carries the platform's own default
     backing store, which is unrelated to the size asked for here. *)
  Jv.set canvas "width" (Jv.of_int width);
  Jv.set canvas "height" (Jv.of_int height);
  canvas

let canvas_width canvas = Jv.to_int (Jv.get canvas "width")
let canvas_height canvas = Jv.to_int (Jv.get canvas "height")

let context_2d canvas =
  let context = Jv.call canvas "getContext" [| Jv.of_string "2d" |] in
  match Jv.is_none context with
  | true -> None
  | false -> Some context

let draw context bitmap ~width ~height =
  ignore
    (Jv.call context "drawImage"
       [| bitmap; Jv.of_int 0; Jv.of_int 0; Jv.of_int width; Jv.of_int height |])

let encode canvas ~mime ~quality k =
  let on_encoded =
    Jv.callback ~arity:1 (fun encoded ->
        match Jv.is_none encoded with
        | true -> k (Error "the canvas encoder produced no image")
        | false ->
            (* Brr.Blob.of_jv: safe cast — toBlob is specified to call back with
               a Blob or with null, and null is the branch above. *)
            k (Ok (Brr.Blob.of_jv encoded)))
  in
  ignore
    (Jv.call canvas "toBlob"
       [| on_encoded; Jv.of_string mime; Jv.of_float quality |])

let read_pixels context =
  let canvas = Jv.get context "canvas" in
  let image_data =
    Jv.call context "getImageData"
      [|
        Jv.of_int 0; Jv.of_int 0; Jv.get canvas "width"; Jv.get canvas "height";
      |]
  in
  (* Brr.Tarray.of_jv: safe cast — the data property of an ImageData is
     specified to be a Uint8ClampedArray, which is what [uint8_clamped]
     denotes. *)
  Brr.Tarray.of_jv (Jv.get image_data "data")

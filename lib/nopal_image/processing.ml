type error =
  | Blob_not_found of string
  | Decode_failed of string
  | Canvas_unavailable of string
  | Pixel_read_failed of string
  | Encode_failed of string

let message = function
  | Blob_not_found detail -> Printf.sprintf "Image blob not found: %s" detail
  | Decode_failed detail -> Printf.sprintf "Image decode failed: %s" detail
  | Canvas_unavailable detail ->
      Printf.sprintf "Image canvas unavailable: %s" detail
  | Pixel_read_failed detail ->
      Printf.sprintf "Image pixel read failed: %s" detail
  | Encode_failed detail -> Printf.sprintf "Image encode failed: %s" detail

type result_info = {
  blob_id : string;
  width : int;
  height : int;
  byte_size : int;
  sharpness : float;
}

type backend = {
  process :
    blob_id:string ->
    config:Config.t ->
    (result_info, error) result Nopal_mvu.Task.t;
}

let default_backend =
  {
    process =
      (fun ~blob_id:_ ~config:_ ->
        Nopal_mvu.Task.return
          (Error
             (Canvas_unavailable
                "no image processing backend was registered for this platform")));
  }

(* Mutable: backend registration lets a platform implementation (nopal_image_web
   is the first) be injected at startup, so application code names the seam and
   never a platform package. *)
let current_backend = ref default_backend
let register_backend b = current_backend := b

let process ~blob_id ~config on_result =
  Nopal_mvu.Cmd.task
    (Nopal_mvu.Task.map on_result (!current_backend.process ~blob_id ~config))

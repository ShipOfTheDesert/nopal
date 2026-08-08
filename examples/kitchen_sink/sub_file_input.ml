open Nopal_element

type upload_state =
  | Not_uploaded
  | Uploading
  | Upload_succeeded of int
  | Upload_failed of Nopal_http.error

type model = { selection : Element.file_info list; upload : upload_state }

type msg =
  | Selected of Element.file_info list
  | Upload_clicked
  | Upload_dangling_clicked
  | Upload_result of Nopal_http.outcome

(* The picker has no label of its own to slugify, so the accessible name and the
   test anchor are both supplied here at the call site. *)
let picker_label = "Receipt image"
let picker_field = "receipt-image"
let upload_field = "receipt-upload"
let dangling_field = "receipt-upload-dangling"
let upload_url = "/api/receipt-upload"
let caption_field = "caption"
let caption_value = "kitchen sink receipt"
let file_part_name = "receipt"

(* A handle the blob store never issued. Every handle the picker hands over
   resolves, so naming one that does not is the only way to reach the
   unresolvable-handle failure from the UI. This is the single place a blob
   handle is written as a literal, and it is deliberately dangling. *)
let dangling_handle = "no-such-receipt-blob"

(* The caption travels with every upload, including the dangling one: a body
   whose string field is perfectly good and whose file part cannot be resolved
   is exactly the case that must send nothing at all rather than a partial
   body. *)
let upload_parts ~blob_id ~filename ~mime =
  [
    Nopal_http.Field (caption_field, caption_value);
    Nopal_http.File { name = file_part_name; blob_id; filename; mime };
  ]

let post_upload parts =
  Nopal_http.post ~body:(Nopal_http.Multipart parts) upload_url (fun outcome ->
      Upload_result outcome)

let init () = ({ selection = []; upload = Not_uploaded }, Nopal_mvu.Cmd.none)

let update model msg =
  match msg with
  | Selected selection ->
      ({ selection; upload = Not_uploaded }, Nopal_mvu.Cmd.none)
  | Upload_clicked -> (
      match model.selection with
      | [] -> (model, Nopal_mvu.Cmd.none)
      (* Both overrides are declared rather than deferred, so the name and type
         the server is told about are the ones the readout above shows. The MIME
         is the user agent's report passed straight through: a declaration
         attached to the part, never a claim about the bytes. *)
      | (file : Element.file_info) :: _ ->
          ( { model with upload = Uploading },
            post_upload
              (upload_parts ~blob_id:file.blob_id ~filename:(Some file.name)
                 ~mime:(Some file.mime)) ))
  | Upload_dangling_clicked ->
      ( { model with upload = Uploading },
        post_upload
          (upload_parts ~blob_id:dangling_handle ~filename:None ~mime:None) )
  | Upload_result (Ok { Nopal_http.status; _ }) ->
      ({ model with upload = Upload_succeeded status }, Nopal_mvu.Cmd.none)
  | Upload_result (Error e) ->
      ({ model with upload = Upload_failed e }, Nopal_mvu.Cmd.none)

let subscriptions _model = Nopal_mvu.Sub.none

let describe (f : Element.file_info) =
  Printf.sprintf "%s | %s | %d bytes" f.name f.mime f.size

let upload_status_text = function
  | Not_uploaded -> "No upload yet"
  | Uploading -> "Uploading\u{2026}"
  | Upload_succeeded status -> Printf.sprintf "Uploaded (HTTP %d)" status
  | Upload_failed e -> Nopal_http.message e

let view _vp model =
  let readout =
    match model.selection with
    | [] -> [ Element.text "No file selected" ]
    | files -> List.map (fun f -> Element.text (describe f)) files
  in
  Element.column
    [
      Element.text picker_label;
      Element.file_input
        ~attrs:[ ("data-field", picker_field); ("aria-label", picker_label) ]
        ~accept:[ "image/*" ] ~capture:Element.Environment ~multiple:false
        ~on_change:(fun files -> Selected files)
        ();
      Element.column ~attrs:[ ("data-testid", "file-input-selection") ] readout;
      Element.button
        ~attrs:[ ("data-field", upload_field) ]
        ~on_click:Upload_clicked
        (Element.text "Upload receipt");
      Element.button
        ~attrs:[ ("data-field", dangling_field) ]
        ~on_click:Upload_dangling_clicked
        (Element.text "Upload a released handle");
      Element.column
        ~attrs:[ ("data-testid", "file-input-upload-status") ]
        [ Element.text (upload_status_text model.upload) ];
    ]

(* The blob handle is deliberately absent: it is issued fresh on every selection
   and means nothing outside the page session, so asserting on it would pin a
   value no test can predict. Every field is terminated with ';' so a substring
   assertion is bounded on both sides. *)
let serialize_file (f : Element.file_info) =
  Printf.sprintf "file_name=%S; file_mime=%S; file_size=%d;" f.name f.mime
    f.size

(* Each failure gets its own tag so a browser spec reading these by substring
   cannot mistake an unresolvable handle for a network failure — the two have
   different remedies and the telemetry has to say which one happened. *)
let error_tag = function
  | Nopal_http.Network_error _ -> "error:network"
  | Nopal_http.Timeout -> "error:timeout"
  | Nopal_http.Invalid_blob handle ->
      Printf.sprintf "error:invalid_blob:%S" handle

let upload_tag = function
  | Not_uploaded -> "idle"
  | Uploading -> "uploading"
  | Upload_succeeded status -> Printf.sprintf "ok:%d" status
  | Upload_failed e -> error_tag e

let outcome_tag = function
  | Ok { Nopal_http.status; _ } -> Printf.sprintf "ok:%d" status
  | Error e -> error_tag e

let serialize_model model =
  String.concat " "
    (Printf.sprintf "file_count=%d;" (List.length model.selection)
     :: List.map serialize_file model.selection
    @ [ Printf.sprintf "upload=%s;" (upload_tag model.upload) ])

let serialize_msg = function
  | Selected files -> Printf.sprintf "FilesSelected:%d;" (List.length files)
  | Upload_clicked -> "UploadClicked;"
  | Upload_dangling_clicked -> "UploadDanglingClicked;"
  | Upload_result outcome ->
      Printf.sprintf "UploadResult:%s;" (outcome_tag outcome)

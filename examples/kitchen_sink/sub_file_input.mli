(** File input kitchen sink subapp.

    Demonstrates the native file picker: an image-restricted, rear-camera
    preferring single-file picker whose current selection is listed as metadata
    (name, reported MIME type, byte size), plus the upload leg that sends the
    picked file as one part of a [multipart/form-data] body.

    The picker hands over an opaque store handle per file, never bytes. Picking
    again supersedes the previous selection in this model but does not release
    the handle it held — a stored blob lives for the page session and only an
    explicit call by the application releases it. *)

(** How the most recent upload attempt ended. Distinct from the selection: a
    file stays picked after its upload succeeds or fails. *)
type upload_state =
  | Not_uploaded  (** Nothing has been uploaded since the last selection. *)
  | Uploading  (** A request is in flight. *)
  | Upload_succeeded of int
      (** The server answered; carries its status code. *)
  | Upload_failed of Nopal_http.error
      (** The request failed. The typed error is kept rather than its rendering
          so a dangling handle stays distinguishable from a network failure
          after the fact. *)

type model = {
  selection : Nopal_element.Element.file_info list;
      (** The files the user currently has picked. Empty before the first
          selection and again after the picker is cleared. *)
  upload : upload_state;  (** Outcome of the most recent upload attempt. *)
}
(** The subapp model. [selection] is a list rather than an option because the
    handler always receives the whole selection, even though this demo picks one
    file. *)

(** The subapp's messages. *)
type msg =
  | Selected of Nopal_element.Element.file_info list
      (** The user changed the selection. Carries [[]] when the picker was
          cleared. *)
  | Upload_clicked
      (** Upload the first picked file alongside a plain string field. A no-op
          when nothing is selected — there is no file to name. *)
  | Upload_dangling_clicked
      (** Upload a handle the blob store never issued, so the [Invalid_blob]
          failure is reachable from the UI. *)
  | Upload_result of Nopal_http.outcome  (** The upload request completed. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** Initial model: nothing selected, nothing uploaded. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** [Selected files] replaces the whole selection, so clearing the picker
    empties the readout rather than leaving it stale, and resets the upload
    state so a previous outcome is not shown beside a new file. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** Renders a labelled file picker restricted to images, a readout of the
    current selection's metadata, the two upload controls, and the upload status
    line. *)

val subscriptions : model -> msg Nopal_mvu.Sub.t
(** Subscriptions. Currently none. *)

val serialize_model : model -> string
(** Telemetry serializer. Emits each field terminated with a trailing [;] so a
    substring assertion ([file_size=13;]) cannot prefix-alias a larger value.
    Every upload failure carries its own tag, so [upload=error:invalid_blob:…;]
    is never satisfiable by a network failure. *)

val serialize_msg : msg -> string
(** Telemetry serializer for the section's messages, also [;]-terminated. Lives
    here rather than at the entry point so the message and model fragments stay
    described by one module. *)

(** File input kitchen sink subapp.

    Demonstrates the native file picker: an image-restricted, rear-camera
    preferring single-file picker whose current selection is listed as metadata
    (name, reported MIME type, byte size).

    The picker hands over an opaque store handle per file, never bytes. Picking
    again supersedes the previous selection in this model but does not release
    the handle it held — a stored blob lives for the page session and only an
    explicit call by the application releases it. *)

type model = {
  selection : Nopal_element.Element.file_info list;
      (** The files the user currently has picked. Empty before the first
          selection and again after the picker is cleared. *)
}
(** The subapp model. A list rather than an option because the handler always
    receives the whole selection, even though this demo picks one file. *)

(** The subapp's only message. *)
type msg =
  | Selected of Nopal_element.Element.file_info list
      (** The user changed the selection. Carries [[]] when the picker was
          cleared. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** Initial model: nothing selected. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** [Selected files] replaces the whole selection, so clearing the picker
    empties the readout rather than leaving it stale. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** Renders a labelled file picker restricted to images, plus a readout of the
    current selection's metadata. *)

val subscriptions : model -> msg Nopal_mvu.Sub.t
(** Subscriptions. Currently none. *)

val serialize_model : model -> string
(** Telemetry serializer. Emits each field terminated with a trailing [;] so a
    substring assertion ([file_size=13;]) cannot prefix-alias a larger value. *)

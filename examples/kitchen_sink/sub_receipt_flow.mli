(** Receipt capture kitchen sink subapp.

    Demonstrates the on-device image pipeline end to end: an image-restricted,
    rear-camera preferring single-file picker hands over a stored handle, the
    registered image backend turns it into an upload-ready one, and the section
    reads out what came back — the stored dimensions, the encoded byte length,
    and the focus score measured over the processed pixels.

    The capture parameters are named here rather than taken from the library
    preset, so the metric edge that makes two scores comparable is visible
    beside the picker that produces them. Nothing in this module names a
    platform type: the backend it dispatches to is registered by the example's
    entry point. *)

(** How far the accepted photo has got towards the server. It lives inside the
    stage that holds a measured photo, so a receipt cannot be reported in flight
    by a section that has measured nothing. *)
type upload =
  | Not_started  (** The photo has been measured but not accepted. *)
  | In_flight  (** A request is out and has not answered. *)
  | Stored of int
      (** The server accepted the receipt, with the status it answered. *)
  | Rejected of int
      (** The request completed and the server refused it, with the status it
          answered. A completed request is not a stored receipt. *)
  | Undelivered of Nopal_http.error
      (** The request never completed, so nothing was stored. The typed error is
          kept rather than its rendering so the kind of failure stays
          distinguishable after the fact. *)

(** How far the current photo has got through the pipeline. Exactly one stage
    holds at a time, only {!update} moves between them, and a measurement moves
    it only when the picker still names the photo that measurement was taken
    for. A readout can therefore never show a result beside a picker that has
    since been cleared, nor beside a picker naming a different photo. *)
type stage =
  | Idle  (** Nothing picked, or the picker was cleared. *)
  | Working  (** A processing pass is in flight for the picked handle. *)
  | Ready of { info : Nopal_image.Processing.result_info; upload : upload }
      (** The pass completed. Carries what was actually stored, never the
          parameters it was asked for, and how far the upload of it has got. *)
  | Failed of Nopal_image.Processing.error
      (** The pass failed. The typed error is kept rather than its rendering so
          the stage that failed stays distinguishable after the fact. *)

type model = {
  selection : Nopal_element.Element.file_info option;
      (** The photo the user currently has picked. [None] before the first
          selection and again after the picker is cleared. *)
  stage : stage;  (** How far that photo has got. *)
  previous_score : float option;
      (** Focus score of the last photo measured before the one currently held,
          or [None] until a second photo is taken. It is what a replacement is
          judged against, so it outlives the readout of the photo it came from.
      *)
  note : string;
      (** What the user typed about this receipt. It travels with the upload as
          a plain string field and describes the receipt rather than the photo,
          so replacing the photo leaves it standing. *)
}
(** The subapp model. A single photo rather than a list because the picker is
    opened in single-file mode. *)

(** The subapp's messages. *)
type msg =
  | Selected of Nopal_element.Element.file_info list
      (** The user changed the selection. Carries [[]] when the picker was
          cleared. *)
  | Processed of {
      source : string;
          (** The picked handle the pass was started for. Carried so a result
              can be matched back to the photo it was measured for: passes over
              different files can finish in either order, and a result that
              names a photo the section has moved off describes nothing on
              screen. *)
      result :
        ( Nopal_image.Processing.result_info,
          Nopal_image.Processing.error )
        result;
    }  (** A processing pass finished. *)
  | Reshoot_clicked
      (** The user rejected the measured photo and wants to take another. *)
  | Note_changed of string  (** The user edited the note. *)
  | Accept_clicked  (** The user kept the measured photo and is sending it. *)
  | Upload_finished of Nopal_http.outcome  (** An upload request answered. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** Initial model: nothing picked, nothing processed. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** [Selected] with a photo replaces the selection and asks the registered image
    backend to process it, so the processing command is built here rather than
    at module initialisation, which runs before any backend is registered.
    [Selected] with an empty list returns the section to its initial stage, so a
    cleared picker cannot be shown beside a stale readout. [Reshoot_clicked]
    does the same for a photo the user rejected, so the next one is taken
    against an empty readout rather than beside the one it replaces.

    [Processed] is recorded only against the photo it names: its {!field-source}
    is checked against the handle the picker holds, and only while that photo is
    still the section's to describe - not once the picker has been cleared, and
    not once the receipt has been sent. A pass answering for a photo that has
    since been replaced, or for one the user cancelled, is discarded and leaves
    the model untouched. Without that check a pass still out when the picker is
    cleared would put a readout and a working upload control under a picker
    holding nothing, and two passes finishing out of order would leave the
    section describing the earlier photo while naming the later one.

    Every arm that moves off a measured photo keeps that photo's score as
    {!field-previous_score}, the re-shoot included: clearing the readout of a
    rejected photo is what the user asked for, but forgetting what it scored
    would leave its replacement with nothing to be judged against.

    [Accept_clicked] sends the handle the processing pass produced, never the
    one the picker produced, beside the note as a multipart post to a relative
    stub endpoint. It starts a request only from the one stage that offers the
    control, so a receipt cannot be sent twice. [Upload_finished] records the
    outcome under that same photo, and only while a request for it is out: a
    reply for a photo the section has already moved on from belongs to a receipt
    that is no longer on screen and is not written over the one that is. Every
    reply, including one from a server that refused the receipt, lands in a
    state the section renders, so no outcome leaves it reporting a request that
    is still out. The request carries a deadline for the case where no reply
    comes at all, which is the one such state a reply cannot end. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** Renders a labelled picker - the label is on screen as well as in the
    accessibility tree, since a file input carries no label of its own - a note
    field, the readout of what the processing pass produced, and, once a photo
    has been measured, the one way forward the focus score earns it: keeping the
    photo when the score reaches this section's own threshold and taking another
    when it does not. That threshold is calibration for this demo alone and the
    section says so on screen, because the image library defines no notion of a
    good enough score and offers none. A second readout says how the upload of
    an accepted photo went, so a refusal or a failure is visible on screen and
    not only in the telemetry.

    Spacing is typed layout from [Nopal_style]; this module writes no CSS
    string. The section heading, and the wrapper a browser test scopes itself
    to, are supplied by the kitchen sink at the call site, so both are inside
    the scanned subtree rather than around it. *)

val subscriptions : model -> msg Nopal_mvu.Sub.t
(** Subscriptions. Currently none. *)

val serialize_model : model -> string
(** Telemetry serializer. Emits each field terminated with a trailing [;] so a
    substring assertion ([width=768;]) cannot prefix-alias a larger value. A
    failed pass names the stage that failed ([processing=failed:decode_failed;])
    rather than reporting a bare failure, so an assertion aimed at one kind of
    failure is not satisfiable by any of the others. The focus score is
    deliberately absent: float rendering is not a stable assertion surface, so
    what the score decided ([sharpness_ok=true;]) is emitted rather than the
    score. That verdict appears only once a pass has measured something, so a
    fragment claiming one is never satisfiable by a section that has measured
    nothing.

    The comparison against the photo before this one is emitted the same way and
    for the same reason: [sharper_than_previous=true;] rather than the pair of
    scores it was decided from. It appears from the second photo onwards and is
    absent for the first, which has nothing behind it to be compared against.

    Where the upload stands is emitted in every stage as [upload=idle;] until
    one is started, then [upload=uploading;] and one tag per way it can end -
    [upload=ok:201;], [upload=rejected:404;] and one per transport failure kind.
    This section states the example's [upload=] vocabulary; the file-input
    section's is the older and narrower one, and this one supersedes it rather
    than matching it. The two differ in two named places: that section has no
    rejection arm, so a server refusing an upload there is reported as
    [upload=ok:404;], and its [Invalid_blob] tag carries the handle where this
    one does not. Migrating it would change assertions in a shipped browser
    spec, so it belongs to whoever next touches that section.

    The [upload=] vocabulary is deliberately not the one [processing=] uses: a
    processing failure names the stage of a pipeline this repo wrote, while an
    upload failure names a category of HTTP outcome, and a shared shape would
    make one of them describe something it does not. *)

val serialize_msg : msg -> string
(** Telemetry serializer for the section's messages, also [;]-terminated. Lives
    here rather than at the entry point so the message and model fragments stay
    described by one module. *)

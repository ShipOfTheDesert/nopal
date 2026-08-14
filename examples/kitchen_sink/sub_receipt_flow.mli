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
  | Ready of {
      info : Nopal_image.Processing.result_info;
      source_byte_size : int;
      upload : upload;
    }
      (** The pass completed. Carries what was actually stored, never the
          parameters it was asked for, and how far the upload of it has got.

          [source_byte_size] is the length of the file the pass consumed,
          recorded on the stage that measured it rather than read back off
          {!field-selection} when something wants it. The selection and the
          stage do move together in every transition, but nothing in the types
          says so, so a reader wanting the two lengths beside each other would
          otherwise have to open an option the compiler cannot see is full.
          Carried here, a section holding no measured photo cannot report a size
          comparison at all. *)
  | Failed of Nopal_image.Processing.error
      (** The pass failed. The typed error is kept rather than its rendering so
          the stage that failed stays distinguishable after the fact. *)

(** Which of the two pictures a delivered URL belongs to. Named rather than a
    boolean because the two are shown under different headings, so a URL put in
    the wrong slot would present the photo that is about to be sent as the one
    that was picked. *)
type preview_slot =
  | Original_photo  (** the photo the user picked, before any processing *)
  | Processed_photo  (** the photo as it will be uploaded *)

(** How far the before-and-after pair has got. One variant rather than a pair of
    [string option]s, so a section holding half a pair cannot be read as one
    holding none, and only {!update} moves between the arms.

    Every arm names the request it belongs to, the one holding nothing included.
    A URL is delivered a turn or more after it was asked for, so a delivery can
    arrive for a pair the section has already replaced, and the generation it
    names is what tells that delivery from a current one. The count only ever
    goes up: an arm that let go of a pair and then started counting again would
    number its next request the same as one still in flight for the pair it let
    go, and that delivery would be taken for a current one.

    The arm names are prefixed because a processing pass has a [Ready] of its
    own; two constructors of that name in one module would leave a match on
    either readable only by knowing which type it was written against. *)
type previews =
  | No_previews of { generation : int }
      (** Nothing has been asked for, or the pair that was held has been let go
          and its URLs released. Carries the number of the last request so the
          next one cannot repeat it. *)
  | Preview_pending of {
      generation : int;
      original : string option;
      processed : string option;
    }
      (** URLs have been asked for and at most one has arrived. A pair is not a
          pair until both slots hold one. *)
  | Preview_ready of { generation : int; original : string; processed : string }
      (** Both URLs arrived and the pair can be shown. Each pins the image it
          names until it is released. *)
  | Preview_failed of { generation : int; error : Nopal_image.Preview.error }
      (** A URL could not be minted. It is its own arm rather than a processing
          failure: a picture that cannot be shown says nothing about the photo
          that was measured, scaled and encoded. The typed error is kept rather
          than its rendering, for the reason [stage]'s own [Failed] keeps one: a
          failure turned into a string at the moment it happened can only ever
          be shown the one way it was turned into, and the tag
          {!serialize_model} reports is computed where every other tag is.

          It names the FIRST failure and only that one. Both pictures are asked
          for at once, so both can be refused, and for different reasons - a
          handle nothing is stored under for one, a platform that mints no URL
          for the other. The refusal that arrives first is the one that moves
          the arm; the second arrives at a pair that has already failed and is
          dropped. So a pair whose halves fail differently reports one of the
          two reasons rather than both.

          The arm holds no URL, because the two pictures are shown together and
          neither is shown once one of them has failed. Whatever the pair it
          replaces had already been handed is therefore released as the arm is
          entered, this being the last point at which that half is reachable. *)

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
  previews : previews;
      (** The displayable pair for the photo currently held: what was picked
          beside what will be sent. *)
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
  | Preview_delivered of {
      generation : int;
          (** The request this delivery answers. A pair asked for before the one
              the section now holds is answered under an earlier generation, so
              a URL that arrives too late is recognisable as such rather than
              being written over the pair on screen. *)
      slot : preview_slot;  (** Which of the two pictures it names. *)
      result : (string, Nopal_image.Preview.error) result;
    }
      (** A displayable URL was minted, or could not be. Both pictures are asked
          for at once, so two of these answer one request. *)

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
    comes at all, which is the one such state a reply cannot end.

    A pass that succeeded also asks the registered preview backend for a
    displayable URL naming each of the two photos - the one that was picked and
    the one that will be sent - so those commands are likewise built here rather
    than at module initialisation. The pair is reported ready only once both
    URLs have arrived, and a [Preview_delivered] naming a generation other than
    the one currently held answers a request the section has moved off, so it is
    not written over the pair on screen.

    A [Preview_delivered] that carries no URL ends the pair rather than leaving
    it waiting, since the two pictures are shown together and one that cannot be
    minted is a pair that cannot be shown. It is recorded in the preview
    vocabulary alone and leaves the stage, the score, the verdict and the upload
    exactly as the pass left them: the photo it names had already been decoded,
    scaled, re-encoded and measured before anything asked to show it, so a
    picture that failed is not a photo that failed to process. The half of the
    pair that had already arrived, if any, is released as the failure is
    recorded.

    A URL keeps the picture it names alive until it is released, and nothing
    else releases one - no runtime, no unmount, no collector - so every arm that
    lets go of a pair releases the URLs it was holding, and it does so before
    asking for the pair that replaces them. That covers replacing the photo,
    re-shooting it, clearing the picker, and a second pass answering for a photo
    still picked - whether that second pass succeeded or failed. A pass that
    failed is the measurement going, and the lengths under the two photographs
    are read off that measurement, so a pair cannot outlive it; a failed stage
    also offers no re-shoot control, so a pair left standing there would be
    pinned until the user found the picker again. A URL that arrives for a
    request the section has moved off is released as it arrives for the same
    reason: nothing is going to show it, and holding it would pin its photo for
    the rest of the session. *)

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

    Between the readout and those two controls sit the two photographs
    themselves: the receipt as it was taken beside the receipt as it will be
    uploaded, each under a heading naming which of the two it is and each
    carrying its own description for a reader who cannot see it. They are what a
    person decides on, so they are shown before the control that acts on the
    decision. Both are drawn to one width with their heights left to follow, so
    a preview keeps the proportions the pass produced rather than the
    proportions of a box.

    Under each photograph is the length of the picture that half shows, and
    under the processed one what that came to as a share of the picked file, so
    the payload change is read off the same pair as the fidelity change. A
    re-encode does not always shrink - an already-small photo, or one whose long
    edge is under the stored edge, comes back bigger - and the two directions
    are worded apart, so a pass that grew reads as one rather than as a
    reduction that went wrong. The share is rendered here and nowhere else: it
    is a person reading a screen, not a value {!serialize_model} could put on
    the wire.

    The pair is rendered only once both URLs have arrived, and only while a
    measured photo is what the section is holding: the lengths under it come off
    that measurement, so a pair outliving the pass that produced it has nothing
    to label its halves with. A section still waiting holds at most one of them,
    and one photograph on its own under whichever heading arrived first is not a
    before and an after; a pair that could not be minted shows nothing for the
    same reason, and where it stands is readable in {!serialize_model} instead.
    Nothing here is offered for a photo that failed to process, which is a
    different matter and already has its own readout.

    The layout of the pair depends on the viewport: side by side where there is
    room for two photographs, stacked where there is room for one, with anything
    between the two treated as the narrower case. Both layouts show both
    photographs - a reflow that dropped one would defeat the comparison the pair
    exists for.

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

    What the pass cost in bytes is emitted as two integers and never as the
    ratio between them: [byte_size=214007;] is the length the pass produced and
    [original_byte_size=2097152;] the length of the file it consumed. A share is
    a float by another name, and its rendering would depend on a rounding rule a
    reader of these fragments would have to reimplement in order to assert on
    it, while the two integers are exact and answer every question the share
    does. Both appear only once a pass has produced a length, so neither is
    satisfiable by a section that has measured nothing.

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
    make one of them describe something it does not.

    Where the before-and-after pair stands is emitted the same way and in a
    third vocabulary, for the same reason: [previews=none;] until a pass has
    succeeded, then [previews=pending;] while the URLs are out and
    [previews=ready;] once both have arrived. A pair that could not be minted is
    reported as [previews=failed:blob_not_found;] and one tag per other way the
    minting can fail, so an assertion aimed at one reason is not satisfiable by
    another - and, being its own vocabulary, never by a processing failure
    carrying the same reason. The URLs themselves never appear - they are minted
    at run time, so they are not values a spec could name in advance. *)

val serialize_msg : msg -> string
(** Telemetry serializer for the section's messages, also [;]-terminated. Lives
    here rather than at the entry point so the message and model fragments stay
    described by one module. *)

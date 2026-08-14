open Nopal_element
module Button = Nopal_ui.Button
module TextInput = Nopal_ui.TextInput
module Config = Nopal_image.Config
module Preview = Nopal_image.Preview
module Processing = Nopal_image.Processing

type upload =
  | Not_started
  | In_flight
  | Stored of int
  | Rejected of int
  | Undelivered of Nopal_http.error

(* How far the current photo has got. The length of the file the pass consumed
   is recorded on the stage that measured it rather than read back off the
   selection when something wants it: the picker and the stage do move together
   in every transition, but nothing in the types says so, so a reader wanting the
   two lengths beside each other would have to open an option the compiler
   cannot see is full. Carried here, a section holding no measured photo cannot
   report a comparison at all, which is the property the size fragments already
   depend on. *)
type stage =
  | Idle
  | Working
  | Ready of {
      info : Processing.result_info;
      source_byte_size : int;
      upload : upload;
    }
  | Failed of Processing.error

(* Which of the two pictures a delivered URL belongs to. A named pair rather
   than a boolean because the two are labelled differently on screen, so a URL
   put in the wrong slot would show the photo that is about to be sent under the
   heading of the photo that was picked - which is the one mistake a
   before-and-after pair exists to make impossible. *)
type preview_slot = Original_photo | Processed_photo

(* Where the before-and-after pair has got to. One variant rather than a pair of
   [string option]s, so a section holding half a pair cannot be read as one
   holding none, and only [update] moves between the arms.

   Every arm names the request it belongs to, the one holding nothing included.
   A URL is delivered a turn or more after it was asked for, so a delivery can
   arrive for a pair the section has already replaced; the generation it names is
   what tells that delivery from a current one. An arm that let go of a pair and
   then started counting again would number its next request the same as one
   still in flight for the pair it let go, and that delivery would be taken for
   a current one - so the arm holding nothing carries the number of the last
   request rather than resetting it. The arm names are prefixed because this
   module already has a [Ready] - the one a processing pass reaches - and two
   constructors of that name in one module would leave every match on either of
   them readable only by knowing which type it is against. *)
type previews =
  | No_previews of { generation : int }
  | Preview_pending of {
      generation : int;
      original : string option;
      processed : string option;
    }
  | Preview_ready of { generation : int; original : string; processed : string }
  (* The typed error rather than a rendering of it, for the reason [stage]'s own
     [Failed] keeps one: a failure that has been turned into a string is a
     failure that can only ever be shown the one way it was turned into. The tag
     is computed where every other tag is, at serialisation. *)
  | Preview_failed of { generation : int; error : Preview.error }

type model = {
  selection : Element.file_info option;
  stage : stage;
  previous_score : float option;
  note : string;
  previews : previews;
}

type msg =
  | Selected of Element.file_info list
  | Processed of {
      source : string;
      result : (Processing.result_info, Processing.error) result;
    }
  | Reshoot_clicked
  | Note_changed of string
  | Accept_clicked
  | Upload_finished of Nopal_http.outcome
  | Preview_delivered of {
      generation : int;
      slot : preview_slot;
      result : (string, Preview.error) result;
    }

(* Which of the two ways forward a measured photo is offered. A named pair
   rather than a bare boolean because the view and the telemetry both have to
   agree on which side of the threshold means which control, and matching on
   this in each of them is what makes the compiler check that they do. *)
type verdict = Accept | Reshoot

(* The picker has no label of its own to slugify, so its name and its test
   anchor are both supplied at the call site. The one name serves both the
   screen and the accessibility tree - it is rendered above the control and
   passed as its [aria-label] - so the two cannot drift apart. *)
let picker_label = "Receipt photo"
let picker_field = "receipt-photo"
let metadata_anchor = "receipt-flow-metadata"
let verdict_anchor = "receipt-flow-verdict"
let upload_anchor = "receipt-flow-upload"
let accept_field = "receipt-accept"
let reshoot_field = "receipt-reshoot"
let note_field = "receipt-note"

(* The before-and-after pair, and each half of it. A picture element carries no
   attributes of its own, so the anchor a browser test reaches a photograph
   through sits on the wrapper around it and the test selects the picture
   inside. That is what lets this section show a pair without the element
   vocabulary growing a case for it. *)
let preview_pair_anchor = "receipt-flow-previews"
let original_preview_anchor = "receipt-flow-preview-original"
let processed_preview_anchor = "receipt-flow-preview-processed"

(* What each half is called on screen. These are the point of the pair: a before
   and an after with nothing to tell them apart lets a reviewer read the photo
   that is about to be sent as the one that was picked, which is the one
   misreading a before-and-after exists to prevent. *)
let original_preview_label = "Original"
let processed_preview_label = "As uploaded"

(* And what each is called to someone who cannot see it. Two photographs of one
   receipt described the same way are two photographs a screen reader cannot
   tell apart, so each says which of the two it is rather than what it is of. *)
let original_preview_alt = "The receipt exactly as it was photographed"

let processed_preview_alt =
  "The receipt as it will be uploaded, after scaling and re-encoding"

let note_label = "Note for this receipt"
let note_placeholder = "What was it for?"

(* The section's own spacing, so the picker, the note and the three readouts read
   as separate things rather than as one run of text - the kitchen sink is a
   visual reference before it is anything else. Typed layout throughout: this
   example never writes a CSS string. The heading above all of it, and the
   wrapper a browser test scopes itself to, are supplied by the kitchen sink at
   the call site, the same way the file-input section takes them. *)
let section_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (fun l -> { l with gap = Some 12.0 })

let readout_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (fun l -> { l with gap = Some 4.0 })

(* The picker's name, on screen as well as in the accessibility tree. An
   [aria-label] alone names the control for a screen reader and for nobody
   else, which on a page whose whole purpose is to be looked at is half a
   label. *)
let picker_label_text =
  Nopal_style.Text.default |> Nopal_style.Text.font_weight Nopal_style.Font.Bold

(* The heading over each half of the pair. Its own constant rather than the
   picker's, because the two name different things and a change to how a control
   is named should not silently restyle a photograph's caption. *)
let preview_label_text =
  Nopal_style.Text.default |> Nopal_style.Text.font_weight Nopal_style.Font.Bold

(* One half of the pair: its heading and, under it, the photograph. *)
let preview_cell_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (fun l -> { l with gap = Some 4.0 })

(* The two halves, whichever way round they are laid out. Both the stacked and
   the side-by-side container use this, so the space between the photographs
   does not change with the viewport. *)
let preview_pair_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (fun l -> { l with gap = Some 12.0 })

(* How wide a photograph is drawn. Width alone, with the height left to follow
   from it, so what is shown keeps the proportions the pass actually produced -
   a preview stretched to a box would hide the one mistake a reviewer is looking
   at these two pictures to catch. The number fits inside the narrowest viewport
   the section is laid out for with room to spare, and two of them sit beside
   each other on a wide one. *)
let preview_width = 320.0

let preview_image_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (fun l ->
      { l with width = Some (Nopal_style.Style.Fixed preview_width) })

(* Its own endpoint rather than the one the file-input section posts to: both
   sections render on the same page, so a browser test that intercepts one must
   not catch the other's uploads as well. Relative, so it resolves against
   whatever host the example is served from and reaches nothing outside it. *)
let upload_url = "/api/receipt-capture"
let file_part_name = "receipt"
let note_part_name = "note"

(* How long a receipt is given to reach the server before the request is
   abandoned. Without one a connection that stops answering leaves the section
   reporting a request that will never come back, which is the one outcome this
   section must not have. Thirty seconds is calibration for a demo photograph on
   a phone connection, the same kind of number as the threshold above. *)
let upload_timeout_seconds = 30.0

(* The score a photo has to reach here before the section offers to keep it. It
   is on the same 0 to 255 scale as the focus score itself, measured at the
   metric edge named below, and it is calibration for this demo's receipts under
   this demo's lighting - nothing more. The image library deliberately defines no
   such number, because a score carries no meaning apart from the subject, the
   camera and the light it was measured under. *)
let sharpness_threshold = 6.0

(* This section's own capture parameters, every one of them stated. They differ
   from the library preset on purpose: two photos are only comparable when both
   were measured at the same metric edge, so the edge that makes the comparison
   meaningful is written here beside the picker rather than inherited. *)
let stored_long_edge = 1400
let metric_long_edge = 700
let encode_quality = 0.75
let encode_format = Config.Jpeg

(* The name and type declared for the bytes on the wire. They describe what this
   section encoded, not what the user picked: the upload carries the re-encoded
   photo, so passing on the original file's name and media type would be a
   declaration about bytes that were never sent. Both are read off the encode
   format so neither can drift from it. *)
let upload_mime = Config.format_to_mime encode_format

let upload_filename =
  let extension =
    match encode_format with
    | Config.Jpeg -> "jpg"
    | Config.Png -> "png"
    | Config.Webp -> "webp"
  in
  "receipt." ^ extension

(* The four constants above are accepted by [Config.make], so the rejected arm
   below is unreachable. It answers with the preset rather than raising, which
   keeps this function total; the unit suite pins all four values as they reach
   the backend, so a constant that started being rejected would show up as the
   preset's values rather than passing unnoticed. *)
let capture_config () =
  match
    Config.make ~max_edge:stored_long_edge ~metric_edge:metric_long_edge
      ~quality:encode_quality ~format:encode_format
  with
  | Ok config -> config
  | Error _ -> Config.recommended

(* Read off the score already in hand rather than kept beside it, so there is
   only ever one answer to which side of the threshold a photo fell on.
   [Float.compare] orders a score that is not a number below every real one, so
   a photo the metric could not measure is offered the re-shoot - which is the
   side to fall on when nothing is known about the picture. *)
let verdict (info : Processing.result_info) =
  match Float.compare info.Processing.sharpness sharpness_threshold >= 0 with
  | true -> Accept
  | false -> Reshoot

(* The score the section keeps hold of when it moves on from the photo it is
   showing. Read off the stage being left rather than written at each transition,
   so there is one answer to what "the previous photo" was and the arm that
   replaces a photo and the arm that rejects one cannot disagree about it. A
   stage holding no measurement leaves the previous one standing, which is what
   lets a failed pass sit between two photos without breaking the comparison. *)
let score_left_behind model =
  match model.stage with
  | Ready { info; source_byte_size = _; upload = _ } ->
      Some info.Processing.sharpness
  | Idle
  | Working
  | Failed _ ->
      model.previous_score

(* What the reply did to the upload. A request that completed is not the same
   thing as a receipt that was stored: a server that answered outside the
   success range refused it, and saying so is what keeps the demo from
   reporting a rejection as an upload. *)
let settled = function
  | Ok { Nopal_http.status; _ } -> (
      match status >= 200 && status < 300 with
      | true -> Stored status
      | false -> Rejected status)
  | Error error -> Undelivered error

(* The processed photo and the typed note, in that order, named by handle so no
   pixel data enters the OCaml heap. *)
let upload_parts ~blob_id ~note =
  [
    Nopal_http.Field (note_part_name, note);
    Nopal_http.File
      {
        name = file_part_name;
        blob_id;
        filename = Some upload_filename;
        mime = Some upload_mime;
      };
  ]

(* The request the pair currently held belongs to, read off the arm rather than
   kept beside it, so there is one answer to which request a delivery names and
   the arm and the counter cannot disagree about it. *)
let current_generation = function
  | No_previews { generation }
  | Preview_pending { generation; original = _; processed = _ }
  | Preview_ready { generation; original = _; processed = _ }
  | Preview_failed { generation; error = _ } ->
      generation

(* The generation the next request belongs to. It only ever goes up, across
   letting go of a pair as well as across replacing one, so no two requests in
   the life of a section are numbered alike and a URL still in flight can always
   be told from the one being waited for. *)
let next_generation previews = current_generation previews + 1

(* The URLs the pair is holding at this moment. Each call to the seam mints a URL
   of its own, so a complete pair is two of them and releasing it is two
   releases. A half-delivered pair holds one; an arm reporting a failure holds
   none, because nothing was minted for it. *)
let held_urls = function
  | No_previews { generation = _ } -> []
  | Preview_pending { generation = _; original; processed } -> (
      match (original, processed) with
      | None, None -> []
      | Some url, None -> [ url ]
      | None, Some url -> [ url ]
      | Some original, Some processed -> [ original; processed ])
  | Preview_ready { generation = _; original; processed } ->
      [ original; processed ]
  (* Nothing is held here because the arm keeps no URL: the two pictures are
     shown together, so neither is shown once one of them has failed. One side of
     a pair can arrive before the other fails, so this reader is only honest
     while the transition into the arm releases what it discards - which is why
     that release lives in [update]'s failure arm and reads the arm being LEFT
     rather than the one being entered. *)
  | Preview_failed { generation = _; error = _ } -> []

(* Everything the pair is holding, released. A URL keeps the picture it names
   alive until it is released and nothing else ever releases one - no unmount, no
   collector - so a section that replaces a pair without this holds every picture
   it has ever shown for the rest of the session. *)
let release_held previews =
  Nopal_mvu.Cmd.batch
    (List.map (fun url -> Preview.revoke ~url) (held_urls previews))

(* The arm a section that has let go of its pair sits in: nothing held, and the
   number of the last request kept so the next one cannot repeat it. *)
let released previews = No_previews { generation = current_generation previews }

(* A URL that arrived for a pair the section is no longer showing. It pins its
   picture exactly as a shown one does and nothing is going to show it, so it is
   released here rather than dropped. A delivery carrying no URL has nothing to
   release. *)
let release_arrival = function
  | Ok url -> Preview.revoke ~url
  | Error _ -> Nopal_mvu.Cmd.none

(* A URL put in the slot it was delivered for. The pair is reported ready only
   once both slots hold one: a section showing one picture is not showing a
   before and an after, and saying it is would let a reviewer read whichever
   arrived first as both.

   The slot being written is empty, so nothing is written over and nothing needs
   releasing here: [request_previews] asks once per slot under a generation of
   its own, the pair it belongs to starts with both slots empty, and the
   generation guard at the delivery site lets no other request's URL reach this
   point. *)
let with_delivered ~generation ~slot ~url ~original ~processed =
  let original, processed =
    match slot with
    | Original_photo -> (Some url, processed)
    | Processed_photo -> (original, Some url)
  in
  match (original, processed) with
  | Some original, Some processed ->
      Preview_ready { generation; original; processed }
  | None, (None | Some _)
  | Some _, None ->
      Preview_pending { generation; original; processed }

(* The picked photo and the processed one, asked for in that order - the order
   they are shown in. Both are asked for at once because the pair is what the
   section shows: a URL for one of them on its own has nothing to be beside. *)
let request_previews ~generation ~original ~processed =
  Nopal_mvu.Cmd.batch
    [
      Preview.preview_url ~blob_id:original (fun result ->
          Preview_delivered { generation; slot = Original_photo; result });
      Preview.preview_url ~blob_id:processed (fun result ->
          Preview_delivered { generation; slot = Processed_photo; result });
    ]

let init () =
  ( {
      selection = None;
      stage = Idle;
      previous_score = None;
      note = "";
      previews = No_previews { generation = 0 };
    },
    Nopal_mvu.Cmd.none )

let update model msg =
  match msg with
  | Note_changed note -> ({ model with note }, Nopal_mvu.Cmd.none)
  | Reshoot_clicked ->
      (* The rejected photo's readout goes, but its score stays: a re-shoot is
         precisely the moment a user is trying to beat the photo they were just
         shown, so the replacement has to have something to be measured
         against. The note stays too - it describes the receipt, not the photo
         of it. The pair goes with the readout, and the URLs holding it are
         released as it goes: the pictures are not on screen any more, and a
         re-shoot is the one thing a user of this section does repeatedly. *)
      ( {
          model with
          selection = None;
          stage = Idle;
          previous_score = score_left_behind model;
          previews = released model.previews;
        },
        release_held model.previews )
  | Selected [] ->
      (* The picker emptied. It reaches the same place a re-shoot does and owes
         the same release: the pictures it was showing describe a photo the user
         has taken back. *)
      ( {
          model with
          selection = None;
          stage = Idle;
          previous_score = score_left_behind model;
          previews = released model.previews;
        },
        release_held model.previews )
  | Selected (file :: _) ->
      (* The pair on screen describes the photo being replaced, so it is let go
         here rather than when the replacement's own pair arrives - which may be
         two turns away, or never, if the pass fails. Releasing before asking is
         what keeps a re-shoot loop from holding every picture it has shown. *)
      ( {
          model with
          selection = Some file;
          stage = Working;
          previous_score = score_left_behind model;
          previews = released model.previews;
        },
        Nopal_mvu.Cmd.batch
          [
            release_held model.previews;
            Processing.process ~blob_id:file.Element.blob_id
              ~config:(capture_config ()) (fun result ->
                Processed { source = file.Element.blob_id; result });
          ] )
  | Processed { source; result } -> (
      (* A pass answers for the photo it was started for, and it is recorded
         only where that photo is still the section's to describe. Two passes
         over different files genuinely can finish in either order, and the
         picker can be cleared while one is out, so the handle the pass names is
         checked against the one the picker holds rather than the result being
         written wherever the section happens to have got to. *)
      match (model.stage, model.selection) with
      | ( ( Working
          | Ready { info = _; source_byte_size = _; upload = Not_started }
          | Failed _ ),
          Some file ) -> (
          match String.equal file.Element.blob_id source with
          | true -> (
              match result with
              | Ok info ->
                  (* A pass that succeeded is the moment there are two photos
                     to show: the one that was picked and the one that will be
                     sent. Both URLs are asked for here, under a generation of
                     their own, so a pair delivered for a photo the section has
                     since moved off can be told from the pair it is holding.

                     Whatever the pair was holding is released first, in the same
                     batch and ahead of the requests. A second pass can answer
                     for a photo still picked - two passes over one handle can be
                     started and both are recorded - and that second answer
                     replaces the pair the first one produced. *)
                  let generation = next_generation model.previews in
                  ( {
                      model with
                      stage =
                        Ready
                          {
                            info;
                            (* The photo that passed the guard above, never
                               [model.selection] read again afterwards: the two
                               are the same file here only because the guard says
                               so, and reading it a second time would be reading
                               it without the guard. *)
                            source_byte_size = file.Element.size;
                            upload = Not_started;
                          };
                      previous_score = score_left_behind model;
                      previews =
                        Preview_pending
                          { generation; original = None; processed = None };
                    },
                    Nopal_mvu.Cmd.batch
                      [
                        release_held model.previews;
                        request_previews ~generation ~original:source
                          ~processed:info.Processing.blob_id;
                      ] )
              (* A pass that failed leaves nothing for a pair to be labelled
                 with: the two lengths under the photographs are read off the
                 measurement, and this arm is the measurement going. So the pair
                 goes with it and the URLs holding it are released as it goes -
                 the same release every other arm that lets go of a photo owes,
                 reached by the one route where the picker never changed. It is
                 also the only exit this arm has: a failed stage offers no
                 re-shoot control, so a pair left standing here would be pinned
                 until the user found the picker again. *)
              | Error error ->
                  ( {
                      model with
                      stage = Failed error;
                      previous_score = score_left_behind model;
                      previews = released model.previews;
                    },
                    release_held model.previews ))
          (* A pass for a photo that has since been replaced. It measured
             something the section is no longer holding, so it is not written
             over the photo that is. *)
          | false -> (model, Nopal_mvu.Cmd.none))
      (* Nothing on screen is waiting for a measurement: the picker was cleared
         or the photo re-shot, so there is no photo to record one against, or
         the receipt has already been sent and re-measuring it now would put the
         section back to offering an upload that is already out. *)
      | ( Ready
            {
              info = _;
              source_byte_size = _;
              upload = In_flight | Stored _ | Rejected _ | Undelivered _;
            },
          (Some _ | None) )
      | Idle, (Some _ | None)
      | ( ( Working
          | Ready { info = _; source_byte_size = _; upload = Not_started }
          | Failed _ ),
          None ) ->
          (model, Nopal_mvu.Cmd.none))
  | Accept_clicked -> (
      match model.stage with
      | Ready { info; source_byte_size; upload = Not_started } ->
          (* The handle the processing pass produced, never the one the picker
             produced: the photo that was measured, scaled and re-encoded is the
             one the readout beside this describes and the one worth sending. *)
          ( {
              model with
              stage = Ready { info; source_byte_size; upload = In_flight };
            },
            Nopal_http.post ~timeout:upload_timeout_seconds
              ~body:
                (Nopal_http.Multipart
                   (upload_parts ~blob_id:info.Processing.blob_id
                      ~note:model.note))
              upload_url
              (fun outcome -> Upload_finished outcome) )
      (* The control is offered in one stage only, so there is no other stage
         from which a receipt can be sent. Nothing was started here, so nothing
         is dropped by answering with the model unchanged. *)
      | Ready
          {
            info = _;
            source_byte_size = _;
            upload = In_flight | Stored _ | Rejected _ | Undelivered _;
          }
      | Idle
      | Working
      | Failed _ ->
          (model, Nopal_mvu.Cmd.none))
  | Upload_finished outcome -> (
      match model.stage with
      | Ready { info; source_byte_size; upload = In_flight } ->
          ( {
              model with
              stage = Ready { info; source_byte_size; upload = settled outcome };
            },
            Nopal_mvu.Cmd.none )
      (* A reply for a photo the section has already moved on from - the user
         picked another one, or re-shot, while the request was out. It belongs
         to a receipt that is no longer on screen, so it is not written over the
         one that is. *)
      | Ready
          {
            info = _;
            source_byte_size = _;
            upload = Not_started | Stored _ | Rejected _ | Undelivered _;
          }
      | Idle
      | Working
      | Failed _ ->
          (model, Nopal_mvu.Cmd.none))
  | Preview_delivered { generation; slot; result } -> (
      match model.previews with
      | Preview_pending { generation = current; original; processed } -> (
          match Int.equal current generation with
          | true -> (
              match result with
              (* A delivery carrying no URL ends the pair rather than leaving it
                 waiting: the two pictures are asked for together and shown
                 together, so one of them that cannot be minted is a pair that
                 cannot be shown. It is recorded in the preview vocabulary and
                 nowhere else - the photo it names was decoded, scaled,
                 re-encoded and measured before anything asked to show it, so a
                 picture that failed says nothing about the pass that produced
                 it and must not be read as one that failed.

                 Whatever the pair had already been handed is released here. The
                 arm being entered keeps no URL, so this is the last point at
                 which the half that did arrive is reachable at all: every other
                 release path reads the arm, and the arm has forgotten it. *)
              | Error error ->
                  ( {
                      model with
                      previews = Preview_failed { generation; error };
                    },
                    release_held model.previews )
              | Ok url ->
                  ( {
                      model with
                      previews =
                        with_delivered ~generation ~slot ~url ~original
                          ~processed;
                    },
                    Nopal_mvu.Cmd.none ))
          (* A URL minted for a pair the section has already moved off. It names
             a photo that is no longer on screen, so it is not written over the
             pair that is - and it is released rather than dropped, because
             holding it would pin that photo for the rest of the session. *)
          | false -> (model, release_arrival result))
      (* Nothing is waiting for a URL: the pair is already complete, it has
         already failed, or none was ever asked for. Whatever arrived has nothing
         to be shown beside, so it is released on the same grounds. *)
      | No_previews { generation = _ }
      | Preview_ready { generation = _; original = _; processed = _ }
      | Preview_failed { generation = _; error = _ } ->
          (model, release_arrival result))

let subscriptions _model = Nopal_mvu.Sub.none

let selected_name model =
  match model.selection with
  | Some file -> file.Element.name
  | None -> "no photo"

let metadata_text model =
  match model.stage with
  | Idle -> "No receipt selected"
  | Working -> "Processing " ^ selected_name model
  | Ready { info; source_byte_size = _; upload = _ } ->
      (* The score is read out here and nowhere else. The telemetry deliberately
         carries what it decided rather than the number itself, because a float
         rendering is not something a browser spec can assert on - which leaves
         this readout as the only place a person can see what the photo actually
         measured. *)
      Printf.sprintf "%d by %d pixels, %d bytes, focus score %.1f"
        info.Processing.width info.Processing.height info.Processing.byte_size
        info.Processing.sharpness
  | Failed error -> "Processing failed: " ^ Processing.message error

(* How long a picture is, in the unit the readout above already speaks. Raw
   bytes rather than a rounded kilobyte: a rounding rule is a second vocabulary
   for one quantity, and this section already states that quantity one way. *)
let size_text bytes = Printf.sprintf "%d bytes" bytes

(* Which way the re-encode took the payload. A named trio rather than the raw
   sign of a comparison, because the label reads differently in each direction
   and the compiler is what should say that all three have been written. *)
type payload_change = Smaller | Unchanged | Larger

let payload_change ~original ~processed =
  match Int.compare processed original with
  | 0 -> Unchanged
  | order -> (
      match order < 0 with
      | true -> Smaller
      | false -> Larger)

(* What the processed photo came to as a share of the photo that was picked. A
   named trio rather than an [int option], for the reason [payload_change] is a
   variant rather than a sign: a share the arithmetic cannot state and a share
   too small for the unit this readout speaks in are two different things, and
   neither of them is a share of nothing.

   [No_original] is the zero-byte file a picker can hand over, the case the
   division itself cannot state. The product that division is taken over has a
   ceiling of its own wherever [int] is 32 bits wide, as it is once this is
   compiled for a browser: a processed photo past about twenty megabytes wraps
   it. That bound is held by the pass rather than guarded here - the photo is
   scaled to [stored_long_edge] before it is re-encoded, so nothing this section
   is handed comes near it - and no test could speak to it either, since the
   structural suite runs native, where the width is wider still.
   [Under_a_percent] is the re-encode that worked so well
   the whole-number share floors to nothing: "reduced to 0% of the original"
   reads as a broken readout rather than as a very good one, which is the same
   misreading the two directions are worded apart to prevent, at the other end of
   the range. *)
type share = No_original | Under_a_percent | Share of int

let share_of_original ~original ~processed =
  match Int.equal original 0 with
  | true -> No_original
  | false -> (
      match processed * 100 / original with
      | 0 -> Under_a_percent
      | percent -> Share percent)

(* The processed photo's length beside what it cost. Two lengths on their own are
   two numbers a reader has to divide, and being spared that division is the
   point of showing them at all - so the share is rendered here, where a person
   is reading a screen, and nowhere near the telemetry, where a rounding rule
   would become something a browser spec had to reimplement in order to assert on
   it.

   A re-encode does not always shrink: an already-small photo, or one whose long
   edge is under the stored edge so no downscale applies, comes back bigger. A
   share rendered without saying which way it went reads, under a heading saying
   this is the photo about to be sent, as a reduction that went wrong rather than
   as the ordinary outcome for a small photo. So the two directions are worded
   apart, and they share no wording, which is what keeps a reader - and an
   assertion - from taking one for the other. *)
let reduction_text ~original ~processed =
  let length = size_text processed in
  match
    (payload_change ~original ~processed, share_of_original ~original ~processed)
  with
  | Unchanged, (No_original | Under_a_percent | Share _) ->
      Printf.sprintf "%s, the same size as the original" length
  | Smaller, Share percent ->
      Printf.sprintf "%s, reduced to %d%% of the original" length percent
  | Larger, Share percent ->
      Printf.sprintf "%s, grown to %d%% of the original" length percent
  (* A re-encode that came back under a hundredth of what it consumed. It is a
     reduction and reads as one, so the direction's own wording stands and only
     the number - which whole-number arithmetic would render as nothing - is said
     in words instead. *)
  | Smaller, Under_a_percent ->
      Printf.sprintf "%s, reduced to under 1%% of the original" length
  (* Nothing is a share of an empty original, so these say only which way it
     went. Smaller than zero bytes is not something a length can be, and a photo
     that grew cannot be under a hundredth of what it grew from; the arms are
     written out because a total function is what the section owes rather than
     because anything reaches them. *)
  | Smaller, No_original ->
      Printf.sprintf "%s, smaller than the original" length
  | Larger, (No_original | Under_a_percent) ->
      Printf.sprintf "%s, larger than the original" length

(* Where an upload stands is read off the stage rather than kept beside it, so a
   section holding no measured photo cannot report a receipt in flight. *)
let upload_of_stage = function
  | Idle
  | Working
  | Failed _ ->
      Not_started
  | Ready { upload; info = _; source_byte_size = _ } -> upload

(* Every outcome says on screen what happened, so a failure is something the
   person looking at the section can see rather than only something the
   telemetry records. *)
let upload_text = function
  | Not_started -> "Not uploaded yet"
  | In_flight -> "Uploading\u{2026}"
  | Stored status -> Printf.sprintf "Uploaded (HTTP %d)" status
  | Rejected status ->
      Printf.sprintf "The server refused this receipt (HTTP %d)" status
  | Undelivered error -> "Upload failed: " ^ Nopal_http.message error

(* Stated beside the controls rather than in a comment, because the person
   looking at the section is the one who needs to know that the number the
   verdict was reached against is this demo's own and not a library rule. *)
let calibration_note =
  Printf.sprintf
    "Threshold %.1f is demo calibration for this photo setup; the image \
     library defines no sharp enough."
    sharpness_threshold

(* Every field of the button configuration is written out. The two controls
   differ in more than their label - the one that keeps a photo and the one that
   throws it away should not look alike - so neither is derived from the other
   or from a preset. *)
let control ~variant ~field ~on_click label =
  Button.view
    {
      Button.variant;
      disabled = false;
      loading = false;
      on_click;
      style = None;
      interaction = None;
      attrs = [ ("data-field", field) ];
    }
    (Element.text label)

(* The two ways forward are offered while the measured photo is still the
   section's to do something with. Once it has been sent there is nothing left
   to decide, and the upload readout is what says how it went. *)
let verdict_children model =
  match model.stage with
  | Idle
  | Working
  | Failed _
  | Ready
      {
        info = _;
        source_byte_size = _;
        upload = In_flight | Stored _ | Rejected _ | Undelivered _;
      } ->
      []
  | Ready { info; source_byte_size = _; upload = Not_started } ->
      let choice =
        match verdict info with
        | Accept ->
            control ~variant:Button.Primary ~field:accept_field
              ~on_click:(Some Accept_clicked) "Accept this receipt"
        | Reshoot ->
            control ~variant:Button.Secondary ~field:reshoot_field
              ~on_click:(Some Reshoot_clicked) "Re-shoot this receipt"
      in
      [ choice; Element.text calibration_note ]

(* Every field is written out rather than taken from a constructor and amended,
   so what the note field does is stated here in full. *)
let note_input model =
  TextInput.view
    {
      TextInput.label = note_label;
      value = model.note;
      placeholder = Some note_placeholder;
      error = None;
      disabled = false;
      id = Some note_field;
      on_change = Some (fun value -> Note_changed value);
      on_submit = None;
      on_blur = None;
      style = None;
      interaction = None;
      attrs = [];
    }

(* A photograph under the heading that says which of the two it is. Every field
   is supplied by the caller rather than derived from the other half, so the two
   cannot be produced from one description and end up naming the same picture. *)
let preview_cell ~anchor ~label ~size_label ~alt ~src =
  Element.column ~style:preview_cell_style
    ~attrs:[ ("data-testid", anchor) ]
    [
      Element.styled_text ~text_style:preview_label_text label;
      Element.image ~style:preview_image_style ~src ~alt ();
      Element.text size_label;
    ]

(* The pair, and only when there is a pair. A section still waiting for its URLs
   holds at most one of them, and one photograph shown on its own under whichever
   heading arrived first is not a before and an after - it is a picture a
   reviewer has no way to place. A pair that could not be minted shows nothing
   for the same reason; where it stands is recorded in the telemetry, and the
   photo it names was measured and encoded before anything asked to show it, so
   there is nothing here to warn anyone about. *)
let preview_cells model =
  match model.previews with
  | No_previews { generation = _ }
  | Preview_pending { generation = _; original = _; processed = _ }
  | Preview_failed { generation = _; error = _ } ->
      []
  | Preview_ready { generation = _; original; processed } -> (
      match model.stage with
      | Idle
      | Working
      | Failed _ ->
          []
      | Ready { info; source_byte_size; upload = _ } ->
          [
            preview_cell ~anchor:original_preview_anchor
              ~label:original_preview_label
              ~size_label:(size_text source_byte_size)
              ~alt:original_preview_alt ~src:original;
            preview_cell ~anchor:processed_preview_anchor
              ~label:processed_preview_label
              ~size_label:
                (reduction_text ~original:source_byte_size
                   ~processed:info.Processing.byte_size)
              ~alt:processed_preview_alt ~src:processed;
          ])

(* A before and an after are read against each other, so they go side by side
   wherever there is room for two of them and stack where there is not. A phone
   held upright has room for one: two photographs squeezed into that width are
   two photographs nobody can see the difference between, which is the whole of
   what this pair is for. Only the direction changes - both layouts show both
   pictures, because reflowing by showing less is not reflowing. Anything
   between the two widths stacks as well, which is the conservative side to
   fall on when the room is uncertain.

   The container itself is unconditional - it is rendered in every stage, empty
   in all the ones [preview_cells] returns nothing for - so its presence says
   only that this section rendered, never that there is a pair to see. Anything
   asserting the pair is shown has to read the two cells inside it. *)
let preview_pair viewport model =
  let cells = preview_cells model in
  Element.responsive viewport
    ~compact:
      (Element.column ~style:preview_pair_style
         ~attrs:[ ("data-testid", preview_pair_anchor) ]
         cells)
    ~expanded:
      (Element.row ~style:preview_pair_style
         ~attrs:[ ("data-testid", preview_pair_anchor) ]
         cells)
    ()

let view viewport model =
  Element.column ~style:section_style
    [
      Element.styled_text ~text_style:picker_label_text picker_label;
      Element.file_input
        ~attrs:[ ("data-field", picker_field); ("aria-label", picker_label) ]
        ~accept:[ "image/*" ] ~capture:Element.Environment ~multiple:false
        ~on_change:(fun files -> Selected files)
        ();
      note_input model;
      Element.column ~style:readout_style
        ~attrs:[ ("data-testid", metadata_anchor) ]
        [ Element.text (metadata_text model) ];
      (* Between what the pass measured and the two ways forward it earns: the
         photographs are what a person decides on, so they are read before the
         control that acts on the decision rather than after it. *)
      preview_pair viewport model;
      Element.column ~style:readout_style
        ~attrs:[ ("data-testid", verdict_anchor) ]
        (verdict_children model);
      Element.column ~style:readout_style
        ~attrs:[ ("data-testid", upload_anchor) ]
        [ Element.text (upload_text (upload_of_stage model.stage)) ];
    ]

(* Each failure names the stage that failed, so a spec reading these by
   substring cannot mistake an undecodable file for a missing handle — the two
   have different remedies and the telemetry has to say which one happened. The
   platform's own description is left out on purpose: it is written by the
   browser, not by this repo, so it is not something a spec can pin. It stays
   readable through [Processing.message] in the readout, where a person needs
   it. *)
let error_tag = function
  | Processing.Blob_not_found _ -> "blob_not_found"
  | Processing.Decode_failed _ -> "decode_failed"
  | Processing.Canvas_unavailable _ -> "canvas_unavailable"
  | Processing.Pixel_read_failed _ -> "pixel_read_failed"
  | Processing.Encode_failed _ -> "encode_failed"

let stage_tag = function
  | Idle -> "idle"
  | Working -> "working"
  | Ready _ -> "ready"
  | Failed error -> "failed:" ^ error_tag error

(* The transport failure kinds. This is the section that states the example's
   [upload=] vocabulary; the file-input section's is the older and narrower one
   and differs in two named places. It has no rejection arm at all, so a server
   that refuses an upload there is reported as [upload=ok:404;] where this
   section reports [upload=rejected:404;]. And its [Invalid_blob] tag carries
   the handle, which it can because the handle it sends is a literal it wrote
   itself; the one here is issued by the platform at run time and is not a value
   any test could name in advance, so it is left out. It stays readable through
   [Nopal_http.message] in the readout, where a person needs it. Migrating that
   section onto this vocabulary would change assertions in a shipped browser
   spec and belongs to whoever next touches it. *)
let upload_error_tag = function
  | Nopal_http.Network_error _ -> "error:network"
  | Nopal_http.Timeout -> "error:timeout"
  | Nopal_http.Invalid_blob _ -> "error:invalid_blob"

(* A request that completed and a receipt that was stored are different claims,
   so a refusal is tagged as one rather than folded in with the successes. *)
let upload_tag = function
  | Not_started -> "idle"
  | In_flight -> "uploading"
  | Stored status -> Printf.sprintf "ok:%d" status
  | Rejected status -> Printf.sprintf "rejected:%d" status
  | Undelivered error -> upload_error_tag error

(* The stored dimensions and byte length are emitted only once a pass has
   produced them, so a fragment naming a size is never satisfiable by a section
   that has processed nothing. Every field is terminated with ';' so a substring
   assertion is bounded on both sides. *)
let result_fragments = function
  | Idle
  | Working
  | Failed _ ->
      []
  | Ready { info; source_byte_size; upload = _ } ->
      let sharpness_ok =
        match verdict info with
        | Accept -> true
        | Reshoot -> false
      in
      [
        Printf.sprintf "width=%d;" info.Processing.width;
        Printf.sprintf "height=%d;" info.Processing.height;
        Printf.sprintf "byte_size=%d;" info.Processing.byte_size;
        (* The length of the file the pass consumed, beside the length it
           produced. Two integers rather than the ratio between them: a share is
           a float by another name, and its rendering would depend on a rounding
           rule a spec would have to reimplement in order to assert on it. Every
           question the ratio answers is answerable from the pair, and the pair
           is exact. The share is rendered on screen instead, where a person is
           reading it. *)
        Printf.sprintf "original_byte_size=%d;" source_byte_size;
        Printf.sprintf "sharpness_ok=%b;" sharpness_ok;
      ]

(* Strictly better, so a re-shoot that scores the same as the photo it replaced
   is not reported as an improvement. [Float.compare] orders a score the metric
   could not produce below every real one, which keeps the answer defined in both
   directions: an unmeasurable photo is not sharper than anything, and anything
   measured is sharper than an unmeasurable one. *)
let sharper_than (info : Processing.result_info) previous =
  Float.compare info.Processing.sharpness previous > 0

(* What the comparison decided, never the two scores it decided from: float
   rendering is not something a browser spec can assert on. The fragment is
   absent until a second photo exists, so one claiming a comparison is never
   satisfiable by a section that has only ever measured one photo. *)
let comparison_fragments model =
  match (model.stage, model.previous_score) with
  | (Idle | Working | Failed _), _ -> []
  | Ready _, None -> []
  | Ready { info; source_byte_size = _; upload = _ }, Some previous ->
      [
        Printf.sprintf "sharper_than_previous=%b;" (sharper_than info previous);
      ]

(* Where the before-and-after pair stands, in a vocabulary of its own. It is
   deliberately not the one [processing=] or [upload=] uses: a picture that
   cannot be shown is not a photo that failed to process and not a receipt the
   server refused, so an assertion aimed at one of the three is not satisfiable
   by either of the others. The URLs themselves are never emitted - they are
   minted at run time and are not values any spec could name in advance. *)
(* Why a picture could not be shown, in the vocabulary the preview fragment
   reports. A handle nothing is stored under, a platform that mints no URLs and
   an application that registered no backend have three different remedies, so
   each carries its own tag and an assertion aimed at one is not satisfiable by
   either of the others. The platform's own description is left out of the tag on
   purpose - it is written by the browser, not by this repo, so it is not a value
   any spec could name in advance. It is not lost with it: the arm keeps the
   typed error rather than this rendering of it, so [Preview.message] still
   reaches the description for anything given somewhere to show it. Nothing shows
   it today, which is why the arm renders no picture and no reason. *)
let preview_error_tag = function
  | Preview.Blob_not_found _ -> "blob_not_found"
  | Preview.Url_unavailable _ -> "url_unavailable"
  | Preview.Backend_unregistered _ -> "backend_unregistered"

let previews_tag = function
  | No_previews { generation = _ } -> "none"
  | Preview_pending { generation = _; original = _; processed = _ } -> "pending"
  | Preview_ready { generation = _; original = _; processed = _ } -> "ready"
  | Preview_failed { generation = _; error } ->
      "failed:" ^ preview_error_tag error

let serialize_model model =
  String.concat " "
    (Printf.sprintf "processing=%s;" (stage_tag model.stage)
     :: result_fragments model.stage
    @ comparison_fragments model
    @ [
        Printf.sprintf "upload=%s;" (upload_tag (upload_of_stage model.stage));
        Printf.sprintf "previews=%s;" (previews_tag model.previews);
      ])

(* Which of the two slots a delivery answered for, so a message fragment says
   which half of the pair spoke. The token names the slot and is deliberately
   independent of the heading that slot is shown under: the headings are read by
   a person and can be reworded for them, and a fragment a spec asserts on must
   not move when they are. *)
let slot_name = function
  | Original_photo -> "Original"
  | Processed_photo -> "Processed"

let serialize_msg = function
  | Selected files -> Printf.sprintf "ReceiptSelected:%d;" (List.length files)
  (* The handle the pass was started for is deliberately absent: it is issued by
     the platform at run time, so it is not a value any spec could name in
     advance. What it decides - whether the result was recorded at all - is
     readable in the model fragments. *)
  | Processed { source = _; result = Ok _ } -> "ReceiptProcessed:ok;"
  | Processed { source = _; result = Error _ } -> "ReceiptProcessed:error;"
  | Reshoot_clicked -> "ReceiptReshootClicked;"
  (* The note itself is deliberately absent: it is whatever the user typed, so
     asserting on it would pin a value no test can predict, and it travels on
     the wire where a browser test can read it. *)
  | Note_changed _ -> "ReceiptNoteChanged;"
  | Accept_clicked -> "ReceiptAcceptClicked;"
  | Upload_finished outcome ->
      Printf.sprintf "ReceiptUploadFinished:%s;" (upload_tag (settled outcome))
  (* Which of the two pictures answered, and whether it answered with a URL.
     The URL is left out for the reason it is left out of the model fragments,
     and the generation with it: it is a counter this module keeps, not
     something a spec could name in advance. Why a delivery carried no URL is
     readable in the model fragment, which names the reason. *)
  | Preview_delivered { generation = _; slot; result = Ok _ } ->
      Printf.sprintf "ReceiptPreview%s:ok;" (slot_name slot)
  | Preview_delivered { generation = _; slot; result = Error _ } ->
      Printf.sprintf "ReceiptPreview%s:error;" (slot_name slot)

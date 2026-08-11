open Nopal_element
module Button = Nopal_ui.Button
module TextInput = Nopal_ui.TextInput
module Config = Nopal_image.Config
module Processing = Nopal_image.Processing

type upload =
  | Not_started
  | In_flight
  | Stored of int
  | Rejected of int
  | Undelivered of Nopal_http.error

type stage =
  | Idle
  | Working
  | Ready of { info : Processing.result_info; upload : upload }
  | Failed of Processing.error

type model = {
  selection : Element.file_info option;
  stage : stage;
  previous_score : float option;
  note : string;
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
  | Ready { info; upload = _ } -> Some info.Processing.sharpness
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

let init () =
  ( { selection = None; stage = Idle; previous_score = None; note = "" },
    Nopal_mvu.Cmd.none )

let update model msg =
  match msg with
  | Note_changed note -> ({ model with note }, Nopal_mvu.Cmd.none)
  | Reshoot_clicked ->
      (* The rejected photo's readout goes, but its score stays: a re-shoot is
         precisely the moment a user is trying to beat the photo they were just
         shown, so the replacement has to have something to be measured
         against. The note stays too - it describes the receipt, not the photo
         of it. *)
      ( {
          model with
          selection = None;
          stage = Idle;
          previous_score = score_left_behind model;
        },
        Nopal_mvu.Cmd.none )
  | Selected [] ->
      ( {
          model with
          selection = None;
          stage = Idle;
          previous_score = score_left_behind model;
        },
        Nopal_mvu.Cmd.none )
  | Selected (file :: _) ->
      ( {
          model with
          selection = Some file;
          stage = Working;
          previous_score = score_left_behind model;
        },
        Processing.process ~blob_id:file.Element.blob_id
          ~config:(capture_config ()) (fun result ->
            Processed { source = file.Element.blob_id; result }) )
  | Processed { source; result } -> (
      (* A pass answers for the photo it was started for, and it is recorded
         only where that photo is still the section's to describe. Two passes
         over different files genuinely can finish in either order, and the
         picker can be cleared while one is out, so the handle the pass names is
         checked against the one the picker holds rather than the result being
         written wherever the section happens to have got to. *)
      match (model.stage, model.selection) with
      | (Working | Ready { upload = Not_started; _ } | Failed _), Some file -> (
          match String.equal file.Element.blob_id source with
          | true -> (
              match result with
              | Ok info ->
                  ( {
                      model with
                      stage = Ready { info; upload = Not_started };
                      previous_score = score_left_behind model;
                    },
                    Nopal_mvu.Cmd.none )
              | Error error ->
                  ( {
                      model with
                      stage = Failed error;
                      previous_score = score_left_behind model;
                    },
                    Nopal_mvu.Cmd.none ))
          (* A pass for a photo that has since been replaced. It measured
             something the section is no longer holding, so it is not written
             over the photo that is. *)
          | false -> (model, Nopal_mvu.Cmd.none))
      (* Nothing on screen is waiting for a measurement: the picker was cleared
         or the photo re-shot, so there is no photo to record one against, or
         the receipt has already been sent and re-measuring it now would put the
         section back to offering an upload that is already out. *)
      | ( Ready { upload = In_flight | Stored _ | Rejected _ | Undelivered _; _ },
          (Some _ | None) )
      | Idle, (Some _ | None)
      | (Working | Ready { upload = Not_started; _ } | Failed _), None ->
          (model, Nopal_mvu.Cmd.none))
  | Accept_clicked -> (
      match model.stage with
      | Ready { info; upload = Not_started } ->
          (* The handle the processing pass produced, never the one the picker
             produced: the photo that was measured, scaled and re-encoded is the
             one the readout beside this describes and the one worth sending. *)
          ( { model with stage = Ready { info; upload = In_flight } },
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
      | Ready { upload = In_flight | Stored _ | Rejected _ | Undelivered _; _ }
      | Idle
      | Working
      | Failed _ ->
          (model, Nopal_mvu.Cmd.none))
  | Upload_finished outcome -> (
      match model.stage with
      | Ready { info; upload = In_flight } ->
          ( { model with stage = Ready { info; upload = settled outcome } },
            Nopal_mvu.Cmd.none )
      (* A reply for a photo the section has already moved on from - the user
         picked another one, or re-shot, while the request was out. It belongs
         to a receipt that is no longer on screen, so it is not written over the
         one that is. *)
      | Ready
          { upload = Not_started | Stored _ | Rejected _ | Undelivered _; _ }
      | Idle
      | Working
      | Failed _ ->
          (model, Nopal_mvu.Cmd.none))

let subscriptions _model = Nopal_mvu.Sub.none

let selected_name model =
  match model.selection with
  | Some file -> file.Element.name
  | None -> "no photo"

let metadata_text model =
  match model.stage with
  | Idle -> "No receipt selected"
  | Working -> "Processing " ^ selected_name model
  | Ready { info; upload = _ } ->
      (* The score is read out here and nowhere else. The telemetry deliberately
         carries what it decided rather than the number itself, because a float
         rendering is not something a browser spec can assert on - which leaves
         this readout as the only place a person can see what the photo actually
         measured. *)
      Printf.sprintf "%d by %d pixels, %d bytes, focus score %.1f"
        info.Processing.width info.Processing.height info.Processing.byte_size
        info.Processing.sharpness
  | Failed error -> "Processing failed: " ^ Processing.message error

(* Where an upload stands is read off the stage rather than kept beside it, so a
   section holding no measured photo cannot report a receipt in flight. *)
let upload_of_stage = function
  | Idle
  | Working
  | Failed _ ->
      Not_started
  | Ready { upload; info = _ } -> upload

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
  | Ready { upload = In_flight | Stored _ | Rejected _ | Undelivered _; _ } ->
      []
  | Ready { info; upload = Not_started } ->
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

let view _viewport model =
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
  | Ready { info; upload = _ } ->
      let sharpness_ok =
        match verdict info with
        | Accept -> true
        | Reshoot -> false
      in
      [
        Printf.sprintf "width=%d;" info.Processing.width;
        Printf.sprintf "height=%d;" info.Processing.height;
        Printf.sprintf "byte_size=%d;" info.Processing.byte_size;
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
  | Ready { info; upload = _ }, Some previous ->
      [
        Printf.sprintf "sharper_than_previous=%b;" (sharper_than info previous);
      ]

let serialize_model model =
  String.concat " "
    (Printf.sprintf "processing=%s;" (stage_tag model.stage)
     :: result_fragments model.stage
    @ comparison_fragments model
    @ [ Printf.sprintf "upload=%s;" (upload_tag (upload_of_stage model.stage)) ]
    )

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

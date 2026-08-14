open Nopal_test.Test_renderer
module Sub = Kitchen_sink_app__Sub_receipt_flow
module E = Nopal_element.Element
module Config = Nopal_image.Config
module Preview = Nopal_image.Preview
module Processing = Nopal_image.Processing

let vp = Nopal_element.Viewport.desktop
let picker = By_attr ("data-field", "receipt-photo")
let metadata = By_attr ("data-testid", "receipt-flow-metadata")
let verdict = By_attr ("data-testid", "receipt-flow-verdict")
let accept = By_attr ("data-field", "receipt-accept")
let reshoot = By_attr ("data-field", "receipt-reshoot")
let note = By_attr ("data-field", "receipt-note")
let upload_readout = By_attr ("data-testid", "receipt-flow-upload")
let preview_pair = By_attr ("data-testid", "receipt-flow-previews")
let original_preview = By_attr ("data-testid", "receipt-flow-preview-original")
let processed_preview = By_attr ("data-testid", "receipt-flow-preview-processed")

(* The structural renderer names a picture [image] where a browser renders
   [img]. Both are reached the same way in the end - through the anchor on the
   wrapper around it, because a picture element carries no attributes of its
   own - so the two suites select the same node under two names. *)
let picture = By_tag "image"

(* A selection as the renderer hands it over: an opaque store handle plus
   user-agent metadata. Built directly, which is what keeping [file_info]
   platform-free is for. *)
let receipt =
  E.file_info ~blob_id:"blob-receipt-1" ~name:"receipt-0042.jpg" ~size:2_097_152
    ~mime:"image/jpeg" ~last_modified:1_700_000_000_000.

(* The handle the processing pass hands back is a new one, so a later step that
   sent the picked handle instead of the processed one is visible. Every
   dimension is unrelated to any config value, so a backend that echoed its
   parameters could not satisfy the metadata assertions. *)
let processed_handle = "blob-receipt-processed-9f2"

let processed_info ~sharpness =
  {
    Processing.blob_id = processed_handle;
    width = 1024;
    height = 768;
    byte_size = 214_007;
    sharpness;
  }

(* A second photo, distinguishable from the first at every point the section
   could confuse them: a different picked handle, so a result can be correlated
   back to the photo it was measured for, and a different processed handle and
   set of dimensions, so a readout describing the wrong one is visible rather
   than accidentally identical. *)
let other_receipt =
  E.file_info ~blob_id:"blob-receipt-2" ~name:"receipt-0043.jpg" ~size:1_048_576
    ~mime:"image/jpeg" ~last_modified:1_700_000_100_000.

let replacement_handle = "blob-receipt-processed-4c8"

let replacement_info ~sharpness =
  {
    Processing.blob_id = replacement_handle;
    width = 1440;
    height = 1080;
    byte_size = 305_112;
    sharpness;
  }

(* Deliveries the fakes below have parked, oldest first. A fake that answers
   before it returns settles every stage inside whatever the section was doing
   at the time, which is where a delivery arriving twice, or two passes
   arriving in an order the source does not show, would hide. Parking gives the
   section a real turn boundary while staying drainable from a synchronous test.
   What it does not model is ordering between these deliveries and any other
   event source; this suite has no other event source. *)
let pending : (unit -> unit) Queue.t = Queue.create ()
let park deliver = Queue.add deliver pending

(* A parked delivery may park another, so this drains to quiescence rather than
   once through, and the cap turns a queue that feeds itself into a named
   failure instead of a hang. *)
let drain_limit = 64

let drain () =
  let rec loop steps =
    match Queue.take_opt pending with
    | None -> ()
    | Some deliver ->
        (match steps < drain_limit with
        | true -> ()
        | false -> Alcotest.fail "the parked deliveries never ran out");
        deliver ();
        loop (steps + 1)
  in
  loop 0

(* Deliveries parked under the handle the pass was started for. The queue above
   answers oldest first, which is the one order that cannot show a pass
   answering after the photo it was started for has already been replaced -
   that needs the later pass answered first. These are therefore taken by
   handle rather than by position. *)
let parked_by_handle : (string * (unit -> unit)) list ref = ref []

let clear_parked () =
  Queue.clear pending;
  parked_by_handle := []

(* The oldest delivery parked under [blob_id], with every other one left in the
   order it was parked. Written as a total fold so nothing here reaches for a
   partial list function to find it. *)
let rec take_parked ~blob_id parked =
  match parked with
  | [] -> None
  | (handle, deliver) :: rest -> (
      match String.equal handle blob_id with
      | true -> Some (deliver, rest)
      | false -> (
          match take_parked ~blob_id rest with
          | None -> None
          | Some (deliver_later, remaining) ->
              Some (deliver_later, (handle, deliver) :: remaining)))

let answer_pass_for ~blob_id =
  match take_parked ~blob_id !parked_by_handle with
  | None ->
      Alcotest.fail
        (Printf.sprintf "no processing pass is parked for the handle %s" blob_id)
  | Some (deliver, remaining) ->
      parked_by_handle := remaining;
      deliver ()

(* Installs [backend] for the duration of [f] and restores the default
   afterwards, so a failing assertion cannot leak a stub into the next case.
   Deliveries the fake parked are dropped on the way out for the same reason:
   an assertion that fails mid-flow would otherwise leave one queued for
   whichever case drains next. *)
let with_image_backend backend f =
  Fun.protect
    ~finally:(fun () ->
      clear_parked ();
      Processing.register_backend Processing.default_backend)
    (fun () ->
      Processing.register_backend backend;
      f ())

let with_http_backend backend f =
  Fun.protect
    ~finally:(fun () ->
      clear_parked ();
      Nopal_http.register_backend Nopal_http.default_backend)
    (fun () ->
      Nopal_http.register_backend backend;
      f ())

let image_backend ~calls ~outcome =
  {
    Processing.process =
      (fun ~blob_id ~config ->
        calls := (blob_id, config) :: !calls;
        Nopal_mvu.Task.from_callback (fun resolve ->
            park (fun () -> resolve outcome)));
  }

let http_backend ~requests ~outcome =
  {
    Nopal_http.send =
      (fun request ->
        requests := request :: !requests;
        Nopal_mvu.Task.from_callback (fun resolve ->
            park (fun () -> resolve outcome)));
  }

(* What the preview stub was asked to do, in the order it was asked. One ordered
   ledger rather than two lists, because what a caller replacing one picture with
   another owes is that the release happens BEFORE the request that replaces it -
   and an order is not recoverable from two membership lists. *)
type preview_event = Requested of string | Revoked of string

(* The preview deliveries park on a queue of their own rather than the one
   above. A single queue drained to quiescence answers these inside the same
   drain that answers the processing pass, and the state between those two
   answers - two URLs asked for, neither arrived - is precisely what this
   section has to be able to report. *)
let preview_pending : (unit -> unit) Queue.t = Queue.create ()

(* Newest first while it is being built; the readers below put it back in the
   order the calls happened. *)
let preview_events : preview_event list ref = ref []

(* Mutable: how many URLs the stub has minted, so that every mint is a distinct
   string. The store this stands in for mints a separate URL per call, so a stub
   answering the same string twice would let a section that released one of two
   mints look as though it had released both. *)
let preview_mints = ref 0

let drain_previews () =
  let rec loop steps =
    match Queue.take_opt preview_pending with
    | None -> ()
    | Some deliver ->
        (match steps < drain_limit with
        | true -> ()
        | false -> Alcotest.fail "the parked preview deliveries never ran out");
        deliver ();
        loop (steps + 1)
  in
  loop 0

(* Exactly one delivery, oldest first, so a case can look at the section holding
   half a pair. *)
let deliver_next_preview () =
  match Queue.take_opt preview_pending with
  | None -> Alcotest.fail "no preview delivery is parked"
  | Some deliver -> deliver ()

(* The URL the stub mints on its [mint]th call. Named here rather than written
   out at each call site, so a case can name the particular URL a section ought
   to have released without restating the stub's format. *)
let stub_url ~blob_id ~mint = Printf.sprintf "blob:stub/%s/%d" blob_id mint

(* Handles the stub answers with a failure rather than a URL, scripted per case.
   Failing by handle rather than by call number is what lets a case fail one half
   of a pair and let the other half through, which is the state a section can
   only reach when a picture it is showing has no twin to be shown beside. *)
let preview_failures : (string * Preview.error) list ref = ref []

(* A total fold rather than [List.assoc], which raises on a handle nothing was
   scripted for - and most calls are for handles nothing was scripted for. *)
let rec scripted_failure ~blob_id failures =
  match failures with
  | [] -> None
  | (handle, error) :: rest -> (
      match String.equal handle blob_id with
      | true -> Some error
      | false -> scripted_failure ~blob_id rest)

(* The request is recorded in the [Task.from_callback] body rather than in the
   body of [url]. The seam builds its task when the COMMAND is built and runs
   that body when the command is EXECUTED, while a release is a [Cmd.perform]
   whose thunk also runs at execution; recording both at execution time is what
   makes the ledger above one order rather than a mixture of two clocks. The
   closure this body parks - [fun () -> resolve ...] - is a third clock again,
   DELIVERY, and is deliberately not where the ledger is written. Recording at
   execution is also what the platform backend does, where the URL is minted
   inside the task rather than while it is being built.

   A scripted failure mints nothing, which is what the platform does too: there
   is no URL to hand over and therefore none to release. That is what makes the
   mint counter readable as "URLs that exist" in a case where one half of the
   pair failed. *)
let preview_backend =
  {
    Preview.url =
      (fun ~blob_id ->
        Nopal_mvu.Task.from_callback (fun resolve ->
            preview_events := Requested blob_id :: !preview_events;
            match scripted_failure ~blob_id !preview_failures with
            | Some error ->
                Queue.add (fun () -> resolve (Error error)) preview_pending
            | None ->
                preview_mints := !preview_mints + 1;
                let url = stub_url ~blob_id ~mint:!preview_mints in
                Queue.add (fun () -> resolve (Ok url)) preview_pending));
    revoke = (fun ~url -> preview_events := Revoked url :: !preview_events);
  }

(* Written as total folds so nothing here reaches for a partial list function to
   read what the section asked the seam for. *)
let rec requested_handles events =
  match events with
  | [] -> []
  | Requested blob_id :: rest -> blob_id :: requested_handles rest
  | Revoked _ :: rest -> requested_handles rest

let preview_requests () = requested_handles (List.rev !preview_events)

let rec revoked_of events =
  match events with
  | [] -> []
  | Revoked url :: rest -> url :: revoked_of rest
  | Requested _ :: rest -> revoked_of rest

let revoked_urls () = revoked_of (List.rev !preview_events)

(* Written as a total fold for the same reason as the readers above. A URL
   released twice would make a count of releases read as a release that never
   happened, so a case counting what is still out has to be able to tell how many
   distinct URLs were let go. *)
let rec distinct values =
  match values with
  | [] -> []
  | value :: rest ->
      value
      :: distinct
           (List.filter (fun other -> not (String.equal other value)) rest)

(* The whole ledger in the order the calls happened, requests and releases in one
   list. What a section replacing one picture with another owes is that the
   release happens BEFORE the request that replaces it, and that is a claim about
   order which two membership lists cannot make. *)
let ledger_entry = function
  | Requested blob_id -> "requested:" ^ blob_id
  | Revoked url -> "revoked:" ^ url

let preview_ledger () = List.map ledger_entry (List.rev !preview_events)

(* Installs the stub for the duration of [f] and restores the default afterwards,
   so a failing assertion cannot leak it into the next case, and drops whatever
   it had parked for the same reason. The ledger is reset on the way IN rather
   than on the way out, so a case can read what the section asked for after the
   exchange it was asked during has closed. *)
let with_preview_backend f =
  Queue.clear preview_pending;
  preview_events := [];
  preview_mints := 0;
  preview_failures := [];
  Fun.protect
    ~finally:(fun () ->
      Queue.clear preview_pending;
      Preview.register_backend Preview.default_backend)
    (fun () ->
      Preview.register_backend preview_backend;
      f ())

let single_message rendered =
  match messages rendered with
  | [ msg ] -> msg
  | [] -> Alcotest.fail "the interaction dispatched no message"
  | _ :: _ :: _ ->
      Alcotest.fail "the interaction dispatched more than one message"

(* The section driven the way the runtime drives it: a message is folded through
   [update] and the command it returns is executed, with whatever that command
   dispatches folded straight back in. Returns the cell holding the current
   model along with the send function, so a case can look at the model in the
   window between a dispatch and the drain that answers it. *)
let driver model =
  let current = ref model in
  let rec send msg =
    let next, cmd = Sub.update !current msg in
    current := next;
    Nopal_mvu.Cmd.execute send cmd
  in
  (current, send)

(* Whether a processing pass has answered, either way. Used to pin that the fake
   really did defer: a section that already holds a result before the drain is a
   fake that answered before it returned. *)
let pass_answered model =
  let fragments = Sub.serialize_model model in
  Test_util.string_contains fragments ~sub:"processing=ready;"
  || Test_util.string_contains fragments ~sub:"processing=failed:"

(* Renders [model], simulates a selection against the picker, folds the
   dispatched message through [update], runs the command that produced against a
   recording backend, then lets the backend answer. The backend is installed
   before [update] because [Processing.process] reads it when the command is
   BUILT, not when it runs. Returns every backend call and the model after the
   whole exchange. *)
let select_and_run ~outcome files model =
  let calls = ref [] in
  let rendered = render (Sub.view vp model) in
  Alcotest.(check (result unit Test_util.error_testable))
    "the selection is simulated on the view" (Ok ())
    (select_files picker files rendered);
  let msg = single_message rendered in
  let current, send = driver model in
  with_preview_backend (fun () ->
      with_image_backend (image_backend ~calls ~outcome) (fun () ->
          send msg;
          Alcotest.(check bool)
            "the pass has not answered before the drain" false
            (pass_answered !current);
          drain ()));
  (!calls, !current)

let model0 () = fst (Sub.init ())
let rendered_tree model = tree (render (Sub.view vp model))

let present selector model =
  Option.is_some (find selector (rendered_tree model))

let metadata_text model =
  match find metadata (rendered_tree model) with
  | Some node -> text_content node
  | None ->
      Alcotest.fail "the receipt metadata element is missing from the view"

let shows model ~sub = Test_util.string_contains (metadata_text model) ~sub
let serialized model = Sub.serialize_model model

(* The section renders its own subtree and the kitchen sink wraps it in the
   anchor the browser specs scope themselves to, so what has to be pinned here
   is that each control is rendered at all - and that the picker is configured
   the way this section says it is. Those three attributes are its whole
   configuration: images only, the rear camera, and one photo at a time. None of
   them reaches the model, so nothing else in either suite would notice a picker
   that started asking for the front camera or taking a folder full of files. *)
let test_section_renders_its_configured_picker () =
  let idle = model0 () in
  Alcotest.(check bool) "the picker is rendered" true (present picker idle);
  Alcotest.(check bool)
    "the metadata readout is rendered" true (present metadata idle);
  Alcotest.(check bool)
    "the picker carries a visible label as well as an accessible one" true
    (Test_util.string_contains
       (text_content (rendered_tree idle))
       ~sub:"Receipt photo");
  match find picker (rendered_tree idle) with
  | None -> Alcotest.fail "the receipt picker is missing from the view"
  | Some node ->
      Alcotest.(check (option string))
        "the picker accepts images only" (Some "image/*") (attr "accept" node);
      Alcotest.(check (option string))
        "the picker asks for the rear camera" (Some "environment")
        (attr "capture" node);
      Alcotest.(check (option string))
        "the picker takes one photo at a time" (Some "false")
        (attr "multiple" node);
      Alcotest.(check (option string))
        "and keeps its accessible name" (Some "Receipt photo")
        (attr "aria-label" node)

(* The whole point of the section: picking a photo asks the registered backend
   to process THAT handle under the section's own capture parameters. Each
   parameter is asserted by value because they are all deliberately different
   from [Config.recommended] — a section that dropped its own parameters and
   inherited the preset would be visible here rather than passing silently. *)
let test_selection_triggers_processing () =
  let calls, _ =
    select_and_run
      ~outcome:(Ok (processed_info ~sharpness:41.5))
      [ receipt ] (model0 ())
  in
  match calls with
  | [] -> Alcotest.fail "the selection never reached the image backend"
  | calls ->
      List.iter
        (fun (blob_id, config) ->
          Alcotest.(check string)
            "the picked handle reaches the backend" "blob-receipt-1" blob_id;
          Alcotest.(check int)
            "the section's stored long edge reaches the backend" 1400
            (Config.max_edge config);
          Alcotest.(check int)
            "the section's metric long edge reaches the backend" 700
            (Config.metric_edge config);
          Alcotest.(check (float 0.))
            "the section's encoder quality reaches the backend" 0.75
            (Config.quality config);
          Alcotest.(check string)
            "the section's encoded form reaches the backend" "image/jpeg"
            (Config.format_to_mime (Config.format config)))
        calls

(* What the backend reported has to land in the model and on screen. The idle
   assertions are the affirmative arm: without them the ready assertions could
   be satisfied by a serializer that emits the dimensions unconditionally. *)
let test_metadata_recorded_in_model () =
  let idle = model0 () in
  Alcotest.(check bool)
    "an untouched section reports itself idle" true
    (Test_util.string_contains (serialized idle) ~sub:"processing=idle;");
  Alcotest.(check bool)
    "an untouched section carries no dimensions" false
    (Test_util.string_contains (serialized idle) ~sub:"width=");
  let _, ready =
    select_and_run
      ~outcome:(Ok (processed_info ~sharpness:41.5))
      [ receipt ] (model0 ())
  in
  let fragments = serialized ready in
  Alcotest.(check bool)
    "a processed receipt reports itself ready" true
    (Test_util.string_contains fragments ~sub:"processing=ready;");
  Alcotest.(check bool)
    "the processed width is recorded" true
    (Test_util.string_contains fragments ~sub:"width=1024;");
  Alcotest.(check bool)
    "the processed height is recorded" true
    (Test_util.string_contains fragments ~sub:"height=768;");
  (* Anchored on the left, unlike its two neighbours: [original_byte_size=] ends
     in [byte_size=], so a plain substring search for the processed length is
     satisfied by the picked photo's fragment whenever the two lengths coincide.
     The fixture's two lengths differ today, which is exactly what makes an
     unanchored assertion here a latent one rather than a failing one. *)
  Alcotest.(check bool)
    "the processed byte size is recorded" true
    (Test_util.contains_fragment fragments ~fragment:"byte_size=214007;");
  (* Render correctness of the readout the browser spec reads the dimensions
     out of. *)
  Alcotest.(check bool)
    "the readout shows the processed dimensions" true (shows ready ~sub:"1024");
  Alcotest.(check bool)
    "the readout shows the processed height" true (shows ready ~sub:"768");
  (* The focus score is the third thing the readout owes a person, and the only
     surface it has: the serializer deliberately emits what the score decided
     rather than the score, so the readout is where a measured number is
     visible at all. *)
  Alcotest.(check bool)
    "the readout shows the focus score the pass measured" true
    (shows ready ~sub:"41.5");
  (* And it stays off the telemetry, which is the reason it has to be on
     screen: a float rendering is not something a browser spec can assert on. *)
  Alcotest.(check bool)
    "the score does not reach the telemetry" false
    (Test_util.string_contains fragments ~sub:"41.5")

let model_after_failure error =
  let _, failed =
    select_and_run ~outcome:(Error error) [ receipt ] (model0 ())
  in
  failed

(* Every stage the pipeline can fail at, paired with the fragment that names it.
   The payloads are deliberately unlike each other so a serializer that leaked
   one in place of the constructor could not accidentally agree. *)
let processing_failures =
  [
    ( Processing.Blob_not_found "blob-receipt-1",
      "processing=failed:blob_not_found;" );
    (Processing.Decode_failed "not a JPEG", "processing=failed:decode_failed;");
    ( Processing.Canvas_unavailable "no 2d context on this surface",
      "processing=failed:canvas_unavailable;" );
    ( Processing.Pixel_read_failed "the surface was tainted",
      "processing=failed:pixel_read_failed;" );
    ( Processing.Encode_failed "the encoder refused the quality",
      "processing=failed:encode_failed;" );
  ]

(* The failure the browser spec drives with the truncated fixture. It has to
   name the decode stage specifically, and it must not leave the dimensions of
   whatever was processed before standing beside it. *)
let test_decode_failure_recorded () =
  let failed = model_after_failure (Processing.Decode_failed "not a JPEG") in
  let fragments = serialized failed in
  Alcotest.(check bool)
    "an undecodable receipt names the decode stage as the one that failed" true
    (Test_util.string_contains fragments ~sub:"processing=failed:decode_failed;");
  Alcotest.(check bool)
    "a failed pass carries no dimensions" false
    (Test_util.string_contains fragments ~sub:"width=");
  (* Render correctness: the reason has to reach the person looking at the
     section, not only the telemetry log. *)
  Alcotest.(check bool)
    "the readout explains why the pass failed" true
    (shows failed ~sub:"not a JPEG")

(* A spec that asserts one failure must not be satisfiable by any other. Each
   arm is checked to carry its own fragment AND to carry none of the others, so
   a scheme where one tag is a substring of another would be caught here rather
   than by a browser spec passing on the wrong failure. *)
let test_failure_arms_distinct () =
  List.iter
    (fun (error, tag) ->
      let fragments = serialized (model_after_failure error) in
      Alcotest.(check bool)
        (Printf.sprintf "%s is reported under its own tag" tag)
        true
        (Test_util.string_contains fragments ~sub:tag);
      processing_failures
      |> List.filter (fun (_, other) -> not (String.equal other tag))
      |> List.iter (fun (_, other) ->
          Alcotest.(check bool)
            (Printf.sprintf "%s is not also reported as %s" tag other)
            false
            (Test_util.string_contains fragments ~sub:other)))
    processing_failures

let ready_model ~sharpness =
  snd
    (select_and_run
       ~outcome:(Ok (processed_info ~sharpness))
       [ receipt ] (model0 ()))

let verdict_text model =
  match find verdict (rendered_tree model) with
  | Some node -> text_content node
  | None -> Alcotest.fail "the receipt verdict element is missing from the view"

(* Renders [model], clicks [selector], and folds the dispatched message back
   through [update], so a control that renders but dispatches nothing is a
   failure rather than a silently unchanged model. *)
let click_and_update selector model =
  let rendered = render (Sub.view vp model) in
  Alcotest.(check (result unit Test_util.error_testable))
    "the control is clickable" (Ok ()) (click selector rendered);
  fst (Sub.update model (single_message rendered))

(* The picker driven the way a browser drives it when the user drops the file
   they had chosen: the handler fires with an empty list rather than not firing
   at all. Renders [model] first so the message comes from the picker as it
   stands, not from a constructor written here. *)
let clear_message model =
  let rendered = render (Sub.view vp model) in
  Alcotest.(check (result unit Test_util.error_testable))
    "the picker is cleared on the view" (Ok ())
    (select_files picker [] rendered);
  single_message rendered

let clear_and_update model = fst (Sub.update model (clear_message model))

(* Two scores that straddle the section's demo threshold. They are written out
   rather than derived from the section's constant so this suite states the
   calibration it expects instead of restating whatever the section currently
   holds; moving the threshold past either of them is a deliberate change to
   what the demo claims, and it should have to be made here too. *)
let under_threshold = 2.75
let over_threshold = 19.5

(* The threshold itself, written out for the same reason and pinning the side of
   it that a score landing exactly on the line falls: the section reaches its
   verdict with a [>=] comparison, so the boundary belongs to the accept side,
   and a rewrite to a strict [>] would leave every other case in this suite
   identical. *)
let at_threshold = 6.0

(* A photo the section judges too soft has to say so, offer the re-shoot rather
   than the accept, and say out loud that the number it judged against is this
   demo's own calibration - the image library defines no such number. *)
let test_threshold_verdict_below () =
  Alcotest.(check bool)
    "an untouched section passes no verdict at all" false
    (Test_util.string_contains (serialized (model0 ())) ~sub:"sharpness_ok=");
  let below = ready_model ~sharpness:under_threshold in
  let fragments = serialized below in
  Alcotest.(check bool)
    "a photo under the threshold is reported as not sharp enough" true
    (Test_util.string_contains fragments ~sub:"sharpness_ok=false;");
  Alcotest.(check bool)
    "and is not also reported as sharp enough" false
    (Test_util.string_contains fragments ~sub:"sharpness_ok=true;");
  Alcotest.(check bool)
    "the re-shoot control is offered" true (present reshoot below);
  Alcotest.(check bool)
    "the accept control is not offered" false (present accept below);
  Alcotest.(check bool)
    "the verdict says which side of the threshold the photo fell" true
    (Test_util.string_contains (verdict_text below) ~sub:"Re-shoot");
  Alcotest.(check bool)
    "the verdict states that the threshold is this demo's own calibration" true
    (Test_util.string_contains (verdict_text below) ~sub:"demo calibration");
  (* A score that is not a number says nothing about the photo, and a comparison
     written the other way round - not below the threshold - would read that
     silence as a pass. It falls on the re-shoot side. *)
  let unmeasured = ready_model ~sharpness:Float.nan in
  Alcotest.(check bool)
    "an unmeasurable photo is not reported as sharp enough" true
    (Test_util.string_contains (serialized unmeasured)
       ~sub:"sharpness_ok=false;");
  Alcotest.(check bool)
    "an unmeasurable photo is offered the re-shoot" true
    (present reshoot unmeasured)

let test_threshold_verdict_above () =
  let above = ready_model ~sharpness:over_threshold in
  let fragments = serialized above in
  Alcotest.(check bool)
    "a photo over the threshold is reported as sharp enough" true
    (Test_util.string_contains fragments ~sub:"sharpness_ok=true;");
  Alcotest.(check bool)
    "and is not also reported as not sharp enough" false
    (Test_util.string_contains fragments ~sub:"sharpness_ok=false;");
  Alcotest.(check bool)
    "the accept control is offered" true (present accept above);
  Alcotest.(check bool)
    "the re-shoot control is not offered" false (present reshoot above);
  Alcotest.(check bool)
    "the verdict still names the threshold as demo calibration" true
    (Test_util.string_contains (verdict_text above) ~sub:"demo calibration")

(* A score landing exactly on the threshold. Neither case above sits on the
   line, so which side it falls on is a claim this section makes that nothing
   else here reads: "sharp enough" is stated as reaching the number, not as
   beating it, and a photo that reached it is offered the accept. *)
let test_threshold_boundary_is_accepted () =
  let exactly = ready_model ~sharpness:at_threshold in
  let fragments = serialized exactly in
  Alcotest.(check bool)
    "a photo scoring exactly the threshold is reported as sharp enough" true
    (Test_util.string_contains fragments ~sub:"sharpness_ok=true;");
  Alcotest.(check bool)
    "and is not also reported as not sharp enough" false
    (Test_util.string_contains fragments ~sub:"sharpness_ok=false;");
  Alcotest.(check bool)
    "the accept control is offered on the boundary" true
    (present accept exactly);
  Alcotest.(check bool)
    "the re-shoot control is not offered on the boundary" false
    (present reshoot exactly)

(* Re-shooting has to leave the section ready for another photo with nothing of
   the rejected one still on screen or in the telemetry - a stale readout beside
   a fresh picker is how a spec ends up asserting on the photo before last. *)
let test_reshoot_clears_result () =
  let below = ready_model ~sharpness:under_threshold in
  Alcotest.(check bool)
    "the rejected photo's readout is there to begin with" true
    (Test_util.string_contains (serialized below) ~sub:"width=1024;");
  let cleared = click_and_update reshoot below in
  let fragments = serialized cleared in
  Alcotest.(check bool)
    "re-shooting returns the section to its untouched stage" true
    (Test_util.string_contains fragments ~sub:"processing=idle;");
  Alcotest.(check bool)
    "the rejected photo's dimensions are gone" false
    (Test_util.string_contains fragments ~sub:"width=");
  Alcotest.(check bool)
    "the rejected photo's verdict is gone" false
    (Test_util.string_contains fragments ~sub:"sharpness_ok=");
  Alcotest.(check bool)
    "the readout no longer shows the rejected photo" false
    (shows cleared ~sub:"1024");
  Alcotest.(check bool)
    "the picker is still there to take another photo" true
    (present picker cleared)

(* A second photo taken while [model] is showing the first, delivered the way a
   replaced pick or a re-shoot delivers one: the section is rendered as it stands,
   the picker is driven again, and the new result is folded back in. *)
let photo_after ~sharpness model =
  snd
    (select_and_run ~outcome:(Ok (processed_info ~sharpness)) [ receipt ] model)

(* The first photo of a session has nothing behind it, so the section must claim
   no comparison at all rather than compare against a stand-in. The second half
   is the affirmative arm: it shows the same fixture can produce the fragment, so
   the absence above is the missing previous photo and not a serializer that
   never emits it. *)
let test_first_photo_has_no_comparison () =
  let first = ready_model ~sharpness:over_threshold in
  Alcotest.(check bool)
    "a first photo is compared against nothing" false
    (Test_util.string_contains (serialized first) ~sub:"sharper_than_previous=");
  let second = photo_after ~sharpness:under_threshold first in
  Alcotest.(check bool)
    "a second photo is compared against the first" true
    (Test_util.string_contains (serialized second) ~sub:"sharper_than_previous=")

(* The improving direction. Asserting the fragment is present is not enough: a
   serializer stuck on one answer satisfies one direction, which is why this
   case and the one below are both required and neither alone would do. *)
let test_second_photo_records_sharper () =
  let sharper =
    photo_after ~sharpness:over_threshold
      (ready_model ~sharpness:under_threshold)
  in
  let fragments = serialized sharper in
  Alcotest.(check bool)
    "a photo that scored better than the last one says so" true
    (Test_util.string_contains fragments ~sub:"sharper_than_previous=true;");
  Alcotest.(check bool)
    "and does not also say the opposite" false
    (Test_util.string_contains fragments ~sub:"sharper_than_previous=false;");
  (* A previous score the metric could not produce is still a previous score.
     Ordering it below every real one keeps the comparison total, and it is the
     case a rewrite to a bare float [>] gets wrong while leaving every other
     case identical. *)
  let after_unmeasured =
    photo_after ~sharpness:over_threshold (ready_model ~sharpness:Float.nan)
  in
  Alcotest.(check bool)
    "a measured photo scores better than an unmeasurable one" true
    (Test_util.string_contains
       (serialized after_unmeasured)
       ~sub:"sharper_than_previous=true;")

(* The degrading direction, which is what the sharp-then-blurred browser spec
   rests on. The equal-scores arm pins that "sharper" is strict: re-shooting a
   photo and getting the same score back is not an improvement. *)
let test_second_photo_records_not_sharper () =
  let softer =
    photo_after ~sharpness:under_threshold
      (ready_model ~sharpness:over_threshold)
  in
  let fragments = serialized softer in
  Alcotest.(check bool)
    "a photo that scored worse than the last one says so" true
    (Test_util.string_contains fragments ~sub:"sharper_than_previous=false;");
  Alcotest.(check bool)
    "and does not also say the opposite" false
    (Test_util.string_contains fragments ~sub:"sharper_than_previous=true;");
  let unchanged =
    photo_after ~sharpness:over_threshold
      (ready_model ~sharpness:over_threshold)
  in
  Alcotest.(check bool)
    "a photo that scored the same as the last one is not sharper than it" true
    (Test_util.string_contains (serialized unchanged)
       ~sub:"sharper_than_previous=false;")

(* Re-shooting is the whole reason the comparison exists: the user was told the
   photo was too soft and is taking another one to beat it. The rejected photo's
   readout has to go, which is pinned elsewhere in this suite, but its score has
   to stay, or the
   replacement has nothing to be measured against. Between the two the section
   claims no comparison, because it is holding no photo to compare. *)
let test_comparison_survives_a_reshoot () =
  let rejected = ready_model ~sharpness:under_threshold in
  let cleared = click_and_update reshoot rejected in
  Alcotest.(check bool)
    "a section holding no photo claims no comparison" false
    (Test_util.string_contains (serialized cleared)
       ~sub:"sharper_than_previous=");
  let replacement = photo_after ~sharpness:over_threshold cleared in
  Alcotest.(check bool)
    "the replacement is compared against the photo it replaced" true
    (Test_util.string_contains (serialized replacement)
       ~sub:"sharper_than_previous=true;")

(* A pass that failed measured nothing, so it is not the photo the next one
   should be judged against - the last one that actually produced a score is.
   Picking an unreadable file in the middle of a session must therefore not
   silently cost the section its comparison. *)
let test_comparison_survives_a_failed_pass () =
  let measured = ready_model ~sharpness:under_threshold in
  let failed =
    snd
      (select_and_run ~outcome:(Error (Processing.Decode_failed "not a JPEG"))
         [ receipt ] measured)
  in
  Alcotest.(check bool)
    "a section whose last pass failed claims no comparison" false
    (Test_util.string_contains (serialized failed) ~sub:"sharper_than_previous=");
  let recovered = photo_after ~sharpness:over_threshold failed in
  Alcotest.(check bool)
    "the next photo is compared against the last one that was measured" true
    (Test_util.string_contains (serialized recovered)
       ~sub:"sharper_than_previous=true;")

(* Two passes in flight at once, which is only reachable now that the fake
   answers on a later turn: a photo is picked and a second is picked before the
   first pass has answered, then both answer in the order they were started. The
   photo the second result is compared against is the one measured immediately
   before it, so a section that only remembered the photo it was holding when
   the picker was driven would claim no comparison at all here. *)
let queued_image_backend outcomes =
  let remaining = ref outcomes in
  {
    Processing.process =
      (fun ~blob_id:_ ~config:_ ->
        let outcome =
          match !remaining with
          | [] ->
              Error
                (Processing.Decode_failed
                   "the suite ran out of prepared results")
          | next :: rest ->
              remaining := rest;
              next
        in
        Nopal_mvu.Task.from_callback (fun resolve ->
            park (fun () -> resolve outcome)));
  }

let select_message files model =
  let rendered = render (Sub.view vp model) in
  Alcotest.(check (result unit Test_util.error_testable))
    "the selection is simulated on the view" (Ok ())
    (select_files picker files rendered);
  single_message rendered

let test_second_pass_in_flight_is_compared_to_the_first () =
  let current, send = driver (model0 ()) in
  with_image_backend
    (queued_image_backend
       [
         Ok (processed_info ~sharpness:under_threshold);
         Ok (processed_info ~sharpness:over_threshold);
       ])
    (fun () ->
      send (select_message [ receipt ] !current);
      send (select_message [ receipt ] !current);
      Alcotest.(check bool)
        "neither pass has answered before the drain" false
        (pass_answered !current);
      drain ());
  let fragments = Sub.serialize_model !current in
  Alcotest.(check bool)
    "the second result is compared against the first" true
    (Test_util.string_contains fragments ~sub:"sharper_than_previous=true;");
  Alcotest.(check bool)
    "and is not reported the other way round" false
    (Test_util.string_contains fragments ~sub:"sharper_than_previous=false;")

(* A backend that answers per handle rather than per call order, so a case can
   let the pass for the photo picked second come back before the pass for the
   photo picked first. A handle no result was prepared for answers with a
   failure rather than nothing, so a fixture that stopped reaching the backend
   could not read as a pass the section correctly discarded. *)
let handle_keyed_image_backend outcomes =
  {
    Processing.process =
      (fun ~blob_id ~config:_ ->
        let outcome =
          match List.assoc_opt blob_id outcomes with
          | Some outcome -> outcome
          | None ->
              Error
                (Processing.Decode_failed
                   "the suite prepared no result for this handle")
        in
        Nopal_mvu.Task.from_callback (fun resolve ->
            parked_by_handle :=
              !parked_by_handle @ [ (blob_id, fun () -> resolve outcome) ]));
  }

(* A backend that answers successive passes over ONE handle differently. The
   handle-keyed fixture above maps a handle to a single outcome, so two passes
   over the same photo always agree there - which is exactly the sequence it
   cannot drive: one pass succeeding and the next failing. Outcomes are taken in
   the order the passes were STARTED and parked under the handle they were
   started for, so a case still chooses the order they answer in. A pass beyond
   the prepared ones answers with a failure rather than nothing, so a fixture
   that stopped reaching the backend could not read as a pass the section
   correctly discarded. *)
let sequenced_image_backend outcomes =
  let remaining = ref outcomes in
  {
    Processing.process =
      (fun ~blob_id ~config:_ ->
        let outcome =
          match !remaining with
          | [] ->
              Error
                (Processing.Decode_failed
                   "the suite ran out of prepared results")
          | next :: rest ->
              remaining := rest;
              next
        in
        Nopal_mvu.Task.from_callback (fun resolve ->
            parked_by_handle :=
              !parked_by_handle @ [ (blob_id, fun () -> resolve outcome) ]));
  }

(* Clearing the picker is a first-class thing a user does - the browser fires
   the handler with an empty list rather than not firing at all - and it has to
   leave nothing of the cleared photo behind. The pre-clear assertions are the
   affirmative arm: without them the absences below would stay green even if the
   fixture had stopped reaching the readout in the first place. *)
let test_clearing_the_picker_returns_the_section_to_idle () =
  let ready = ready_model ~sharpness:over_threshold in
  Alcotest.(check bool)
    "the photo's readout is there to begin with" true
    (Test_util.string_contains (serialized ready) ~sub:"width=1024;");
  Alcotest.(check bool)
    "and its verdict with it" true
    (Test_util.string_contains (serialized ready) ~sub:"sharpness_ok=true;");
  Alcotest.(check bool)
    "and the control that would send it" true (present accept ready);
  let cleared = clear_and_update ready in
  let fragments = serialized cleared in
  Alcotest.(check bool)
    "clearing the picker returns the section to its untouched stage" true
    (Test_util.string_contains fragments ~sub:"processing=idle;");
  Alcotest.(check bool)
    "the cleared photo's dimensions are gone" false
    (Test_util.string_contains fragments ~sub:"width=");
  Alcotest.(check bool)
    "the cleared photo's verdict is gone" false
    (Test_util.string_contains fragments ~sub:"sharpness_ok=");
  Alcotest.(check bool)
    "the readout no longer shows the cleared photo" false
    (shows cleared ~sub:"1024");
  Alcotest.(check bool)
    "the cleared photo can no longer be sent" false (present accept cleared);
  Alcotest.(check bool)
    "the picker is still there to take another photo" true
    (present picker cleared)

(* The same clear, but with the pass still out when it happens. A result that
   lands on a section the user has emptied would put a readout and a working
   accept control under a picker holding nothing, which is a photo the user
   cancelled offered back for upload. *)
let test_clearing_the_picker_discards_a_pass_still_in_flight () =
  let current, send = driver (model0 ()) in
  with_image_backend
    (queued_image_backend [ Ok (processed_info ~sharpness:over_threshold) ])
    (fun () ->
      send (select_message [ receipt ] !current);
      send (clear_message !current);
      Alcotest.(check bool)
        "the clear leaves the section idle before the pass answers" true
        (Test_util.string_contains
           (Sub.serialize_model !current)
           ~sub:"processing=idle;");
      drain ());
  let fragments = Sub.serialize_model !current in
  Alcotest.(check bool)
    "the section is still idle once the cancelled pass answers" true
    (Test_util.string_contains fragments ~sub:"processing=idle;");
  Alcotest.(check bool)
    "the cancelled photo's dimensions do not appear" false
    (Test_util.string_contains fragments ~sub:"width=");
  Alcotest.(check bool)
    "nor its verdict" false
    (Test_util.string_contains fragments ~sub:"sharpness_ok=");
  Alcotest.(check bool)
    "and it is not offered for upload" false (present accept !current);
  (* The affirmative arm on the same fixture: a photo picked after the clear is
     measured and offered normally, so the absences above are the discarded
     pass and not a section that has stopped working. *)
  let recovered = photo_after ~sharpness:over_threshold !current in
  Alcotest.(check bool)
    "a photo picked after the clear is measured as usual" true
    (Test_util.string_contains (serialized recovered) ~sub:"width=1024;")

(* Two passes out at once, answering in the order a browser is free to answer
   them: the replacement's pass comes back first and the pass for the photo it
   replaced comes back last. That late result was measured for a photo the
   section has moved off, so recording it would show the earlier photo's
   dimensions and verdict beside a picker naming the later one - and would
   report the ordering contract this section exists to demonstrate backwards. *)
let test_a_late_pass_is_not_recorded_against_the_photo_that_replaced_it () =
  let current, send = driver (model0 ()) in
  with_image_backend
    (handle_keyed_image_backend
       [
         (receipt.E.blob_id, Ok (processed_info ~sharpness:over_threshold));
         ( other_receipt.E.blob_id,
           Ok (replacement_info ~sharpness:under_threshold) );
       ])
    (fun () ->
      send (select_message [ receipt ] !current);
      send (select_message [ other_receipt ] !current);
      answer_pass_for ~blob_id:other_receipt.E.blob_id;
      Alcotest.(check bool)
        "the replacement's own pass lands" true
        (Test_util.string_contains
           (Sub.serialize_model !current)
           ~sub:"width=1440;");
      answer_pass_for ~blob_id:receipt.E.blob_id);
  let fragments = Sub.serialize_model !current in
  Alcotest.(check bool)
    "the section still describes the photo the picker names" true
    (Test_util.string_contains fragments ~sub:"width=1440;");
  Alcotest.(check bool)
    "not the one it replaced" false
    (Test_util.string_contains fragments ~sub:"width=1024;");
  Alcotest.(check bool)
    "and reports the replacement's own verdict" true
    (Test_util.string_contains fragments ~sub:"sharpness_ok=false;");
  Alcotest.(check bool)
    "not the verdict of the photo it replaced" false
    (Test_util.string_contains fragments ~sub:"sharpness_ok=true;");
  Alcotest.(check bool)
    "the replacement is offered the re-shoot its own score earns it" true
    (present reshoot !current);
  Alcotest.(check bool)
    "and is not offered acceptance on the strength of the discarded pass" false
    (present accept !current);
  (* The discarded pass measured nothing this section holds, so there is no
     photo behind the replacement for it to be compared against. *)
  Alcotest.(check bool)
    "a discarded pass leaves nothing to be compared against" false
    (Test_util.string_contains fragments ~sub:"sharper_than_previous=");
  (* The affirmative arm on the same fixture: the next photo does produce the
     comparison, so the absence above is the discarded pass rather than a
     section that has stopped comparing at all. *)
  let next = photo_after ~sharpness:over_threshold !current in
  Alcotest.(check bool)
    "the photo after it is compared against the replacement" true
    (Test_util.string_contains (serialized next)
       ~sub:"sharper_than_previous=true;")

(* A note no constant written into the section could be mistaken for. *)
let note_value = "lunch with the team, 12 August"
let upload_reply status = Ok { Nopal_http.status; body = ""; headers = [] }

(* The whole flow the section exists to demonstrate, driven through the rendered
   controls at every step: pick a photo, let the processing pass answer, type a
   note, accept, and let the upload answer. The photo scores above the demo
   threshold because that is the only side of it on which the accept control is
   offered. Returns every request the section put on the wire, newest first, and
   the model the exchange left behind. *)
let capture_and_accept ~reply () =
  let calls = ref [] in
  let requests = ref [] in
  let current, send = driver (model0 ()) in
  let interact description simulate =
    let rendered = render (Sub.view vp !current) in
    Alcotest.(check (result unit Test_util.error_testable))
      description (Ok ()) (simulate rendered);
    send (single_message rendered)
  in
  with_image_backend
    (image_backend ~calls
       ~outcome:(Ok (processed_info ~sharpness:over_threshold)))
    (fun () ->
      with_http_backend (http_backend ~requests ~outcome:reply) (fun () ->
          interact "the photo is picked" (select_files picker [ receipt ]);
          drain ();
          interact "the note is typed" (input note note_value);
          interact "the receipt is accepted" (click accept);
          (* Nothing has answered yet, so this is the state a person is left
             looking at while the request is out - and the one the section must
             not still be in once it has. *)
          Alcotest.(check bool)
            "the upload is reported in flight before the reply arrives" true
            (Test_util.string_contains
               (Sub.serialize_model !current)
               ~sub:"upload=uploading;");
          drain ()));
  (!requests, !current)

let single_request requests =
  match requests with
  | [ request ] -> request
  | [] -> Alcotest.fail "accepting the receipt sent no request"
  | _ :: _ :: _ ->
      Alcotest.fail "accepting the receipt sent more than one request"

let multipart_parts (request : Nopal_http.request) =
  match request.Nopal_http.body with
  | Nopal_http.Multipart parts -> parts
  | Nopal_http.String _
  | Nopal_http.Json _
  | Nopal_http.Form_encoded _
  | Nopal_http.Empty ->
      Alcotest.fail "the upload did not send a multipart body"

(* The first file part's field name, handle, declared filename and declared
   type. Written as a total fold so nothing here reaches for a partial list
   function to read what the section put on the wire. *)
let rec file_part parts =
  match parts with
  | [] -> None
  | Nopal_http.File { name; blob_id; filename; mime } :: _ ->
      Some (name, blob_id, filename, mime)
  | Nopal_http.Field _ :: rest -> file_part rest

let rec field_part ~name parts =
  match parts with
  | [] -> None
  | Nopal_http.Field (field, value) :: rest -> (
      match String.equal field name with
      | true -> Some value
      | false -> field_part ~name rest)
  | Nopal_http.File _ :: rest -> field_part ~name rest

let upload_text model =
  match find upload_readout (tree (render (Sub.view vp model))) with
  | Some node -> text_content node
  | None -> Alcotest.fail "the receipt upload readout is missing from the view"

(* The mistake this leg of the feature exists to catch: sending the handle the
   picker produced rather than the one the processing pass produced would put
   the untouched original on the wire - full size, unmeasured - while the
   readout beside it describes the processed one. The declared name and type
   describe the re-encoded bytes for the same reason: they are what was
   actually sent. *)
let test_upload_sends_processed_handle () =
  let requests, final = capture_and_accept ~reply:(upload_reply 201) () in
  let request = single_request requests in
  (* The control the helper just clicked is gone once the receipt has been sent,
     which is what keeps a second click from sending the same receipt twice. *)
  Alcotest.(check bool)
    "the accept control is not offered again" false (present accept final);
  (match request.Nopal_http.meth with
  | Nopal_http.POST -> ()
  | Nopal_http.GET
  | Nopal_http.PUT
  | Nopal_http.DELETE
  | Nopal_http.PATCH ->
      Alcotest.fail "the upload must POST");
  Alcotest.(check string)
    "the upload names its own endpoint" "/api/receipt-capture"
    request.Nopal_http.url;
  (* A request with no deadline is the one way this section could be left
     reporting an upload that never comes back. *)
  Alcotest.(check bool)
    "the upload is given a deadline" true
    (Option.is_some request.Nopal_http.timeout);
  match file_part (multipart_parts request) with
  | None -> Alcotest.fail "the upload carried no file part"
  | Some (name, blob_id, filename, mime) ->
      Alcotest.(check string) "the file part's field name" "receipt" name;
      Alcotest.(check string)
        "the upload names the handle the processing pass produced"
        processed_handle blob_id;
      Alcotest.(check (option string))
        "the declared filename" (Some "receipt.jpg") filename;
      Alcotest.(check (option string))
        "the declared type is the one the section encoded to"
        (Some "image/jpeg") mime

(* The note is a plain string field beside the file, and it is the value the
   user typed rather than anything the section holds of its own. *)
let test_upload_includes_text_field () =
  Alcotest.(check bool)
    "the note field is rendered" true
    (present note (model0 ()));
  let requests, _ = capture_and_accept ~reply:(upload_reply 201) () in
  let parts = multipart_parts (single_request requests) in
  match field_part ~name:"note" parts with
  | None -> Alcotest.fail "the upload carried no note field"
  | Some value ->
      Alcotest.(check string)
        "the typed note travels with the upload" note_value value

(* The accept control is rendered in one stage only, so a section holding no
   measured photo never shows it - but [update] still has to answer the message,
   because a stage is not what stops a message arriving. Nothing was started, so
   nothing may go out and nothing may change. The affirmative arm for the
   request count is [test_upload_sends_processed_handle], which drives the same
   backend fixture through a stage that does offer the control and finds exactly
   one request on it. *)
let test_accepting_from_an_idle_section_starts_nothing () =
  let requests = ref [] in
  let idle = model0 () in
  let final = ref idle in
  with_http_backend
    (http_backend ~requests ~outcome:(upload_reply 201))
    (fun () ->
      let next, cmd = Sub.update idle Sub.Accept_clicked in
      final := next;
      Nopal_mvu.Cmd.execute
        (fun _ ->
          Alcotest.fail "accepting from an idle section dispatched a message")
        cmd;
      drain ());
  Alcotest.(check string)
    "an idle section is left exactly as it was" (Sub.serialize_model idle)
    (Sub.serialize_model !final);
  Alcotest.(check int) "and nothing reaches the wire" 0 (List.length !requests)

(* Every way the upload can end, paired with the fragment that names it. A
   browser spec reads these by substring, so an assertion aimed at one must not
   be satisfiable by any other: a refused handle and a refused request have
   different remedies, and a server that answered 404 did not store anything
   however completely the request went out. *)
let upload_outcomes =
  [
    (upload_reply 201, "upload=ok:201;");
    (upload_reply 404, "upload=rejected:404;");
    ( Error (Nopal_http.Network_error "connection refused"),
      "upload=error:network;" );
    (Error Nopal_http.Timeout, "upload=error:timeout;");
    ( Error (Nopal_http.Invalid_blob processed_handle),
      "upload=error:invalid_blob;" );
  ]

let test_upload_failure_arms_distinct () =
  let nothing_uploaded = upload_text (model0 ()) in
  List.iter
    (fun (reply, tag) ->
      let _, final = capture_and_accept ~reply () in
      let fragments = Sub.serialize_model final in
      Alcotest.(check bool)
        (Printf.sprintf "%s is reported under its own tag" tag)
        true
        (Test_util.string_contains fragments ~sub:tag);
      (* The other half of resolving exactly once: no reply may leave the
         section reporting a request that is still out. *)
      Alcotest.(check bool)
        (Printf.sprintf "%s does not leave the upload in flight" tag)
        false
        (Test_util.string_contains fragments ~sub:"upload=uploading;");
      Alcotest.(check bool)
        (Printf.sprintf "%s reaches the person looking at the section" tag)
        false
        (String.equal (upload_text final) nothing_uploaded);
      upload_outcomes
      |> List.filter (fun (_, other) -> not (String.equal other tag))
      |> List.iter (fun (_, other) ->
          Alcotest.(check bool)
            (Printf.sprintf "%s is not also reported as %s" tag other)
            false
            (Test_util.string_contains fragments ~sub:other)))
    upload_outcomes

(* An upload backend that answers one turn later than whatever was started after
   it, which is a thing a browser is free to do: the request went out first and
   comes back last. *)
let late_http_backend ~outcome =
  {
    Nopal_http.send =
      (fun _request ->
        Nopal_mvu.Task.from_callback (fun resolve ->
            park (fun () -> park (fun () -> resolve outcome))));
  }

(* A reply that arrives after the photo it belongs to has been replaced. The
   receipt it reports on is no longer the one on screen, so recording it against
   the replacement would show a photo as uploaded that was never sent - and the
   replacement's own accept control would be gone with it. *)
let test_late_reply_is_not_recorded_against_the_next_photo () =
  let calls = ref [] in
  let current, send = driver (model0 ()) in
  let interact description simulate =
    let rendered = render (Sub.view vp !current) in
    Alcotest.(check (result unit Test_util.error_testable))
      description (Ok ()) (simulate rendered);
    send (single_message rendered)
  in
  with_image_backend
    (image_backend ~calls
       ~outcome:(Ok (processed_info ~sharpness:over_threshold)))
    (fun () ->
      with_http_backend
        (late_http_backend ~outcome:(upload_reply 201))
        (fun () ->
          interact "the photo is picked" (select_files picker [ receipt ]);
          drain ();
          interact "the receipt is accepted" (click accept);
          (* Picked while the request is still out. Both answer in the drain
             below, the replacement's pass first. *)
          interact "another photo is picked" (select_files picker [ receipt ]);
          drain ()));
  let fragments = Sub.serialize_model !current in
  Alcotest.(check bool)
    "the replacement has been measured" true
    (Test_util.string_contains fragments ~sub:"processing=ready;");
  Alcotest.(check bool)
    "and is waiting to be sent rather than reported as sent" true
    (Test_util.string_contains fragments ~sub:"upload=idle;");
  Alcotest.(check bool)
    "the earlier receipt's reply is not recorded against it" false
    (Test_util.string_contains fragments ~sub:"upload=ok:201;");
  Alcotest.(check bool)
    "the replacement can still be accepted" true (present accept !current)

(* The pair the section owes a reviewer is the photo that was picked beside the
   photo that will be sent, so a pass that succeeded has to ask the seam for a
   URL naming each of the two handles. The processed handle is the one every
   later step of the flow uses, which is exactly why an implementation drifts
   towards asking for it twice; the ledger is compared as a whole so that
   asking twice, asking once, or asking in the other order is a failure rather
   than a pass on a membership check. *)
let test_previews_requested_for_both_ids () =
  let _, ready =
    select_and_run
      ~outcome:(Ok (processed_info ~sharpness:over_threshold))
      [ receipt ] (model0 ())
  in
  Alcotest.(check bool)
    "the pass whose handles are being previewed did complete" true
    (Test_util.string_contains (serialized ready) ~sub:"processing=ready;");
  Alcotest.(check (list string))
    "the section asks for the picked photo and the processed photo, in that \
     order"
    [ receipt.E.blob_id; processed_handle ]
    (preview_requests ())

(* Where the pair stands is its own vocabulary and it has to move. The untouched
   section is the affirmative arm for the two absences below: without it a
   serializer that never emitted the fragment at all would satisfy every "not
   ready" and "not pending" assertion here. *)
let test_previews_fragment_pending_then_ready () =
  let untouched = serialized (model0 ()) in
  Alcotest.(check bool)
    "an untouched section holds no previews" true
    (Test_util.string_contains untouched ~sub:"previews=none;");
  Alcotest.(check bool)
    "and does not claim a pair" false
    (Test_util.string_contains untouched ~sub:"previews=ready;");
  let current, send = driver (model0 ()) in
  with_preview_backend (fun () ->
      with_image_backend
        (image_backend ~calls:(ref [])
           ~outcome:(Ok (processed_info ~sharpness:over_threshold)))
        (fun () ->
          send (select_message [ receipt ] !current);
          drain ();
          let asked = Sub.serialize_model !current in
          Alcotest.(check bool)
            "a section whose URLs are still out reports them pending" true
            (Test_util.string_contains asked ~sub:"previews=pending;");
          Alcotest.(check bool)
            "and does not report a pair it has not got" false
            (Test_util.string_contains asked ~sub:"previews=ready;");
          (* Half a pair is not a pair. Without this the fragment could turn
             over on the first URL to arrive and every other assertion here
             would still pass. *)
          deliver_next_preview ();
          let half = Sub.serialize_model !current in
          Alcotest.(check bool)
            "one URL of the two leaves the pair pending" true
            (Test_util.string_contains half ~sub:"previews=pending;");
          Alcotest.(check bool)
            "and is not reported as a pair" false
            (Test_util.string_contains half ~sub:"previews=ready;");
          drain_previews ();
          let both = Sub.serialize_model !current in
          Alcotest.(check bool)
            "once both URLs arrive the section reports the pair ready" true
            (Test_util.string_contains both ~sub:"previews=ready;");
          Alcotest.(check bool)
            "and no longer reports them pending" false
            (Test_util.string_contains both ~sub:"previews=pending;");
          (* The URLs themselves are runtime values no spec could name in
             advance, so they stay out of the telemetry entirely. *)
          Alcotest.(check bool)
            "the URLs do not reach the telemetry" false
            (Test_util.string_contains both ~sub:"blob:stub/")))

(* The message a rendered control dispatches, handed back rather than folded in,
   so a case that has to put several steps on one clock can send it through the
   driver it is already using. *)
let click_message selector model =
  let rendered = render (Sub.view vp model) in
  Alcotest.(check (result unit Test_util.error_testable))
    "the control is clickable" (Ok ()) (click selector rendered);
  single_message rendered

(* The section driven through several photos with ONE preview backend installed
   for the whole of it, so the ledger spans every step. [select_and_run] installs
   and resets the stub per selection, which is what makes it useless for a case
   about replacing one pair with another. Every photo scores under the demo
   threshold, because that is the side of it on which the re-shoot control is
   offered. Returns the model the whole exchange left behind; the ledger is read
   afterwards, since the fixture resets it on the way in rather than out. *)
let preview_session f =
  let current, send = driver (model0 ()) in
  with_preview_backend (fun () ->
      with_image_backend
        (image_backend ~calls:(ref [])
           ~outcome:(Ok (processed_info ~sharpness:under_threshold)))
        (fun () -> f ~current ~send));
  !current

(* One photo carried all the way through: picked, measured, and both URLs
   arrived. *)
let take_a_photo ~current ~send =
  send (select_message [ receipt ] !current);
  drain ();
  drain_previews ()

let showing_a_pair model =
  Test_util.string_contains (Sub.serialize_model model) ~sub:"previews=ready;"

(* Each call to the seam mints a URL of its own, so a section that replaces a
   pair owes two releases rather than one - and it owes them BEFORE it asks for
   the pair that replaces them, or a re-shoot loop holds every picture it has
   ever shown. The whole ledger is compared as one ordered list because that
   before is the property: releasing after the new request, or releasing only one
   of the two, satisfies every membership check that could be written instead. *)
let test_reshoot_revokes_before_requesting () =
  let final =
    preview_session (fun ~current ~send ->
        take_a_photo ~current ~send;
        Alcotest.(check bool)
          "the section is holding a pair before it replaces one" true
          (showing_a_pair !current);
        send (click_message reshoot !current);
        take_a_photo ~current ~send)
  in
  Alcotest.(check bool)
    "the replacement's own pair is shown once the re-shoot has been through"
    true (showing_a_pair final);
  Alcotest.(check (list string))
    "both URLs are released before either replacement is asked for"
    [
      "requested:" ^ receipt.E.blob_id;
      "requested:" ^ processed_handle;
      "revoked:" ^ stub_url ~blob_id:receipt.E.blob_id ~mint:1;
      "revoked:" ^ stub_url ~blob_id:processed_handle ~mint:2;
      "requested:" ^ receipt.E.blob_id;
      "requested:" ^ processed_handle;
    ]
    (preview_ledger ())

(* The re-shoot loop the feature exists to survive. A URL pins the picture it
   names for as long as it is held and nothing in the browser reports how many
   are out, so this count at the seam is the only place the leak is observable at
   all: three photos mint six URLs, and a section that releases what it replaces
   is holding the last two of them and nothing else. *)
let test_reshoot_loop_leak_count () =
  let final =
    preview_session (fun ~current ~send ->
        List.iter (fun (_ : int) -> take_a_photo ~current ~send) [ 1; 2; 3 ])
  in
  Alcotest.(check bool)
    "the section ends the loop showing a pair" true (showing_a_pair final);
  Alcotest.(check int) "three photos mint two URLs each" 6 !preview_mints;
  let released = revoked_urls () in
  Alcotest.(check int)
    "every URL but the pair on screen has been released" 4
    (List.length released);
  (* A URL released twice would make the count above read as a release that never
     happened, so the releases have to be distinct as well as numerous. *)
  Alcotest.(check int)
    "and no URL is released twice" 4
    (List.length (distinct released));
  Alcotest.(check int)
    "which leaves exactly the pair the section is showing still out" 2
    (!preview_mints - List.length released)

(* A URL minted for a pair the user has already moved off. It arrives a turn or
   more after it was asked for, so a re-shoot taken while both were still out
   leaves two deliveries in flight for a pair nothing is going to show. They pin
   their pictures exactly as a shown URL does, so they are released as they
   arrive rather than dropped - and they are not written over the pair the
   section is actually waiting for, which is what the generation is for. *)
let test_superseded_url_revoked_on_arrival () =
  let stale_original = stub_url ~blob_id:receipt.E.blob_id ~mint:1 in
  let stale_processed = stub_url ~blob_id:processed_handle ~mint:2 in
  let final =
    preview_session (fun ~current ~send ->
        send (select_message [ receipt ] !current);
        drain ();
        (* Re-shot while both URLs are still out, so the replacement's own pair
           is asked for with two deliveries from the abandoned one parked ahead
           of it. *)
        send (click_message reshoot !current);
        send (select_message [ receipt ] !current);
        drain ();
        deliver_next_preview ();
        deliver_next_preview ();
        let after_stale = Sub.serialize_model !current in
        Alcotest.(check bool)
          "the superseded pair leaves the section still waiting for its own"
          true
          (Test_util.string_contains after_stale ~sub:"previews=pending;");
        Alcotest.(check bool)
          "so it does not report a pair it never received" false
          (Test_util.string_contains after_stale ~sub:"previews=ready;");
        Alcotest.(check (list string))
          "and both superseded URLs are released as they arrive"
          [ stale_original; stale_processed ]
          (revoked_urls ());
        drain_previews ())
  in
  Alcotest.(check bool)
    "the pair the section actually asked for still arrives" true
    (showing_a_pair final);
  Alcotest.(check int)
    "and nothing beyond the superseded pair is released" 2
    (List.length (revoked_urls ()));
  Alcotest.(check int)
    "which leaves exactly the pair on screen still out" 2
    (!preview_mints - List.length (revoked_urls ()))

(* Clearing the picker reaches the same reset by a different arm, and a section
   that released a replaced pair but not a cleared one would hold two URLs for a
   picture it is no longer showing anything of. *)
let test_clearing_the_picker_releases_the_pair () =
  let final =
    preview_session (fun ~current ~send ->
        take_a_photo ~current ~send;
        Alcotest.(check bool)
          "the section is holding a pair before the picker is cleared" true
          (showing_a_pair !current);
        send (clear_message !current))
  in
  Alcotest.(check bool)
    "a cleared picker leaves no pair behind" true
    (Test_util.string_contains
       (Sub.serialize_model final)
       ~sub:"previews=none;");
  Alcotest.(check (list string))
    "and releases both URLs it was holding"
    [
      stub_url ~blob_id:receipt.E.blob_id ~mint:1;
      stub_url ~blob_id:processed_handle ~mint:2;
    ]
    (revoked_urls ());
  Alcotest.(check int)
    "leaving nothing out at all" 0
    (!preview_mints - List.length (revoked_urls ()))

(* Two passes started for the one picked photo, both of which the section
   records - and the second one replaces the pair the first asked for. A URL of
   that first pair has already been handed over by then, so this is the arm that
   lets a pair go without the picker having changed at all: neither a re-shoot
   nor a clear reaches it. The ledger is compared in full because the release has
   to happen before the replacement is asked for here too, and because the second
   of the abandoned URLs arrives afterwards and is released on arrival. *)
let test_a_second_pass_releases_the_pair_it_replaces () =
  let current, send = driver (model0 ()) in
  with_preview_backend (fun () ->
      with_image_backend
        (handle_keyed_image_backend
           [
             (receipt.E.blob_id, Ok (processed_info ~sharpness:under_threshold));
           ])
        (fun () ->
          send (select_message [ receipt ] !current);
          send (select_message [ receipt ] !current);
          answer_pass_for ~blob_id:receipt.E.blob_id;
          (* One of the first pair's two URLs arrives before the second pass
             answers, so the section is holding half a pair at the moment that
             pair is replaced. *)
          deliver_next_preview ();
          answer_pass_for ~blob_id:receipt.E.blob_id;
          drain_previews ()));
  Alcotest.(check bool)
    "the section ends up showing the pair the second pass asked for" true
    (showing_a_pair !current);
  Alcotest.(check (list string))
    "the URL the replaced pair was holding is released before the replacement \
     is asked for, and its late twin as it arrives"
    [
      "requested:" ^ receipt.E.blob_id;
      "requested:" ^ processed_handle;
      "revoked:" ^ stub_url ~blob_id:receipt.E.blob_id ~mint:1;
      "requested:" ^ receipt.E.blob_id;
      "requested:" ^ processed_handle;
      "revoked:" ^ stub_url ~blob_id:processed_handle ~mint:2;
    ]
    (preview_ledger ());
  Alcotest.(check int)
    "which leaves exactly the pair on screen still out" 2
    (!preview_mints - List.length (revoked_urls ()))

(* One photo carried all the way through a pass that succeeded, with the seam
   scripted to refuse a URL for the named handles. The processing backend answers
   first and answers well, so what this leaves behind is a section that has
   decoded, scaled, re-encoded and measured a photo and cannot show it - which is
   the whole of what the failure arm has to leave standing. *)
let photo_with_failing_previews ~failures ~sharpness =
  let current, send = driver (model0 ()) in
  with_preview_backend (fun () ->
      preview_failures := failures;
      with_image_backend
        (image_backend ~calls:(ref [])
           ~outcome:(Ok (processed_info ~sharpness)))
        (fun () ->
          send (select_message [ receipt ] !current);
          drain ();
          drain_previews ()));
  !current

(* A URL that could not be minted says nothing about the photo it was asked for:
   that photo was decoded, scaled, re-encoded and measured before anything asked
   to show it. So the failure lands in the preview vocabulary and leaves every
   other readout where the pass left it - the control that sends the receipt
   included, which a section reporting a processing failure would not be offering
   at all. *)
let test_preview_failure_preserves_processed () =
  let failed =
    photo_with_failing_previews
      ~failures:
        [
          ( receipt.E.blob_id,
            Preview.Blob_not_found "the store holds no entry under that handle"
          );
        ]
      ~sharpness:over_threshold
  in
  let fragments = serialized failed in
  (* The affirmative arms for the absences below. Without them a fixture that
     stopped reaching the pass at all would satisfy every "not a failure" check
     here while pinning nothing. *)
  Alcotest.(check bool)
    "the pass is still reported as complete" true
    (Test_util.string_contains fragments ~sub:"processing=ready;");
  Alcotest.(check bool)
    "with the dimensions it stored" true
    (Test_util.string_contains fragments ~sub:"width=1024;");
  Alcotest.(check bool)
    "and the verdict its score earned" true
    (Test_util.string_contains fragments ~sub:"sharpness_ok=true;");
  Alcotest.(check bool)
    "the upload is still waiting to be started" true
    (Test_util.string_contains fragments ~sub:"upload=idle;");
  Alcotest.(check bool)
    "and the control that starts it is still offered" true
    (present accept failed);
  Alcotest.(check bool)
    "the picture that could not be shown is reported as such" true
    (Test_util.string_contains fragments ~sub:"previews=failed:blob_not_found;");
  Alcotest.(check bool)
    "a preview that failed is not reported as a processing failure" false
    (Test_util.string_contains fragments ~sub:"processing=failed:");
  Alcotest.(check bool)
    "nor as a pair the section can show" false
    (Test_util.string_contains fragments ~sub:"previews=ready;");
  Alcotest.(check bool)
    "nor as one still on its way" false
    (Test_util.string_contains fragments ~sub:"previews=pending;");
  (* The twin of the picture that failed arrives after the pair has already
     failed and has nothing to be shown beside. It pins its photo exactly as a
     shown URL does, so it is released rather than held for the session. *)
  Alcotest.(check int) "the other half of the pair was minted" 1 !preview_mints;
  Alcotest.(check (list string))
    "and released as it arrived to a pair that had already failed"
    [ stub_url ~blob_id:processed_handle ~mint:1 ]
    (revoked_urls ())

(* Every way a URL can fail to be minted, paired with the fragment that names it.
   The payloads are deliberately unlike each other so a serializer leaking one in
   place of the constructor could not accidentally agree. *)
let preview_failures_tagged =
  [
    ( Preview.Blob_not_found "the store holds no entry under that handle",
      "previews=failed:blob_not_found;" );
    ( Preview.Url_unavailable "this platform mints no displayable URL",
      "previews=failed:url_unavailable;" );
    ( Preview.Backend_unregistered "no backend was registered at mount",
      "previews=failed:backend_unregistered;" );
  ]

(* A spec that asserts one preview failure must not be satisfiable by any other:
   a handle nothing is stored under, a platform that mints no URLs and an
   application that forgot to register a backend have three different remedies.
   Each arm is checked to carry its own fragment AND none of the others, so a
   scheme where one tag is a substring of another is caught here. *)
let test_preview_failure_fragment_tagged () =
  List.iter
    (fun (error, tag) ->
      let fragments =
        serialized
          (photo_with_failing_previews
             ~failures:[ (receipt.E.blob_id, error) ]
             ~sharpness:over_threshold)
      in
      Alcotest.(check bool)
        (Printf.sprintf "%s is reported under its own tag" tag)
        true
        (Test_util.string_contains fragments ~sub:tag);
      preview_failures_tagged
      |> List.filter (fun (_, other) -> not (String.equal other tag))
      |> List.iter (fun (_, other) ->
          Alcotest.(check bool)
            (Printf.sprintf "%s is not also reported as %s" tag other)
            false
            (Test_util.string_contains fragments ~sub:other)))
    preview_failures_tagged

(* One half of a pair can arrive before the other fails. The arm that records a
   failure keeps no URL at all, so unless the transition into it releases what it
   is discarding, the half that did arrive is lost to every release path the
   section has - each of them reads the arm, and the arm has forgotten it. *)
let test_a_failure_releases_the_half_pair_it_discards () =
  let arrived = stub_url ~blob_id:receipt.E.blob_id ~mint:1 in
  let failed =
    photo_with_failing_previews
      ~failures:
        [
          ( processed_handle,
            Preview.Url_unavailable "this platform mints no displayable URL" );
        ]
      ~sharpness:under_threshold
  in
  Alcotest.(check bool)
    "the pair is reported as failed" true
    (Test_util.string_contains (serialized failed)
       ~sub:"previews=failed:url_unavailable;");
  Alcotest.(check int) "the half that did arrive was minted" 1 !preview_mints;
  Alcotest.(check (list string))
    "and is released as the failure discards it" [ arrived ] (revoked_urls ());
  Alcotest.(check int)
    "which leaves nothing at all still out" 0
    (!preview_mints - List.length (revoked_urls ()))

(* Both halves refused, and refused differently. The arm carries one reason, so
   one of the two is what the section reports - and which one is a rule the
   module owes a reader, because the whole point of having three distinct tags is
   that an assertion aimed at one reason is not satisfiable by another. The rule
   is first-wins: the failure that arrives first is the one that moves the arm,
   and the second lands on a pair that has already failed and is dropped. The two
   halves are asked for in the order they are shown, so here that is the picked
   photo's reason. *)
let test_a_pair_failing_both_ways_reports_the_first () =
  let failed =
    photo_with_failing_previews
      ~failures:
        [
          ( receipt.E.blob_id,
            Preview.Blob_not_found "the store holds no entry under that handle"
          );
          ( processed_handle,
            Preview.Url_unavailable "this platform mints no displayable URL" );
        ]
      ~sharpness:over_threshold
  in
  (* The affirmative arm: both halves really were asked for, so the single tag
     below is the section choosing one of two failures rather than the fixture
     having produced only one. *)
  Alcotest.(check (list string))
    "both halves of the pair were asked for"
    [ receipt.E.blob_id; processed_handle ]
    (preview_requests ());
  let fragments = serialized failed in
  Alcotest.(check bool)
    "the failure that arrived first is the one reported" true
    (Test_util.string_contains fragments ~sub:"previews=failed:blob_not_found;");
  Alcotest.(check bool)
    "and the one that arrived after it is not also reported" false
    (Test_util.string_contains fragments ~sub:"previews=failed:url_unavailable;");
  (* Neither refusal minted anything, so a pair that failed both ways holds
     nothing and has nothing to release. *)
  Alcotest.(check int) "a refusal mints no URL" 0 !preview_mints;
  Alcotest.(check (list string))
    "so there is nothing for the failure to release" [] (revoked_urls ())

(* Every picture the section is rendering at this viewport, however deep. The
   count is what tells a pair from half of one, and a view showing the same URL
   under both headings from one showing two photographs. *)
let pictures_shown ~viewport model =
  find_all picture (tree (render (Sub.view viewport model)))

(* One half of the pair, by the anchor a browser spec reaches it through. The
   anchor is on the wrapper rather than the picture because a picture element
   takes no attributes, which is also what keeps this feature from having to
   touch the element vocabulary at all. *)
let half_of_the_pair ~anchor ~viewport model =
  match find anchor (tree (render (Sub.view viewport model))) with
  | Some node -> node
  | None -> Alcotest.fail "a half of the before-and-after pair is not rendered"

let picture_in wrapper =
  match find picture wrapper with
  | Some node -> node
  | None -> Alcotest.fail "a half of the before-and-after pair holds no picture"

(* The two photographs side by side, each under the heading that says which one
   it is. That labelling is the whole point of the pair: an unlabelled before
   and after lets a reviewer read the photo that is about to be sent as the one
   that was picked, which is precisely the mistake the section exists to expose.
   The URLs are asserted by value and per side, so a view that put the pair in
   one wrapper, or filled both wrappers from one slot, is visible here rather
   than passing as two pictures. *)
let test_preview_pair_rendered_with_alt_and_testids () =
  let picked_url = stub_url ~blob_id:receipt.E.blob_id ~mint:1 in
  let sent_url = stub_url ~blob_id:processed_handle ~mint:2 in
  let final =
    preview_session (fun ~current ~send ->
        send (select_message [ receipt ] !current);
        drain ();
        (* Half a pair is not a pair, and at this point the section holds none
           of it. Without these two the assertions below would pass against a
           view that showed whichever URL happened to be in hand. *)
        Alcotest.(check int)
          "a section still waiting for its URLs shows no photograph" 0
          (List.length (pictures_shown ~viewport:vp !current));
        deliver_next_preview ();
        Alcotest.(check int)
          "and one URL of the two still shows none" 0
          (List.length (pictures_shown ~viewport:vp !current));
        drain_previews ())
  in
  Alcotest.(check bool)
    "the section ends the exchange holding a pair" true (showing_a_pair final);
  Alcotest.(check int)
    "which is two photographs and no more" 2
    (List.length (pictures_shown ~viewport:vp final));
  let picked = half_of_the_pair ~anchor:original_preview ~viewport:vp final in
  let sent = half_of_the_pair ~anchor:processed_preview ~viewport:vp final in
  Alcotest.(check (option string))
    "the photo that was picked is shown under its own anchor" (Some picked_url)
    (attr "src" (picture_in picked));
  Alcotest.(check (option string))
    "and the photo that will be sent under its own" (Some sent_url)
    (attr "src" (picture_in sent));
  Alcotest.(check bool)
    "the picked photo says on screen which one it is" true
    (Test_util.string_contains (text_content picked) ~sub:"Original");
  Alcotest.(check bool)
    "and the one that will be sent says so too" true
    (Test_util.string_contains (text_content sent) ~sub:"As uploaded");
  (* A pair of photographs with no alternative text is a pair of photographs a
     screen reader cannot tell apart, and describing both the same way would be
     the same failure spelled differently. *)
  match (attr "alt" (picture_in picked), attr "alt" (picture_in sent)) with
  | None, (None | Some _)
  | Some _, None ->
      Alcotest.fail "a half of the before-and-after pair carries no alt text"
  | Some picked_alt, Some sent_alt ->
      Alcotest.(check bool)
        "the picked photo is described" true
        (String.length picked_alt > 0);
      Alcotest.(check bool)
        "so is the one that will be sent" true
        (String.length sent_alt > 0);
      Alcotest.(check bool)
        "and the two descriptions are not the same" false
        (String.equal picked_alt sent_alt)

(* The container the pair sits in, by the direction it lays its children out
   in. *)
let pair_container ~viewport model =
  match find preview_pair (tree (render (Sub.view viewport model))) with
  | Some (Element { tag; style = _; attrs = _; children = _; interaction = _ })
    ->
      tag
  | Some (Empty | Text { content = _; text_style = _ }) ->
      Alcotest.fail "the before-and-after container is not a layout element"
  | None -> Alcotest.fail "the before-and-after container is not rendered"

(* A before and an after are read against each other, so they go side by side
   wherever there is room for two of them and stack where there is not. A phone
   held upright has room for one, and two photographs squeezed into that width
   are two photographs nobody can see the difference between. *)
let test_preview_pair_stacks_on_compact_viewport () =
  let final =
    preview_session (fun ~current ~send -> take_a_photo ~current ~send)
  in
  Alcotest.(check bool)
    "the section is holding a pair to lay out" true (showing_a_pair final);
  Alcotest.(check string)
    "a phone stacks the two photographs" "column"
    (pair_container ~viewport:Nopal_element.Viewport.phone final);
  Alcotest.(check string)
    "a desktop puts them side by side" "row"
    (pair_container ~viewport:Nopal_element.Viewport.desktop final);
  (* Reflowing by showing less is not reflowing. Without these two, a compact
     branch that rendered an empty container would satisfy the direction
     assertions above. *)
  Alcotest.(check int)
    "the phone shows both of them" 2
    (List.length (pictures_shown ~viewport:Nopal_element.Viewport.phone final));
  Alcotest.(check int)
    "and so does the desktop" 2
    (List.length
       (pictures_shown ~viewport:Nopal_element.Viewport.desktop final))

(* Two passes started for the one picked photo, the first of which succeeds and
   produces a pair, the second of which fails. The section is then holding a
   photograph it cannot label - the lengths under the pair come off the
   measurement, and the measurement is gone - so the pair has to go with it, and
   the URLs holding it have to be released as it goes. Nothing else in the module
   would ever let them go: a failed stage offers no re-shoot control, so the only
   exit is the picker, and until the user finds it the pictures stay pinned. *)
let test_a_failing_second_pass_releases_the_pair_the_first_produced () =
  let current, send = driver (model0 ()) in
  with_preview_backend (fun () ->
      with_image_backend
        (sequenced_image_backend
           [
             Ok (processed_info ~sharpness:over_threshold);
             Error (Processing.Decode_failed "not a JPEG");
           ])
        (fun () ->
          send (select_message [ receipt ] !current);
          send (select_message [ receipt ] !current);
          answer_pass_for ~blob_id:receipt.E.blob_id;
          drain_previews ();
          (* The affirmative arm: without it every absence below would be
             satisfied by a fixture that never produced a pair at all. *)
          Alcotest.(check bool)
            "the first pass leaves a pair on screen" true
            (showing_a_pair !current);
          answer_pass_for ~blob_id:receipt.E.blob_id;
          drain_previews ()));
  let fragments = Sub.serialize_model !current in
  Alcotest.(check bool)
    "the failing second pass is reported as the failure it is" true
    (Test_util.string_contains fragments ~sub:"processing=failed:decode_failed;");
  Alcotest.(check bool)
    "the section no longer claims a pair it can neither show nor label" false
    (Test_util.string_contains fragments ~sub:"previews=ready;");
  Alcotest.(check bool)
    "reporting instead that it is holding none" true
    (Test_util.string_contains fragments ~sub:"previews=none;");
  Alcotest.(check int) "the first pass minted two URLs" 2 !preview_mints;
  Alcotest.(check (list string))
    "and both are released as the failure lets the pair go"
    [
      stub_url ~blob_id:receipt.E.blob_id ~mint:1;
      stub_url ~blob_id:processed_handle ~mint:2;
    ]
    (revoked_urls ());
  Alcotest.(check int)
    "which leaves nothing at all still out" 0
    (!preview_mints - List.length (revoked_urls ()));
  (* And nothing is drawn from what was let go, which is what keeps the release
     above from being true only in the ledger. *)
  Alcotest.(check int)
    "no photograph is left on screen" 0
    (List.length (pictures_shown ~viewport:vp !current))

(* A URL still in flight when the user empties the picker. The clear takes the
   pair the section was waiting for with it, so the delivery arrives to a section
   holding no pair at all - not to one waiting for a different pair, which is the
   superseded case and is reached by generation instead. Every other case that
   arrives at a section holding nothing arrives carrying a refusal, so this is
   the only one that puts a real URL in the section's hands with nowhere to put
   it. It pins its picture exactly as a shown one does, so it is released on
   arrival rather than stored under a pair that has been let go. *)
let test_a_url_arriving_after_a_clear_is_released () =
  let current, send = driver (model0 ()) in
  with_preview_backend (fun () ->
      with_image_backend
        (image_backend ~calls:(ref [])
           ~outcome:(Ok (processed_info ~sharpness:over_threshold)))
        (fun () ->
          send (select_message [ receipt ] !current);
          drain ();
          (* The affirmative arm: the pair really was asked for and both URLs
             are out at this point, so what arrives after the clear is a
             delivery the fixture produced rather than one it never started. *)
          Alcotest.(check bool)
            "the section is waiting for a pair when the picker is emptied" true
            (Test_util.string_contains
               (Sub.serialize_model !current)
               ~sub:"previews=pending;");
          send (clear_message !current);
          Alcotest.(check bool)
            "which the clear takes away with it" true
            (Test_util.string_contains
               (Sub.serialize_model !current)
               ~sub:"previews=none;");
          Alcotest.(check (list string))
            "with nothing to release, because neither URL had arrived yet" []
            (revoked_urls ());
          drain_previews ()));
  let fragments = Sub.serialize_model !current in
  Alcotest.(check bool)
    "the section still reports itself holding no pair" true
    (Test_util.string_contains fragments ~sub:"previews=none;");
  Alcotest.(check bool)
    "a URL arriving after the clear does not turn it back into one" false
    (Test_util.string_contains fragments ~sub:"previews=ready;");
  Alcotest.(check bool)
    "nor into one still waiting" false
    (Test_util.string_contains fragments ~sub:"previews=pending;");
  Alcotest.(check int) "both URLs were minted" 2 !preview_mints;
  Alcotest.(check (list string))
    "and both are released as they arrive"
    [
      stub_url ~blob_id:receipt.E.blob_id ~mint:1;
      stub_url ~blob_id:processed_handle ~mint:2;
    ]
    (revoked_urls ());
  Alcotest.(check int)
    "which leaves nothing at all still out" 0
    (!preview_mints - List.length (revoked_urls ()));
  (* And nothing is drawn from what arrived, which is what keeps the release
     above from being true only in the ledger. *)
  Alcotest.(check int)
    "no photograph reaches the screen" 0
    (List.length (pictures_shown ~viewport:vp !current))

(* One photo carried all the way through to a shown pair, with the result the
   pass produced written out at the call site. [preview_session] fixes that
   result, which is what makes it useless for a case about what the pass cost:
   the encoded byte length is the quantity under test here. *)
let photo_with_result info =
  let current, send = driver (model0 ()) in
  with_preview_backend (fun () ->
      with_image_backend
        (image_backend ~calls:(ref []) ~outcome:(Ok info))
        (fun () ->
          send (select_message [ receipt ] !current);
          drain ();
          drain_previews ()));
  !current

(* A pass whose output is bigger than the photo it consumed. Re-encoding does not
   always shrink: a small, already-optimised photo, or one whose long edge is
   already under the section's stored edge so no downscale applies, comes back
   larger. It is 119% of the picked file's own length, which is the number the
   label has to be able to say without reading as a reduction that went wrong. *)
let grown_byte_size = 2_500_000

let grown_info =
  {
    Processing.blob_id = processed_handle;
    width = 1024;
    height = 768;
    byte_size = grown_byte_size;
    sharpness = over_threshold;
  }

(* The text of one half of the pair, by the anchor a browser spec reaches it
   through. Read per half rather than off the section as a whole: what has to be
   true is that each half names the length of the picture THAT half shows, and a
   search over the whole subtree is satisfied by a section that puts both numbers
   under one heading. *)
let half_text ~anchor model =
  text_content (half_of_the_pair ~anchor ~viewport:vp model)

(* The numbers below are the suite's own fixtures written out rather than
   recomputed from them: [receipt] is 2097152 bytes and the pass it drives
   produces 214007, so 10% is arithmetic this file states rather than repeats
   from the section. *)
let test_preview_labels_carry_both_byte_sizes () =
  let final = photo_with_result (processed_info ~sharpness:over_threshold) in
  Alcotest.(check bool)
    "the section is holding a pair to label" true (showing_a_pair final);
  let picked = half_text ~anchor:original_preview final in
  let sent = half_text ~anchor:processed_preview final in
  Alcotest.(check bool)
    "the picked photo is labelled with the length of the file that was picked"
    true
    (Test_util.string_contains picked ~sub:"2097152 bytes");
  Alcotest.(check bool)
    "and not with the length of the photo that will be sent" false
    (Test_util.string_contains picked ~sub:"214007");
  Alcotest.(check bool)
    "the photo that will be sent is labelled with its own length" true
    (Test_util.string_contains sent ~sub:"214007 bytes");
  Alcotest.(check bool)
    "and not with the length of the file that was picked" false
    (Test_util.string_contains sent ~sub:"2097152")

(* Two numbers side by side are two numbers a reader has to divide, and the
   point of the readout is that they should not have to. The comparison belongs
   to the half that was produced: the picked photo is not smaller than anything.
*)
let test_processed_label_reports_the_reduction () =
  let final = photo_with_result (processed_info ~sharpness:over_threshold) in
  let picked = half_text ~anchor:original_preview final in
  let sent = half_text ~anchor:processed_preview final in
  Alcotest.(check bool)
    "the processed half says what it came to relative to the original" true
    (Test_util.string_contains sent ~sub:"reduced to 10% of the original");
  Alcotest.(check bool)
    "and does not read as a pass that grew" false
    (Test_util.string_contains sent ~sub:"grown to");
  Alcotest.(check bool)
    "the picked half claims no reduction of its own" false
    (Test_util.string_contains picked ~sub:"reduced to")

(* A pass that came out bigger. A label computing "N% of the original"
   unconditionally is arithmetically right and reads, under a heading saying the
   photo is the one about to be sent, as a reduction that went wrong rather than
   as the normal outcome for an already-small photo. The two phrasings share no
   substring, so an assertion aimed at one is not satisfiable by the other. *)
let test_a_processed_image_that_grew_is_not_a_reduction () =
  let final = photo_with_result grown_info in
  Alcotest.(check bool)
    "the section is holding a pair to label" true (showing_a_pair final);
  let sent = half_text ~anchor:processed_preview final in
  Alcotest.(check bool)
    "a pass whose output is larger says so" true
    (Test_util.string_contains sent ~sub:"grown to 119% of the original");
  Alcotest.(check bool)
    "and is not reported as a reduction" false
    (Test_util.string_contains sent ~sub:"reduced to");
  Alcotest.(check bool)
    "the length it grew to is the one shown" true
    (Test_util.string_contains sent ~sub:"2500000 bytes")

(* A pass whose output is a fraction of one percent of the file it consumed. The
   share is integer arithmetic, so anything under a hundredth floors to nothing:
   rendered as a number it reads "reduced to 0% of the original", which is a
   broken readout rather than a very good one - the same misreading the growth
   wording exists to prevent, at the other end of the range. 4096 bytes of the
   fixture's 2097152 is 0.2%. *)
let tiny_byte_size = 4_096

let tiny_info =
  {
    Processing.blob_id = processed_handle;
    width = 1024;
    height = 768;
    byte_size = tiny_byte_size;
    sharpness = over_threshold;
  }

let test_a_share_under_one_percent_is_not_rendered_as_none () =
  let final = photo_with_result tiny_info in
  Alcotest.(check bool)
    "the section is holding a pair to label" true (showing_a_pair final);
  let sent = half_text ~anchor:processed_preview final in
  (* Anchored on the "reduced to" that precedes it rather than on "0%" alone:
     every share ending in a zero digit contains "0% of the original", so the
     looser assertion would read a perfectly good "reduced to 10%" as this
     failure. *)
  Alcotest.(check bool)
    "a share too small to state is not rendered as no share at all" false
    (Test_util.string_contains sent ~sub:"reduced to 0%");
  Alcotest.(check bool)
    "it is said in words instead" true
    (Test_util.string_contains sent ~sub:"reduced to under 1% of the original");
  Alcotest.(check bool)
    "and it is still a reduction rather than a growth" false
    (Test_util.string_contains sent ~sub:"grown to");
  Alcotest.(check bool)
    "beside the length it came to" true
    (Test_util.string_contains sent ~sub:"4096 bytes")

(* A pass whose output is exactly as long as the file it consumed - a photo
   already at the stored edge and already at the encoder's quality, which comes
   back the same length it went in. It is the middle of the three directions, and
   the one the three-way variant was written to add: rendered as a share it reads
   "reduced to 100% of the original", which is a reduction that achieved nothing
   rather than a re-encode that changed nothing. *)
let unchanged_byte_size = 2_097_152

let unchanged_info =
  {
    Processing.blob_id = processed_handle;
    width = 1024;
    height = 768;
    byte_size = unchanged_byte_size;
    sharpness = over_threshold;
  }

let test_a_processed_image_of_equal_length_is_not_a_reduction () =
  let final = photo_with_result unchanged_info in
  Alcotest.(check bool)
    "the section is holding a pair to label" true (showing_a_pair final);
  let sent = half_text ~anchor:processed_preview final in
  Alcotest.(check bool)
    "a pass that came back the same length says so" true
    (Test_util.string_contains sent ~sub:"the same size as the original");
  (* The specific misreading first, then the general one: a pass that reduced
     nothing may not be worded as a reduction at all, and "reduced to 100%" is
     the particular rendering the direction exists to keep off the screen. *)
  Alcotest.(check bool)
    "and not as a reduction to all of the original" false
    (Test_util.string_contains sent ~sub:"reduced to 100%");
  Alcotest.(check bool)
    "nor as a reduction of any kind" false
    (Test_util.string_contains sent ~sub:"reduced to");
  Alcotest.(check bool)
    "nor as a growth" false
    (Test_util.string_contains sent ~sub:"grown to");
  Alcotest.(check bool)
    "beside the length it came to" true
    (Test_util.string_contains sent ~sub:"2097152 bytes")

(* The payload change has to be readable by a browser spec, and a percentage is a
   float by another name: its rendering depends on a rounding rule the spec would
   have to reimplement to assert on. Two integers go on the wire and whoever
   reads them does the division. The fragment is emitted only once a pass has
   produced a length, so a section that has measured nothing cannot satisfy an
   assertion naming one. *)
let test_original_byte_size_fragment () =
  let untouched = serialized (model0 ()) in
  Alcotest.(check bool)
    "an untouched section reports no length for a photo it has not measured"
    false
    (Test_util.string_contains untouched ~sub:"original_byte_size=");
  let final = photo_with_result (processed_info ~sharpness:over_threshold) in
  let fragments = serialized final in
  Alcotest.(check bool)
    "a completed pass reports the length of the file it consumed" true
    (Test_util.string_contains fragments ~sub:"original_byte_size=2097152;");
  (* Anchored, and here it is the whole point of the assertion: this case is the
     one that puts the two lengths in the record together, so a search for the
     processed one that a fragment naming the picked one could satisfy would
     report the pair present when only half of it is. *)
  Alcotest.(check bool)
    "beside the length it produced" true
    (Test_util.contains_fragment fragments ~fragment:"byte_size=214007;");
  Alcotest.(check bool)
    "no ratio reaches the telemetry" false
    (String.contains fragments '%');
  Alcotest.(check bool)
    "and nothing on the wire is a float rendering" false
    (String.contains fragments '.');
  let cleared = clear_and_update final in
  Alcotest.(check bool)
    "and a section that has let the photo go stops reporting its length" false
    (Test_util.string_contains (serialized cleared) ~sub:"original_byte_size=")

let () =
  Alcotest.run "kitchen_sink_receipt_flow_section"
    [
      ( "selection",
        [
          Alcotest.test_case "the section renders its configured picker" `Quick
            test_section_renders_its_configured_picker;
          Alcotest.test_case "selection triggers processing" `Quick
            test_selection_triggers_processing;
          Alcotest.test_case "metadata is recorded in the model" `Quick
            test_metadata_recorded_in_model;
        ] );
      ( "failure",
        [
          Alcotest.test_case "a decode failure is recorded under its own tag"
            `Quick test_decode_failure_recorded;
          Alcotest.test_case "every failure arm is distinguishable" `Quick
            test_failure_arms_distinct;
        ] );
      ( "threshold",
        [
          Alcotest.test_case "a soft photo is offered a re-shoot" `Quick
            test_threshold_verdict_below;
          Alcotest.test_case "a sharp photo is offered acceptance" `Quick
            test_threshold_verdict_above;
          Alcotest.test_case "a photo on the threshold is offered acceptance"
            `Quick test_threshold_boundary_is_accepted;
          Alcotest.test_case "re-shooting clears the rejected readout" `Quick
            test_reshoot_clears_result;
        ] );
      ( "clearing",
        [
          Alcotest.test_case "clearing the picker returns the section to idle"
            `Quick test_clearing_the_picker_returns_the_section_to_idle;
          Alcotest.test_case "clearing discards a pass still in flight" `Quick
            test_clearing_the_picker_discards_a_pass_still_in_flight;
          Alcotest.test_case
            "a late pass is not recorded against the photo that replaced it"
            `Quick
            test_a_late_pass_is_not_recorded_against_the_photo_that_replaced_it;
        ] );
      ( "comparison",
        [
          Alcotest.test_case "the first photo is compared against nothing"
            `Quick test_first_photo_has_no_comparison;
          Alcotest.test_case "a better second photo is recorded as sharper"
            `Quick test_second_photo_records_sharper;
          Alcotest.test_case "a worse second photo is recorded as not sharper"
            `Quick test_second_photo_records_not_sharper;
          Alcotest.test_case "the comparison survives a re-shoot" `Quick
            test_comparison_survives_a_reshoot;
          Alcotest.test_case "the comparison survives a failed pass" `Quick
            test_comparison_survives_a_failed_pass;
          Alcotest.test_case
            "a second pass started in flight is compared to the first" `Quick
            test_second_pass_in_flight_is_compared_to_the_first;
        ] );
      ( "upload",
        [
          Alcotest.test_case "accepting uploads the processed handle" `Quick
            test_upload_sends_processed_handle;
          Alcotest.test_case "accepting uploads the typed note" `Quick
            test_upload_includes_text_field;
          Alcotest.test_case "accepting from an idle section starts nothing"
            `Quick test_accepting_from_an_idle_section_starts_nothing;
          Alcotest.test_case "every upload outcome is distinguishable" `Quick
            test_upload_failure_arms_distinct;
          Alcotest.test_case
            "a late reply is not recorded against the next photo" `Quick
            test_late_reply_is_not_recorded_against_the_next_photo;
        ] );
      ( "previews",
        [
          Alcotest.test_case "a pass asks for a URL for both handles" `Quick
            test_previews_requested_for_both_ids;
          Alcotest.test_case "the pair is reported pending, then ready" `Quick
            test_previews_fragment_pending_then_ready;
          Alcotest.test_case
            "a re-shoot releases both URLs before asking for their replacements"
            `Quick test_reshoot_revokes_before_requesting;
          Alcotest.test_case
            "a re-shoot loop leaves only the pair on screen unreleased" `Quick
            test_reshoot_loop_leak_count;
          Alcotest.test_case "a superseded URL is released as it arrives" `Quick
            test_superseded_url_revoked_on_arrival;
          Alcotest.test_case "clearing the picker releases the pair it held"
            `Quick test_clearing_the_picker_releases_the_pair;
          Alcotest.test_case "a second pass releases the pair it replaces"
            `Quick test_a_second_pass_releases_the_pair_it_replaces;
          Alcotest.test_case
            "a preview that failed leaves the processed photo standing" `Quick
            test_preview_failure_preserves_processed;
          Alcotest.test_case "every preview failure arm is distinguishable"
            `Quick test_preview_failure_fragment_tagged;
          Alcotest.test_case "a failure releases the half pair it discards"
            `Quick test_a_failure_releases_the_half_pair_it_discards;
          Alcotest.test_case
            "a pair that failed both ways reports the failure that arrived \
             first"
            `Quick test_a_pair_failing_both_ways_reports_the_first;
          Alcotest.test_case
            "a failing second pass releases the pair the first produced" `Quick
            test_a_failing_second_pass_releases_the_pair_the_first_produced;
          Alcotest.test_case
            "a URL arriving after the picker was cleared is released" `Quick
            test_a_url_arriving_after_a_clear_is_released;
          Alcotest.test_case
            "the pair is rendered labelled, described and anchored" `Quick
            test_preview_pair_rendered_with_alt_and_testids;
          Alcotest.test_case "the pair stacks where there is room for one"
            `Quick test_preview_pair_stacks_on_compact_viewport;
        ] );
      ( "payload",
        [
          Alcotest.test_case "each half names the length of its own picture"
            `Quick test_preview_labels_carry_both_byte_sizes;
          Alcotest.test_case "the processed half reports what the pass cost"
            `Quick test_processed_label_reports_the_reduction;
          Alcotest.test_case "a pass that grew is not reported as a reduction"
            `Quick test_a_processed_image_that_grew_is_not_a_reduction;
          Alcotest.test_case
            "a share under one percent is not rendered as no share at all"
            `Quick test_a_share_under_one_percent_is_not_rendered_as_none;
          Alcotest.test_case
            "a pass that came back the same length is not reported as a \
             reduction"
            `Quick test_a_processed_image_of_equal_length_is_not_a_reduction;
          Alcotest.test_case "the picked photo's length reaches the telemetry"
            `Quick test_original_byte_size_fragment;
        ] );
    ]

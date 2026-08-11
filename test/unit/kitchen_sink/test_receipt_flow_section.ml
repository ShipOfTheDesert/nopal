open Nopal_test.Test_renderer
module Sub = Kitchen_sink_app__Sub_receipt_flow
module E = Nopal_element.Element
module Config = Nopal_image.Config
module Processing = Nopal_image.Processing

let vp = Nopal_element.Viewport.desktop
let picker = By_attr ("data-field", "receipt-photo")
let metadata = By_attr ("data-testid", "receipt-flow-metadata")
let verdict = By_attr ("data-testid", "receipt-flow-verdict")
let accept = By_attr ("data-field", "receipt-accept")
let reshoot = By_attr ("data-field", "receipt-reshoot")
let note = By_attr ("data-field", "receipt-note")
let upload_readout = By_attr ("data-testid", "receipt-flow-upload")

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
  with_image_backend (image_backend ~calls ~outcome) (fun () ->
      send msg;
      Alcotest.(check bool)
        "the pass has not answered before the drain" false
        (pass_answered !current);
      drain ());
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
  Alcotest.(check bool)
    "the processed byte size is recorded" true
    (Test_util.string_contains fragments ~sub:"byte_size=214007;");
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
    ]

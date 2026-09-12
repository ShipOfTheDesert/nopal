open Nopal_test.Test_renderer
module E = Nopal_element.Element
module Processing = Nopal_image.Processing
module Retention = Nopal_image.Retention

(* A capture flow small enough to read in one screen and complete enough to reach
   the upload: pick a photo, process it on device, branch on how sharp it came
   back, and send the processed handle. There is no example application to point
   at yet, so the app under test lives here. *)

let upload_url = "https://uploads.example.test/photos"

(* The score at or above which this application uploads rather than asking for
   another shot. Calibrating it is the consuming application's job, so it is a
   constant of this flow and not of the library. *)
let sharp_enough = 20.0

(* Every field stated rather than taken from [Config.recommended], so a flow that
   dropped its own parameters could not pass by inheriting the preset. The format
   differs from the selected photo's own media type, which is what lets the
   upload assertion tell the processed artefact from the selection. *)
let capture_config () =
  match
    Nopal_image.Config.make ~max_edge:1280 ~metric_edge:640 ~quality:0.625
      ~format:Nopal_image.Config.Png
  with
  | Ok config -> config
  | Error error ->
      Alcotest.failf "the flow's capture parameters were rejected: %s"
        (Nopal_image.message error)

type stage =
  | Idle
  | Measuring
  | Retake of float
  | Ready of Processing.result_info
  | Failed of Processing.error
  | Sending of Processing.result_info
  | Sent of int
  | Send_failed of Nopal_http.error

type model = { selected : E.file_info option; stage : stage }

type msg =
  | Selected of E.file_info list
  | Processed of (Processing.result_info, Processing.error) result
  | Accept_clicked
  | Send_finished of Nopal_http.outcome

let init () = ({ selected = None; stage = Idle }, Nopal_mvu.Cmd.none)

let processed_part handle =
  Nopal_http.File
    {
      name = "photo";
      blob_id = handle;
      filename = Some "photo.png";
      mime =
        Some
          (Nopal_image.Config.format_to_mime
             (Nopal_image.Config.format (capture_config ())));
    }

(* The photo the picker handed over, while the flow is still holding it. *)
let picked_handle model =
  match model.selected with
  | Some file -> [ file.E.blob_id ]
  | None -> []

(* The encode the last pass produced, while the flow is still holding it. A pass
   still running has produced none, a pass that failed stored nothing, and a
   photo sent back for another shot released its encode as the score was
   rejected. The upload stages keep theirs deliberately: a request on its way is
   reading exactly those bytes, so they are not among what a selection change
   frees. *)
let held_encode model =
  match model.stage with
  | Ready info -> [ info.Processing.blob_id ]
  | Idle
  | Measuring
  | Retake _
  | Failed _
  | Sending _
  | Sent _
  | Send_failed _ ->
      []

(* Both stored images the flow is holding at this moment. *)
let held_handles model = picked_handle model @ held_encode model

(* Everything named here, released. A stored image stays held until something
   releases it - no runtime, no unmount and no collector does it - so a flow that
   lets one go without this retains every photo the user has taken for the rest
   of the session. *)
let release_handles handles =
  Nopal_mvu.Cmd.batch
    (List.map (fun blob_id -> Retention.release ~blob_id) handles)

let update model msg =
  match msg with
  | Selected [] ->
      (* The picker emptied. The photo it was holding and the encode measured
         from it are what it stops describing, so they are released here rather
         than dropped. *)
      ({ selected = None; stage = Idle }, release_handles (held_handles model))
  | Selected (file :: _) ->
      (* A photo replaced by another. What the flow was holding goes as the
         replacement arrives, minus the handle just picked: a selection is issued
         a distinct handle every time and no handle is ever reused, but that
         promise is made in another package, and if it were broken this arm would
         free the bytes the pass it is starting is about to read. *)
      ( { selected = Some file; stage = Measuring },
        Nopal_mvu.Cmd.batch
          [
            release_handles
              (List.filter
                 (fun handle -> not (String.equal handle file.E.blob_id))
                 (held_handles model));
            Processing.process ~blob_id:file.E.blob_id
              ~config:(capture_config ()) (fun result -> Processed result);
          ] )
  | Processed (Ok info) ->
      (* The pass stored its encode before it answered, and the retake branch is
         the one exit that never offers to send that encode: the flow is holding
         bytes it has already decided not to use. They are released as the score
         is rejected rather than left for a replacement that may never be
         picked. The photo itself stays picked, so it is not released here. *)
      let stage, released =
        match Float.compare info.Processing.sharpness sharp_enough >= 0 with
        | true -> (Ready info, Nopal_mvu.Cmd.none)
        | false ->
            ( Retake info.Processing.sharpness,
              release_handles [ info.Processing.blob_id ] )
      in
      ({ model with stage }, released)
  | Processed (Error error) ->
      ({ model with stage = Failed error }, Nopal_mvu.Cmd.none)
  | Accept_clicked -> (
      match model.stage with
      | Ready info ->
          ( { model with stage = Sending info },
            Nopal_http.post
              ~body:
                (Nopal_http.Multipart
                   [
                     Nopal_http.Field ("caption", "camera roll");
                     processed_part info.Processing.blob_id;
                   ])
              upload_url
              (fun outcome -> Send_finished outcome) )
      | Idle
      | Measuring
      | Retake _
      | Failed _
      | Sending _
      | Sent _
      | Send_failed _ ->
          (model, Nopal_mvu.Cmd.none))
  | Send_finished (Ok response) ->
      ( { model with stage = Sent response.Nopal_http.status },
        Nopal_mvu.Cmd.none )
  | Send_finished (Error error) ->
      ({ model with stage = Send_failed error }, Nopal_mvu.Cmd.none)

let selected_name model =
  match model.selected with
  | Some file -> file.E.name
  | None -> "no photo"

let status_text model =
  match model.stage with
  | Idle -> "No photo selected"
  | Measuring -> "Measuring " ^ selected_name model
  | Retake score -> Printf.sprintf "Too blurry to upload (sharpness %.1f)" score
  | Ready info ->
      Printf.sprintf "Ready to upload %d by %d" info.Processing.width
        info.Processing.height
  | Failed error -> "Processing failed: " ^ Processing.message error
  | Sending _ -> "Uploading the processed photo"
  | Sent status -> Printf.sprintf "Uploaded (HTTP %d)" status
  | Send_failed error -> "Upload failed: " ^ Nopal_http.message error

let accept_button model =
  match model.stage with
  | Ready _ ->
      E.button
        ~attrs:[ ("data-field", "photo-accept") ]
        ~on_click:Accept_clicked
        (E.text "Upload this photo")
  | Idle
  | Measuring
  | Retake _
  | Failed _
  | Sending _
  | Sent _
  | Send_failed _ ->
      E.empty

let view _viewport model =
  E.column
    ~attrs:[ ("data-testid", "photo-flow") ]
    [
      E.file_input
        ~attrs:[ ("data-field", "photo") ]
        ~accept:[ "image/*" ]
        ~on_change:(fun files -> Selected files)
        ();
      E.box
        ~attrs:[ ("data-testid", "photo-status") ]
        [ E.text (status_text model) ];
      accept_button model;
    ]

(* Names the stage without its payload, so a case can pin which branch the flow
   took without pinning the rendered sentence too. Bare [function] so a new stage
   is a compile error here rather than a silently unasserted branch. *)
let stage_name = function
  | Idle -> "Idle"
  | Measuring -> "Measuring"
  | Retake _ -> "Retake"
  | Ready _ -> "Ready"
  | Failed _ -> "Failed"
  | Sending _ -> "Sending"
  | Sent _ -> "Sent"
  | Send_failed _ -> "Send_failed"

(* Fixtures. *)

let picker = By_attr ("data-field", "photo")
let accept = By_attr ("data-field", "photo-accept")
let status = By_attr ("data-testid", "photo-status")

(* A selection as the renderer hands it over: an opaque store handle plus
   user-agent metadata. Its media type differs from the configured encode
   format, so a part that echoed the selection cannot be mistaken for one that
   describes the processed bytes. *)
let camera_photo =
  E.file_info ~blob_id:"blob-camera-1" ~name:"IMG_0042.jpg" ~size:3_145_728
    ~mime:"image/jpeg" ~last_modified:1_700_000_000_000.

(* A second photo, so a case about a replaced selection can name the handle that
   went and the handles that stayed rather than counting releases. *)
let other_photo =
  E.file_info ~blob_id:"blob-camera-2" ~name:"IMG_0043.jpg" ~size:2_097_152
    ~mime:"image/jpeg" ~last_modified:1_700_000_500_000.

let processed_handle = "blob-processed-9f2"

(* The encode a pass over [other_photo] produces. Distinct from the first pass's,
   so a transition that released the encode it had just produced is visible in
   the ledger rather than hidden behind a shared handle. *)
let replacement_handle = "blob-processed-c47"

(* Every field stated; the dimensions and byte size are unrelated to any config
   value, so a result echoed from the parameters would be visible. *)
let processed_info ~sharpness =
  {
    Processing.blob_id = processed_handle;
    width = 1024;
    height = 768;
    byte_size = 214_007;
    sharpness;
  }

let replacement_info ~sharpness =
  {
    Processing.blob_id = replacement_handle;
    width = 1440;
    height = 1080;
    byte_size = 301_442;
    sharpness;
  }

(* Harness. *)

(* Installs [backend] for the duration of [f] and restores the default
   afterwards, so a failing assertion cannot leak a stub into the next case. *)
let with_image_backend backend f =
  Fun.protect
    ~finally:(fun () -> Processing.register_backend Processing.default_backend)
    (fun () ->
      Processing.register_backend backend;
      f ())

let with_http_backend backend f =
  Fun.protect
    ~finally:(fun () -> Nopal_http.register_backend Nopal_http.default_backend)
    (fun () ->
      Nopal_http.register_backend backend;
      f ())

let image_backend ~calls ~outcome =
  {
    Processing.process =
      (fun ~blob_id ~config ->
        calls := (blob_id, config) :: !calls;
        Nopal_mvu.Task.return outcome);
  }

(* A backend that answers per picked handle rather than per call, so a case
   driving two selections gets the outcome belonging to each rather than to the
   order they happened to arrive in. A handle nothing was scripted for fails the
   case instead of being answered, which is what keeps a flow that processed the
   wrong photo from passing. *)
let keyed_image_backend outcomes =
  {
    Processing.process =
      (fun ~blob_id ~config:_ ->
        match List.assoc_opt blob_id outcomes with
        | Some outcome -> Nopal_mvu.Task.return outcome
        | None ->
            Alcotest.failf
              "the flow processed a handle no outcome was scripted for: %s"
              blob_id);
  }

(* Handles the release seam was asked to let go of, newest first while it is
   being built. A ledger of handles rather than a count of calls: a flow that
   released the handle it is still holding and one that released the handle it
   replaced are the same number, and which handle went is the whole claim. *)
let released_handles : string list ref = ref []

(* Every field written out. The seam has one, and it records rather than frees:
   this flow is native-compiled and cannot name a browser store, so a stub parked
   here is the only place a release is observable at all. *)
let retention_backend =
  {
    Retention.release =
      (fun ~blob_id -> released_handles := blob_id :: !released_handles);
  }

(* The ledger in the order the releases happened. *)
let released () = List.rev !released_handles

(* Installs the stub for the duration of [f] and restores the default
   afterwards, so a failing assertion cannot leak it into the next case. The
   ledger is reset on the way IN, because a case reads what was released after
   the exchange it was released during has closed. *)
let with_retention_backend f =
  released_handles := [];
  Fun.protect
    ~finally:(fun () -> Retention.register_backend Retention.default_backend)
    (fun () ->
      Retention.register_backend retention_backend;
      f ())

(* The flow driven the way the runtime drives it: every command a step returns is
   executed and whatever it dispatches is folded straight back in. [at] renders a
   trace and discards its commands, and [advance] keeps only the last one, so
   neither can see a release - a release is all command and no message. Returns
   the cell holding the current model alongside the send function, so a case can
   assert what the flow was holding before the transition it is about. *)
let driver () =
  let model = ref (fst (init ())) in
  let rec send msg =
    let next, cmd = update !model msg in
    model := next;
    Nopal_mvu.Cmd.execute send cmd
  in
  (model, send)

let http_backend ~requests ~outcome =
  {
    Nopal_http.send =
      (fun request ->
        requests := request :: !requests;
        Nopal_mvu.Task.return outcome);
  }

(* Folds [trace] through the loop and renders the result. *)
let at trace = run_app ~init ~update ~view trace

let status_line rendered =
  match find status (tree rendered) with
  | Some node -> text_content node
  | None -> Alcotest.fail "the flow's status element is missing from the view"

let offers_upload rendered = Option.is_some (find accept (tree rendered))

(* Appends the message the last step's command dispatched. [run_app] discards
   commands, so a message a command produced has to be obtained here;
   [run_app_with_cmds] is its command-collecting form and returns one command per
   message in order, so the last one is the command this step produced. Exactly
   one message is required, so a command that resolved twice fails the flow
   rather than being absorbed. *)
let advance ~context trace =
  let _, _, cmds = run_app_with_cmds ~init ~update ~view trace in
  match List.rev cmds with
  | [] -> Alcotest.failf "%s: the loop produced no command at all" context
  | cmd :: _ -> (
      let dispatched = ref [] in
      Nopal_mvu.Cmd.execute (fun m -> dispatched := m :: !dispatched) cmd;
      match !dispatched with
      | [ msg ] -> trace @ [ msg ]
      | [] ->
          Alcotest.failf
            "%s: the command dispatched nothing, expected one message" context
      | _ :: _ :: _ ->
          Alcotest.failf "%s: the command dispatched %d messages, expected one"
            context (List.length !dispatched))

(* Takes the next message off the rendered view rather than writing it down, so
   the flow fails if a step stops being reachable from the interface. *)
let from_ui ~context simulate trace =
  let _, rendered = at trace in
  Alcotest.(check (result unit Test_util.error_testable))
    (context ^ " is simulated on the view")
    (Ok ()) (simulate rendered);
  match messages rendered with
  | [ msg ] -> trace @ [ msg ]
  | [] -> Alcotest.failf "%s dispatched no message" context
  | _ :: _ :: _ -> Alcotest.failf "%s dispatched more than one message" context

let select_photo trace =
  from_ui ~context:"the photo selection"
    (fun rendered -> select_files picker [ camera_photo ] rendered)
    trace

let click_accept trace =
  from_ui ~context:"the accept click"
    (fun rendered -> click accept rendered)
    trace

(* Every recorded call rather than a count: each of the renders below re-folds
   the trace from [init], and the seam reads its backend when the command is
   built, so the stub is legitimately called more than once. What must hold of
   every one of them is that it named the picked handle and the flow's own
   parameters. *)
let check_every_call ~context calls =
  match calls with
  | [] -> Alcotest.failf "%s: the flow never reached the image backend" context
  | calls ->
      List.iter
        (fun (blob_id, config) ->
          Alcotest.(check string)
            (context ^ ": the picked handle reaches the backend")
            "blob-camera-1" blob_id;
          Alcotest.(check int)
            (context ^ ": the flow's own stored long edge reaches the backend")
            1280
            (Nopal_image.Config.max_edge config))
        calls

let file_handles parts =
  List.filter_map
    (function
      | Nopal_http.File { blob_id; _ } -> Some blob_id
      | Nopal_http.Field _ -> None)
    parts

let file_mimes parts =
  List.filter_map
    (function
      | Nopal_http.File { mime; _ } -> mime
      | Nopal_http.Field _ -> None)
    parts

let check_upload request =
  (match request.Nopal_http.meth with
  | Nopal_http.POST -> ()
  | Nopal_http.GET
  | Nopal_http.PUT
  | Nopal_http.DELETE
  | Nopal_http.PATCH ->
      Alcotest.fail "the accept path must POST the processed photo");
  match request.Nopal_http.body with
  | Nopal_http.Multipart parts ->
      Alcotest.(check (list string))
        "the file part names the processed image, not the selected one"
        [ processed_handle ] (file_handles parts);
      Alcotest.(check (list string))
        "the file part declares the encoded form the processing produced"
        [ "image/png" ] (file_mimes parts)
  | Nopal_http.String _
  | Nopal_http.Json _
  | Nopal_http.Form_encoded _
  | Nopal_http.Empty ->
      Alcotest.fail "the accept path must send a multipart body"

(* Cases. *)

(* Selection, then the processing command run for real, then the view the score
   produced. *)
let branch_on ~sharpness =
  let calls = ref [] in
  let model, rendered =
    with_image_backend
      (image_backend ~calls ~outcome:(Ok (processed_info ~sharpness)))
      (fun () ->
        at (advance ~context:"the processing command" (select_photo [])))
  in
  (!calls, model, rendered)

let test_flow_branches_on_sharpness () =
  let sharp_calls, sharp_model, sharp_view = branch_on ~sharpness:41.5 in
  let blurry_calls, blurry_model, blurry_view = branch_on ~sharpness:3.5 in
  check_every_call ~context:"the sharp run" sharp_calls;
  check_every_call ~context:"the blurry run" blurry_calls;
  Alcotest.(check string)
    "a sharp photo is ready to upload" "Ready"
    (stage_name sharp_model.stage);
  Alcotest.(check string)
    "a blurry photo is sent back for another shot" "Retake"
    (stage_name blurry_model.stage);
  Alcotest.(check bool)
    "the sharp branch offers the upload button" true (offers_upload sharp_view);
  Alcotest.(check bool)
    "the blurry branch offers no upload button" false
    (offers_upload blurry_view);
  Alcotest.(check bool)
    "the sharp status reports the processed size" true
    (Test_util.string_contains (status_line sharp_view) ~sub:"1024 by 768");
  Alcotest.(check bool)
    "the blurry status reports the score that failed" true
    (Test_util.string_contains (status_line blurry_view) ~sub:"3.5")

let test_accept_uploads_processed_handle () =
  Alcotest.(check bool)
    "the fixture's processed handle differs from the picked one" true
    (not (String.equal processed_handle camera_photo.E.blob_id));
  let calls = ref [] in
  let requests = ref [] in
  let model =
    with_image_backend
      (image_backend ~calls ~outcome:(Ok (processed_info ~sharpness:41.5)))
      (fun () ->
        with_http_backend
          (http_backend ~requests
             ~outcome:(Ok { Nopal_http.status = 201; body = ""; headers = [] }))
          (fun () ->
            select_photo []
            |> advance ~context:"the processing command"
            |> click_accept
            |> advance ~context:"the upload command"
            |> at
            |> fst))
  in
  check_every_call ~context:"the accept run" !calls;
  (match !requests with
  | [] -> Alcotest.fail "the accept path issued no request"
  | requests -> List.iter check_upload requests);
  Alcotest.(check string)
    "the reply reaches the model" "Sent" (stage_name model.stage)

(* A stored image stays held until something releases it - no runtime, no unmount
   and no collector does it - so a flow that stops holding one without releasing
   it retains every photo the user has taken for the life of the session. This is
   the shape a consuming application copies, so each transition that lets go of a
   photo here releases what it let go of.

   The exact list is the claim rather than a count: a transition that released the
   handle it is still holding would satisfy any count written instead, and would
   free bytes the flow is about to read. *)
let test_clearing_the_picker_releases_the_handles_it_held () =
  let current, send = driver () in
  with_retention_backend (fun () ->
      with_image_backend
        (image_backend ~calls:(ref [])
           ~outcome:(Ok (processed_info ~sharpness:41.5)))
        (fun () ->
          send (Selected [ camera_photo ]);
          (* The affirmative arm on the same fixture: a flow still holding the
             photo it measured has released nothing, so the list below is what
             the empty selection let go of rather than every handle the flow has
             ever named. *)
          Alcotest.(check string)
            "the flow is holding a measured photo before the picker empties"
            "Ready"
            (stage_name !current.stage);
          Alcotest.(check (list string))
            "and has released nothing while that photo is still its to send" []
            (released ());
          send (Selected [])));
  Alcotest.(check string)
    "clearing the picker returns the flow to its untouched stage" "Idle"
    (stage_name !current.stage);
  Alcotest.(check (list string))
    "and releases the cleared photo and the encode measured from it"
    [ camera_photo.E.blob_id; processed_handle ]
    (released ())

(* A photo replaced by another. The handles let go of here are superseded rather
   than discarded, which is what makes the exact list the claim: a transition
   that released the photo it had just picked, or the encode the replacement is
   about to produce, would satisfy every count that could be written instead. *)
let test_replacing_the_selection_releases_the_superseded_handles () =
  let current, send = driver () in
  with_retention_backend (fun () ->
      with_image_backend
        (keyed_image_backend
           [
             (camera_photo.E.blob_id, Ok (processed_info ~sharpness:41.5));
             (other_photo.E.blob_id, Ok (replacement_info ~sharpness:41.5));
           ])
        (fun () ->
          send (Selected [ camera_photo ]);
          Alcotest.(check string)
            "the first photo is measured before it is replaced" "Ready"
            (stage_name !current.stage);
          Alcotest.(check (list string))
            "and nothing has been released up to that point" [] (released ());
          send (Selected [ other_photo ])));
  Alcotest.(check string)
    "the replacement is what the flow ends up describing" "IMG_0043.jpg"
    (selected_name !current);
  Alcotest.(check (list string))
    "the superseded photo and its encode are released, and the replacement's \
     own handles are not"
    [ camera_photo.E.blob_id; processed_handle ]
    (released ())

(* A photo sent back for another shot. The pass stored an encode before it
   answered and the retake branch is the one exit that never offers to send it,
   so the entry is released as the score is rejected rather than waiting for a
   replacement that may never be picked. The photo itself stays picked - the flow
   still names it in its readout - so what is owed here is one release and not
   two. *)
let test_a_retake_releases_the_encode_it_discards () =
  let sharp_current, sharp_send = driver () in
  with_retention_backend (fun () ->
      with_image_backend
        (image_backend ~calls:(ref [])
           ~outcome:(Ok (processed_info ~sharpness:41.5)))
        (fun () -> sharp_send (Selected [ camera_photo ])));
  (* The affirmative arm: the same pass over the same photo, scored on the other
     side of the threshold, releases nothing at all - so the release below
     belongs to the retake branch rather than to having processed a photo. *)
  Alcotest.(check string)
    "a sharp enough photo is ready to upload" "Ready"
    (stage_name !sharp_current.stage);
  Alcotest.(check (list string))
    "and a pass whose encode the flow is going to send releases nothing" []
    (released ());
  let current, send = driver () in
  with_retention_backend (fun () ->
      with_image_backend
        (image_backend ~calls:(ref [])
           ~outcome:(Ok (processed_info ~sharpness:3.5)))
        (fun () -> send (Selected [ camera_photo ])));
  Alcotest.(check string)
    "a blurry photo is sent back for another shot" "Retake"
    (stage_name !current.stage);
  Alcotest.(check string)
    "with the photo still picked" "IMG_0042.jpg" (selected_name !current);
  Alcotest.(check (list string))
    "and the encode it will never send released, the picked photo left alone"
    [ processed_handle ] (released ())

let () =
  Alcotest.run "Nopal_image"
    [
      ( "Processing flow",
        [
          Alcotest.test_case "the flow branches on sharpness" `Quick
            test_flow_branches_on_sharpness;
          Alcotest.test_case "accept uploads the processed handle" `Quick
            test_accept_uploads_processed_handle;
        ] );
      ( "Release discipline",
        [
          Alcotest.test_case "clearing the picker releases the handles it held"
            `Quick test_clearing_the_picker_releases_the_handles_it_held;
          Alcotest.test_case
            "replacing the selection releases the superseded handles" `Quick
            test_replacing_the_selection_releases_the_superseded_handles;
          Alcotest.test_case "a retake releases the encode it discards" `Quick
            test_a_retake_releases_the_encode_it_discards;
        ] );
    ]

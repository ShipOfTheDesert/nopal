open Nopal_test.Test_renderer
module E = Nopal_element.Element
module Processing = Nopal_image.Processing

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

let update model msg =
  match msg with
  | Selected [] -> ({ selected = None; stage = Idle }, Nopal_mvu.Cmd.none)
  | Selected (file :: _) ->
      ( { selected = Some file; stage = Measuring },
        Processing.process ~blob_id:file.E.blob_id ~config:(capture_config ())
          (fun result -> Processed result) )
  | Processed (Ok info) ->
      let stage =
        match Float.compare info.Processing.sharpness sharp_enough >= 0 with
        | true -> Ready info
        | false -> Retake info.Processing.sharpness
      in
      ({ model with stage }, Nopal_mvu.Cmd.none)
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

let processed_handle = "blob-processed-9f2"

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
    ]

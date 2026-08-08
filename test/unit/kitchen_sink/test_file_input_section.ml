open Nopal_test.Test_renderer
module Sub = Kitchen_sink_app__Sub_file_input
module Harness = Nopal_test.Telemetry_test
module E = Nopal_element.Element

let app_module =
  (module Sub : Nopal_mvu.App.S
    with type model = Sub.model
     and type msg = Sub.msg)

let vp = Nopal_element.Viewport.desktop
let picker = By_attr ("data-field", "receipt-image")
let readout = By_attr ("data-testid", "file-input-selection")
let upload_button = By_attr ("data-field", "receipt-upload")
let dangling_button = By_attr ("data-field", "receipt-upload-dangling")
let status = By_attr ("data-testid", "file-input-upload-status")

(* A selection as the renderer would hand it over: an opaque store handle plus
   user-agent metadata. Built directly, which is the whole point of keeping
   [file_info] platform-free. *)
let receipt =
  E.file_info ~blob_id:"blob-1" ~name:"receipt-sample.txt" ~size:13
    ~mime:"text/plain" ~last_modified:1_700_000_000_000.

let pp_selector fmt sel =
  match sel with
  | By_tag t -> Format.fprintf fmt "By_tag %S" t
  | By_text t -> Format.fprintf fmt "By_text %S" t
  | By_attr (k, v) -> Format.fprintf fmt "By_attr (%S, %S)" k v
  | First_child -> Format.fprintf fmt "First_child"
  | Nth_child n -> Format.fprintf fmt "Nth_child %d" n

let error_testable =
  Alcotest.testable
    (fun fmt e ->
      match e with
      | Not_found sel -> Format.fprintf fmt "Not_found (%a)" pp_selector sel
      | No_handler { tag; event } ->
          Format.fprintf fmt "No_handler { tag = %S; event = %S }" tag event)
    ( = )

let model0 () = fst (Sub.init ())

(* Renders [model], simulates a selection of [files] against the picker, and
   folds the dispatched message back through [update] — the full
   selection -> model -> view loop the section exists to demonstrate. *)
let select files model =
  let r = render (Sub.view vp model) in
  Alcotest.(check (result unit error_testable))
    "selection simulated" (Ok ())
    (select_files picker files r);
  match messages r with
  | [ m ] -> fst (Sub.update model m)
  | [] -> Alcotest.fail "selection dispatched no message"
  | _ :: _ :: _ -> Alcotest.fail "selection dispatched more than one message"

let readout_text model =
  match find readout (tree (render (Sub.view vp model))) with
  | Some node -> text_content node
  | None -> Alcotest.fail "file-input-selection element missing"

let shows model ~sub = Test_util.string_contains (readout_text model) ~sub

let status_text model =
  match find status (tree (render (Sub.view vp model))) with
  | Some node -> text_content node
  | None -> Alcotest.fail "file-input-upload-status element missing"

let test_lists_selected_file_metadata () =
  let model = select [ receipt ] (model0 ()) in
  Alcotest.(check bool)
    "lists the file name" true
    (shows model ~sub:"receipt-sample.txt");
  Alcotest.(check bool) "lists the byte size" true (shows model ~sub:"13 bytes");
  Alcotest.(check bool)
    "lists the reported mime" true
    (shows model ~sub:"text/plain")

(* Clearing the picker must fire the handler with [[]] rather than dispatching
   nothing, so the readout cannot keep showing a file the user has dropped. The
   pre-clear assertion is the affirmative arm: without it this case would stay
   green even if the fixture never reached the readout in the first place. *)
let test_clears_on_empty_selection () =
  let selected = select [ receipt ] (model0 ()) in
  Alcotest.(check bool)
    "file is shown before clearing" true
    (shows selected ~sub:"receipt-sample.txt");
  let cleared = select [] selected in
  Alcotest.(check bool)
    "file is gone after clearing" false
    (shows cleared ~sub:"receipt-sample.txt");
  Alcotest.(check string)
    "readout falls back to the empty state" "No file selected"
    (readout_text cleared)

(* The browser spec reads the selection out of the serialized model by
   substring, so every field has to be bounded by its trailing ';' — otherwise
   [file_size=13;] would be satisfiable by a 130-byte file and the spec would
   pass on a value it never meant. Asserting through the harness keeps the
   delimiter in the assertion, which is the half that actually enforces it. *)
let test_serialized_model_delimits_each_field () =
  let cleared, events =
    Harness.run_with_telemetry app_module ~serialize_model:Sub.serialize_model
      [ Sub.Selected [ receipt ]; Sub.Selected [] ]
  in
  Harness.assert_model_contains events ~fragment:"file_count=1;";
  Harness.assert_model_contains events
    ~fragment:"file_name=\"receipt-sample.txt\";";
  Harness.assert_model_contains events ~fragment:"file_mime=\"text/plain\";";
  Harness.assert_model_contains events ~fragment:"file_size=13;";
  let final = Sub.serialize_model cleared in
  Alcotest.(check bool)
    "cleared selection reports an empty count" true
    (Test_util.string_contains final ~sub:"file_count=0;");
  Alcotest.(check bool)
    "cleared selection carries no file fields" false
    (Test_util.string_contains final ~sub:"file_name=")

(* Installs [backend] for the duration of [f] and restores the default
   afterwards, so a failing assertion cannot leak a stub into the next case. *)
let with_backend backend f =
  Fun.protect
    ~finally:(fun () -> Nopal_http.register_backend Nopal_http.default_backend)
    (fun () ->
      Nopal_http.register_backend backend;
      f ())

let single_message r =
  match messages r with
  | [ m ] -> m
  | [] -> Alcotest.fail "click dispatched no message"
  | _ :: _ :: _ -> Alcotest.fail "click dispatched more than one message"

(* First file part's handle, or [None] when the body carries only string fields.
   Written as a total fold so the stub below never reaches for a partial list
   function to read what the section put on the wire. *)
let rec first_file_handle parts =
  match parts with
  | [] -> None
  | Nopal_http.File { blob_id; _ } :: _ -> Some blob_id
  | Nopal_http.Field _ :: rest -> first_file_handle rest

(* Clicks [selector] on [model]'s view, folds the dispatched message through
   [update], then runs the resulting command against a backend that captures the
   request verbatim and answers with [outcome]. Returns the captured request and
   the model after the whole exchange, so a case can assert on the wire and on
   what the reply did to the model. *)
let click_and_capture selector ~outcome model =
  let r = render (Sub.view vp model) in
  Alcotest.(check (result unit error_testable))
    "upload click simulated" (Ok ()) (click selector r);
  let captured = ref None in
  let final = ref model in
  (* [Nopal_http.send] reads the registered backend when the command is BUILT,
     not when it runs, so the stub has to be installed before [update] — not
     merely before [Cmd.execute]. *)
  with_backend
    {
      Nopal_http.send =
        (fun request ->
          captured := Some request;
          Nopal_mvu.Task.return outcome);
    }
    (fun () ->
      let clicked, cmd = Sub.update model (single_message r) in
      final := clicked;
      Nopal_mvu.Cmd.execute (fun m -> final := fst (Sub.update !final m)) cmd);
  (!captured, !final)

(* The upload leg the whole feature exists for: the picked file travels to the
   backend as a handle beside a plain string field, and the metadata the readout
   shows is the metadata the server is told about. *)
let test_upload_sends_multipart_with_selected_file () =
  (* Nothing picked is the other arm of the same collapse: there is no file to
     name, so no request may go out — a body carrying only the caption would
     read to the server as a deliberate fileless upload. The selected case below
     is this absence assertion's affirmative arm. *)
  let empty_request, _ =
    click_and_capture upload_button
      ~outcome:(Ok { Nopal_http.status = 201; body = ""; headers = [] })
      (model0 ())
  in
  Alcotest.(check bool)
    "no request without a selection" true
    (Option.is_none empty_request);
  let selected = select [ receipt ] (model0 ()) in
  let request, final =
    click_and_capture upload_button
      ~outcome:(Ok { Nopal_http.status = 201; body = ""; headers = [] })
      selected
  in
  match request with
  | None -> Alcotest.fail "upload issued no request"
  | Some request ->
      (match request.Nopal_http.meth with
      | Nopal_http.POST -> ()
      | Nopal_http.GET
      | Nopal_http.PUT
      | Nopal_http.DELETE
      | Nopal_http.PATCH ->
          Alcotest.fail "upload must POST");
      (match request.Nopal_http.body with
      | Nopal_http.Multipart
          [
            Nopal_http.Field (field_name, field_value);
            Nopal_http.File { name; blob_id; filename; mime };
          ] ->
          Alcotest.(check string) "string field name" "caption" field_name;
          Alcotest.(check string)
            "string field value" "kitchen sink receipt" field_value;
          Alcotest.(check string) "file part field name" "receipt" name;
          Alcotest.(check string)
            "file part names the selected blob" "blob-1" blob_id;
          Alcotest.(check (option string))
            "file part filename" (Some "receipt-sample.txt") filename;
          Alcotest.(check (option string))
            "file part mime" (Some "text/plain") mime
      | Nopal_http.Multipart _
      | Nopal_http.String _
      | Nopal_http.Json _
      | Nopal_http.Form_encoded _
      | Nopal_http.Empty ->
          Alcotest.fail
            "expected a Multipart body of exactly [ Field _; File _ ] in order");
      Alcotest.(check bool)
        "the reply reaches the model" true
        (Test_util.string_contains
           (Sub.serialize_model final)
           ~sub:"upload=ok:201;")

(* The dangling-handle path, driven through the real MVU loop so the command the
   button returns is actually executed. The stub answers the way the web backend
   does — it reads the handle off the wire — so this fails if the section stops
   sending a fabricated one rather than passing on a hardcoded expectation. *)
let test_dangling_handle_surfaces_invalid_blob () =
  let invalid_blob_backend =
    {
      Nopal_http.send =
        (fun request ->
          let outcome =
            match request.Nopal_http.body with
            | Nopal_http.Multipart parts -> (
                match first_file_handle parts with
                | Some handle -> Error (Nopal_http.Invalid_blob handle)
                | None ->
                    Error
                      (Nopal_http.Network_error
                         "upload sent no file part to fail on"))
            | Nopal_http.String _
            | Nopal_http.Json _
            | Nopal_http.Form_encoded _
            | Nopal_http.Empty ->
                Error (Nopal_http.Network_error "upload sent no multipart body")
          in
          Nopal_mvu.Task.return outcome);
    }
  in
  (* Taken from the button rather than written down, so this fails if the
     failure path stops being reachable from the UI. *)
  let dangling_msg =
    let r = render (Sub.view vp (model0 ())) in
    Alcotest.(check (result unit error_testable))
      "dangling upload click simulated" (Ok ()) (click dangling_button r);
    single_message r
  in
  let events =
    with_backend invalid_blob_backend (fun () ->
        snd
          (Harness.run_with_telemetry app_module
             ~serialize_model:Sub.serialize_model [ dangling_msg ]))
  in
  Harness.assert_model_contains events
    ~fragment:"upload=error:invalid_blob:\"no-such-receipt-blob\";";
  (* The E2E reads these fragments by substring, so a network failure must not be
     readable as the dangling-handle failure. The assertion above is the
     affirmative arm that keeps the absence below from going vacuous. *)
  let network_status =
    Sub.serialize_model
      (fst
         (Sub.update (model0 ())
            (Sub.Upload_result
               (Error (Nopal_http.Network_error "connection refused")))))
  in
  Alcotest.(check bool)
    "a network failure carries its own tag" true
    (Test_util.string_contains network_status ~sub:"upload=error:network;");
  Alcotest.(check bool)
    "a network failure is not readable as a dangling handle" false
    (Test_util.string_contains network_status ~sub:"invalid_blob")

(* The status line is where the outcome becomes something a person can read, and
   it is the only surface [Nopal_http.message] reaches in this app. Every state
   is driven through [update] rather than constructed, so a state the section can
   no longer reach cannot keep a rendering alive here. *)
let test_status_line_renders_every_outcome () =
  let after msg = fst (Sub.update (model0 ()) msg) in
  let renders model ~sub = Test_util.string_contains (status_text model) ~sub in
  Alcotest.(check bool)
    "before any upload" true
    (renders (model0 ()) ~sub:"No upload yet");
  Alcotest.(check bool)
    "in flight" true
    (renders
       ( select [ receipt ] (model0 ()) |> fun m ->
         fst (Sub.update m Sub.Upload_clicked) )
       ~sub:"Uploading");
  Alcotest.(check bool)
    "success names the status code" true
    (renders
       (after
          (Sub.Upload_result
             (Ok { Nopal_http.status = 201; body = ""; headers = [] })))
       ~sub:"Uploaded (HTTP 201)");
  (* Rendered via [Nopal_http.message], so the handle a developer needs in order
     to find the released blob is on screen and not only in telemetry. *)
  Alcotest.(check bool)
    "a dangling handle is named on screen" true
    (renders
       (after (Sub.Upload_result (Error (Nopal_http.Invalid_blob "blob-gone"))))
       ~sub:"blob-gone");
  Alcotest.(check bool)
    "a network failure carries its own detail" true
    (renders
       (after
          (Sub.Upload_result
             (Error (Nopal_http.Network_error "connection refused"))))
       ~sub:"connection refused")

let () =
  Alcotest.run "kitchen_sink_file_input_section"
    [
      ( "selection",
        [
          Alcotest.test_case "lists selected file metadata" `Quick
            test_lists_selected_file_metadata;
          Alcotest.test_case "clears on empty selection" `Quick
            test_clears_on_empty_selection;
        ] );
      ( "upload",
        [
          Alcotest.test_case "upload sends multipart with the selected file"
            `Quick test_upload_sends_multipart_with_selected_file;
          Alcotest.test_case
            "dangling handle surfaces Invalid_blob in the model" `Quick
            test_dangling_handle_surfaces_invalid_blob;
          Alcotest.test_case "status line renders every outcome" `Quick
            test_status_line_renders_every_outcome;
        ] );
      ( "telemetry",
        [
          Alcotest.test_case "serialized model delimits each field" `Quick
            test_serialized_model_delimits_each_field;
        ] );
    ]

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
      ( "telemetry",
        [
          Alcotest.test_case "serialized model delimits each field" `Quick
            test_serialized_model_delimits_each_field;
        ] );
    ]

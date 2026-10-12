(* The clipboard kitchen-sink section, read structurally.

   What this file can see is the request and the outcome as the MVU loop
   carries them: a click on Copy asks for one write of the key the section
   shows, and each outcome fed back through the extracted callback renders its
   own status. What it cannot see is a platform writing anything — no clipboard
   exists here — which is the browser spec's job.

   Every message is taken from a rendered handler or from the extracted
   callback rather than named here, so a Copy button that stopped dispatching,
   or an outcome the section no longer routes, fails here instead of leaving a
   case driving the section by a message its view cannot produce. *)

open Nopal_test.Test_renderer
module Sub = Kitchen_sink_app__Sub_clipboard

let vp = Nopal_element.Viewport.desktop
let fake_key = "nopal-test-key-7Q2"
let copy_button = By_attr ("data-testid", "clipboard-copy")
let key_text = By_attr ("data-testid", "clipboard-key")
let status = By_attr ("data-testid", "clipboard-status")

let node_in label selector rendered =
  match find selector (tree rendered) with
  | Some node -> node
  | None -> Alcotest.fail (label ^ ": the section renders no such element")

let rendered_for model = render (Sub.view vp model)

(* The messages a click on Copy dispatches, in order. *)
let copy_click_messages model =
  let rendered = rendered_for model in
  match click copy_button rendered with
  | Ok () -> messages rendered
  | Error (Not_found _) -> Alcotest.fail "the Copy button is missing"
  | Error (No_handler { tag; event }) ->
      Alcotest.fail
        (Printf.sprintf "the Copy %s element handles no %s" tag event)

(* Every clipboard write the click's messages asked for, in issue order. *)
let writes_after_click model =
  List.concat_map
    (fun msg ->
      Nopal_mvu.Cmd.extract_clipboard_writes (snd (Sub.update model msg)))
    (copy_click_messages model)

(* The single write a click on Copy asks for. *)
let the_write model =
  match writes_after_click model with
  | [ write ] -> write
  | writes ->
      Alcotest.failf "a click on Copy asked for %d writes, expected 1"
        (List.length writes)

(* The outcome message for [result], built by the section's own callback. *)
let outcome_msg result =
  let model, _ = Sub.init () in
  let _text, on_result = the_write model in
  on_result result

let status_after result =
  let model, _ = Sub.init () in
  let model, _ = Sub.update model (outcome_msg result) in
  let node = node_in "the status" status (rendered_for model) in
  (attr "data-status" node, text_content node)

let status_testable = Alcotest.(pair (option string) string)

let test_copy_button_click_records_write () =
  let model, _ = Sub.init () in
  let shown = text_content (node_in "the key" key_text (rendered_for model)) in
  Alcotest.(check string) "the section shows the fake key" fake_key shown;
  Alcotest.(check (list string))
    "one click asks for exactly one write, of the shown key" [ shown ]
    (List.map fst (writes_after_click model))

let test_initial_status_is_idle () =
  let model, _ = Sub.init () in
  let node = node_in "the status" status (rendered_for model) in
  Alcotest.check status_testable "nothing is reported before a click"
    (Some "idle", "Not copied yet")
    (attr "data-status" node, text_content node)

let test_ok_outcome_shows_copied_status () =
  Alcotest.check status_testable "a successful write says so"
    (Some "copied", "Copied to the clipboard")
    (status_after (Ok ()))

let test_not_permitted_shows_its_status () =
  Alcotest.check status_testable "a refused write says it was refused"
    (Some "not-permitted", "Not copied: the platform refused the write")
    (status_after (Error Nopal_mvu.Clipboard.Not_permitted))

let test_unavailable_shows_its_status () =
  Alcotest.check status_testable "a missing clipboard says it is missing"
    (Some "unavailable", "Not copied: no clipboard is available here")
    (status_after (Error Nopal_mvu.Clipboard.Unavailable))

let test_failed_shows_its_status () =
  Alcotest.check status_testable "any other failure shows the platform's reason"
    (Some "failed", "Not copied: disk on fire")
    (status_after (Error (Nopal_mvu.Clipboard.Failed "disk on fire")))

(* Each outcome's serialised message is pinned whole, which is the affirmative
   arm: the absence check beside it cannot pass on an empty string. *)
let test_outcome_message_omits_key () =
  let cases =
    [
      (Ok (), "Clipboard:Copy_result:Ok;");
      ( Error Nopal_mvu.Clipboard.Not_permitted,
        "Clipboard:Copy_result:Error Not_permitted;" );
      ( Error Nopal_mvu.Clipboard.Unavailable,
        "Clipboard:Copy_result:Error Unavailable;" );
      ( Error (Nopal_mvu.Clipboard.Failed "disk on fire"),
        "Clipboard:Copy_result:Error Failed \"disk on fire\";" );
    ]
  in
  List.iter
    (fun (result, expected) ->
      let serialised = Sub.serialize_msg (outcome_msg result) in
      Alcotest.(check string) "the outcome is named" expected serialised;
      Alcotest.(check bool)
        "the outcome does not carry the key" false
        (Test_util.string_contains serialised ~sub:fake_key))
    cases

let () =
  Alcotest.run "kitchen_sink_clipboard_section"
    [
      ( "request",
        [
          Alcotest.test_case "copy_button_click_records_write" `Quick
            test_copy_button_click_records_write;
          Alcotest.test_case "outcome_message_omits_key" `Quick
            test_outcome_message_omits_key;
        ] );
      ( "status",
        [
          Alcotest.test_case "initial_status_is_idle" `Quick
            test_initial_status_is_idle;
          Alcotest.test_case "ok_outcome_shows_copied_status" `Quick
            test_ok_outcome_shows_copied_status;
          Alcotest.test_case "each_error_arm: Not_permitted" `Quick
            test_not_permitted_shows_its_status;
          Alcotest.test_case "each_error_arm: Unavailable" `Quick
            test_unavailable_shows_its_status;
          Alcotest.test_case "each_error_arm: Failed" `Quick
            test_failed_shows_its_status;
        ] );
    ]

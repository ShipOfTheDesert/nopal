(* The runtime's clipboard handler: what a runtime does with a write when the
   backend supplies no handler, and what telemetry records when it does.

   The app's model is every message it has received, in order, so each
   assertion checks the full dispatch list rather than whether something
   arrived. The copied text is a distinctive fake key, so its absence from the
   telemetry log can only mean it was never written there. *)

module Telemetry = Nopal_runtime.Telemetry
module Clipboard = Nopal_mvu.Clipboard

let fake_key = "nopal-test-key-7Q2"

type msg = Copy | Copied of (unit, Clipboard.error) result

let show_outcome = function
  | Ok () -> "Ok ()"
  | Error Clipboard.Not_permitted -> "Error Not_permitted"
  | Error Unavailable -> "Error Unavailable"
  | Error (Failed reason) -> Printf.sprintf "Error (Failed %S)" reason

let show_msg = function
  | Copy -> "Copy"
  | Copied r -> "Copied (" ^ show_outcome r ^ ")"

let msg =
  Alcotest.testable (fun fmt m -> Format.pp_print_string fmt (show_msg m)) ( = )

let event = Alcotest.testable (fun fmt e -> Telemetry.pp_events fmt [ e ]) ( = )

module Copier : Nopal_mvu.App.S with type model = msg list and type msg = msg =
struct
  type model = msg list
  type nonrec msg = msg

  let init () = ([], Nopal_mvu.Cmd.none)

  let update received m =
    let cmd =
      match m with
      | Copy ->
          Nopal_mvu.Cmd.write_clipboard fake_key ~on_result:(fun r -> Copied r)
      | Copied _ -> Nopal_mvu.Cmd.none
    in
    (received @ [ m ], cmd)

  let view _vp _model = Nopal_element.Element.empty
  let subscriptions _model = Nopal_mvu.Sub.none
end

module R = Nopal_runtime.Runtime.Make (Copier)

(* A backend with no clipboard must still answer the request, once. The
   affirmative arm builds the same app with a handler and sees that handler's
   answer instead, so the [Unavailable] above is the default speaking and not
   an update that issued nothing. *)
let test_default_write_clipboard_resolves_unavailable () =
  let errors = ref [] in
  let rt = R.create ~on_error:(fun e -> errors := e :: !errors) () in
  R.start rt;
  R.dispatch rt Copy;
  Alcotest.(check (list msg))
    "the write resolves as unavailable, exactly once"
    [ Copy; Copied (Error Unavailable) ]
    (R.model rt);
  Alcotest.(check (list string)) "and reports nothing" [] !errors;
  let texts = ref [] in
  let supplied =
    R.create
      ~write_clipboard:(fun text resolve ->
        texts := !texts @ [ text ];
        resolve (Ok ()))
      ()
  in
  R.start supplied;
  R.dispatch supplied Copy;
  Alcotest.(check (list msg))
    "a runtime given a handler resolves with the handler's answer"
    [ Copy; Copied (Ok ()) ] (R.model supplied);
  Alcotest.(check (list string))
    "which received the text once" [ fake_key ] !texts

(* The first assertion is the affirmative arm: the full log, with the command
   recorded under its label and the outcome message after it. Only then does
   the absence of the key mean anything. The handler also proves that
   [create_with_telemetry] routes the request rather than only recording it. *)
let test_telemetry_command_event_omits_text () =
  let texts = ref [] in
  let rt, handle =
    R.create_with_telemetry
      ~write_clipboard:(fun text resolve ->
        texts := !texts @ [ text ];
        resolve (Error Not_permitted))
      ~serialize_msg:show_msg
      ~serialize_model:(fun received -> string_of_int (List.length received))
      ()
  in
  R.start rt;
  R.dispatch rt Copy;
  let events = Telemetry.events handle in
  Alcotest.(check (list event))
    "the write is recorded under its label, followed by its outcome"
    [
      Telemetry.Message "Copy";
      Telemetry.Model_transition { before = "0"; after = "1" };
      Telemetry.Command "write_clipboard";
      Telemetry.Message "Copied (Error Not_permitted)";
      Telemetry.Model_transition { before = "1"; after = "2" };
    ]
    events;
  Alcotest.(check (list string))
    "the recording runtime routed the text to its handler" [ fake_key ] !texts;
  Alcotest.(check (list string))
    "no recorded event carries the copied text" []
    (List.filter_map
       (fun e ->
         let printed = Format.asprintf "%a" Telemetry.pp_events [ e ] in
         if Test_util.string_contains printed ~sub:fake_key then Some printed
         else None)
       events)

let test_handler_resolving_twice_gives_one_message () =
  let rt =
    R.create
      ~write_clipboard:(fun _ resolve ->
        resolve (Ok ());
        resolve (Error Clipboard.Not_permitted))
      ()
  in
  R.start rt;
  R.dispatch rt Copy;
  Alcotest.(check (list msg))
    "only the first outcome is delivered" [ Copy; Copied (Ok ()) ] (R.model rt)

let test_handler_raising_gives_one_failed () =
  let errors = ref [] in
  let rt =
    R.create
      ~on_error:(fun e -> errors := e :: !errors)
      ~write_clipboard:(fun _ _ -> failwith "boom")
      ()
  in
  R.start rt;
  R.dispatch rt Copy;
  (match R.model rt with
  | [ Copy; Copied (Error (Failed reason)) ] ->
      Alcotest.(check bool)
        "the reason omits the copied text" false
        (Test_util.string_contains reason ~sub:fake_key)
  | other ->
      Alcotest.failf "expected one Failed, got %s"
        (String.concat "; " (List.map show_msg other)));
  Alcotest.(check (list string)) "and reports no fault" [] !errors

let () =
  Alcotest.run "runtime_clipboard"
    [
      ( "write_clipboard",
        [
          Alcotest.test_case "default resolves Unavailable" `Quick
            test_default_write_clipboard_resolves_unavailable;
          Alcotest.test_case "telemetry command event omits text" `Quick
            test_telemetry_command_event_omits_text;
          Alcotest.test_case "handler resolving twice gives one message" `Quick
            test_handler_resolving_twice_gives_one_message;
          Alcotest.test_case "handler raising gives one Failed" `Quick
            test_handler_raising_gives_one_failed;
        ] );
    ]

module Telemetry = Nopal_runtime.Telemetry

let event_to_jv (event : Telemetry.event) : Jv.t =
  match event with
  | Telemetry.Message value ->
      Jv.obj
        [| ("kind", Jv.of_string "message"); ("value", Jv.of_string value) |]
  | Telemetry.Model_transition { before; after } ->
      Jv.obj
        [|
          ("kind", Jv.of_string "model_transition");
          ("before", Jv.of_string before);
          ("after", Jv.of_string after);
        |]
  | Telemetry.Command value ->
      Jv.obj
        [| ("kind", Jv.of_string "command"); ("value", Jv.of_string value) |]
  | Telemetry.Subscription value ->
      Jv.obj
        [|
          ("kind", Jv.of_string "subscription"); ("value", Jv.of_string value);
        |]

let events_to_jv events = Jv.of_list event_to_jv events

let event_of_jv jv : (Telemetry.event, string) result =
  (* [kind] is a string tag, not a closed OCaml variant, so a catch-all arm for
     an unrecognised tag is the correct total handling, not an elision. *)
  match Jv.to_string (Jv.get jv "kind") with
  | "message" -> Ok (Telemetry.Message (Jv.to_string (Jv.get jv "value")))
  | "model_transition" ->
      Ok
        (Telemetry.Model_transition
           {
             before = Jv.to_string (Jv.get jv "before");
             after = Jv.to_string (Jv.get jv "after");
           })
  | "command" -> Ok (Telemetry.Command (Jv.to_string (Jv.get jv "value")))
  | "subscription" ->
      Ok (Telemetry.Subscription (Jv.to_string (Jv.get jv "value")))
  | other ->
      Error
        (Printf.sprintf "nopal_telemetry_wire: unknown telemetry event kind %S"
           other)

let events_of_jv arr : (Telemetry.event list, string) result =
  List.fold_right
    (fun jv acc ->
      match acc with
      | Error _ as e -> e
      | Ok events -> (
          match event_of_jv jv with
          | Ok event -> Ok (event :: events)
          | Error _ as e -> e))
    (Jv.to_list Fun.id arr) (Ok [])

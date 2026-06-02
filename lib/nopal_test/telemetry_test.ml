module Telemetry = Nopal_runtime.Telemetry

(* Substring test — the fragment-matching contract shared with the Playwright
   side (TS [String.includes]). [needle] empty matches anything. *)
let contains haystack needle =
  let nlen = String.length needle and hlen = String.length haystack in
  if nlen = 0 then true
  else if nlen > hlen then false
  else
    let rec at i =
      if i + nlen > hlen then false
      else if String.sub haystack i nlen = needle then true
      else at (i + 1)
    in
    at 0

(* Raise [Failure] with the unmet expectation followed by a dump of the actual
   recorded events, so a failing assertion is self-diagnosing (REQ-F3). *)
let fail_unmet description events =
  failwith
    (Format.asprintf "@[<v>%s@,actual events:@,%a@]" description
       Telemetry.pp_events events)

let run_with_telemetry (type model msg)
    (module A : Nopal_mvu.App.S with type model = model and type msg = msg)
    ?serialize_msg ?serialize_model msgs =
  let module R = Nopal_runtime.Runtime.Make (A) in
  let rt, handle =
    R.create_with_telemetry ?serialize_msg ?serialize_model
      ~schedule_after:(fun _ms f -> f ())
      ()
  in
  Fun.protect
    ~finally:(fun () -> Telemetry.clear handle)
    (fun () ->
      R.start rt;
      (try List.iter (fun msg -> R.dispatch rt msg) msgs with
      | exn ->
          (* Capture the raw backtrace first so neither the dump nor [Fun.protect]'s
            cleanup can clobber it, then re-raise the SAME exception unchanged. *)
          let raw_bt = Printexc.get_raw_backtrace () in
          Format.eprintf
            "@[<v>run_with_telemetry: app raised; history so far:@,%a@]@."
            Telemetry.pp_events (Telemetry.events handle);
          Printexc.raise_with_backtrace exn raw_bt);
      (R.model rt, Telemetry.events handle))

let assert_dispatched events ~fragment =
  let matches = function
    | Telemetry.Message s -> contains s fragment
    | Telemetry.Model_transition _
    | Telemetry.Command _
    | Telemetry.Subscription _ ->
        false
  in
  if not (List.exists matches events) then
    fail_unmet
      (Printf.sprintf "no Message event contains fragment %S" fragment)
      events

let assert_sequence events ~fragments =
  (* Greedy in-order match: advance past each fragment when a [Message] contains
     it; non-[Message] events and unmatched [Message]s are skipped. *)
  let remaining =
    List.fold_left
      (fun pending event ->
        match (pending, event) with
        | fragment :: rest, Telemetry.Message s when contains s fragment -> rest
        | _, _ -> pending)
      fragments events
  in
  match remaining with
  | [] -> ()
  | missing :: _ ->
      fail_unmet
        (Printf.sprintf "fragment %S not found as a Message in order" missing)
        events

let assert_model_contains events ~fragment =
  let matches = function
    | Telemetry.Model_transition { after; before = _ } ->
        contains after fragment
    | Telemetry.Message _
    | Telemetry.Command _
    | Telemetry.Subscription _ ->
        false
  in
  if not (List.exists matches events) then
    fail_unmet
      (Printf.sprintf "no Model_transition.after contains fragment %S" fragment)
      events

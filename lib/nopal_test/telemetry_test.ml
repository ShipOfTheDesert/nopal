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
  (* The runtime now reports and swallows exceptions from its callback sites
     (REQ-F1) rather than letting them propagate, so the harness can no longer
     catch them at the [dispatch] boundary. Wrap the synchronous app-code
     callbacks ([update], [subscriptions]) to capture the first exception with
     its raw backtrace and re-raise it into the runtime's guard; the harness
     re-raises that SAME value after driving, preserving the dump-then-re-raise
     contract and physical identity. Failures the runtime only surfaces as a
     string — [Cmd] effect thunks, serialisers — are collected via [on_error]
     and reported as a [Failure] so the harness still fails loud. *)
  let app_exn = ref None in
  let reported = ref [] in
  let capture exn raw_bt =
    match !app_exn with
    | Some _ -> ()
    | None -> app_exn := Some (exn, raw_bt)
  in
  let module Wrapped :
    Nopal_mvu.App.S with type model = model and type msg = msg = struct
    include A

    let update m msg =
      try A.update m msg with
      | exn ->
          let raw_bt = Printexc.get_raw_backtrace () in
          capture exn raw_bt;
          Printexc.raise_with_backtrace exn raw_bt

    let subscriptions m =
      try A.subscriptions m with
      | exn ->
          let raw_bt = Printexc.get_raw_backtrace () in
          capture exn raw_bt;
          Printexc.raise_with_backtrace exn raw_bt
  end in
  let module R = Nopal_runtime.Runtime.Make (Wrapped) in
  let rt, handle =
    R.create_with_telemetry ?serialize_msg ?serialize_model
      ~schedule_after:(fun _ms f -> f ())
      ~on_error:(fun description -> reported := description :: !reported)
      ()
  in
  Fun.protect
    ~finally:(fun () -> Telemetry.clear handle)
    (fun () ->
      R.start rt;
      (* Drive until the first captured app exception, mirroring the old
         propagate-and-stop behaviour: once a callback has raised, later messages
         are not dispatched. *)
      let rec drive = function
        | [] -> ()
        | msg :: rest -> (
            R.dispatch rt msg;
            match !app_exn with
            | Some _ -> ()
            | None -> drive rest)
      in
      drive msgs;
      let dump () =
        Format.eprintf
          "@[<v>run_with_telemetry: app raised; history so far:@,%a@]@."
          Telemetry.pp_events (Telemetry.events handle)
      in
      match (!app_exn, !reported) with
      | Some (exn, raw_bt), _ ->
          dump ();
          Printexc.raise_with_backtrace exn raw_bt
      | None, (_ :: _ as descriptions) ->
          dump ();
          failwith
            (Format.asprintf
               "@[<v>run_with_telemetry: app reported errors:@,%a@]"
               (Format.pp_print_list Format.pp_print_string)
               (List.rev descriptions))
      | None, [] -> (R.model rt, Telemetry.events handle))

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

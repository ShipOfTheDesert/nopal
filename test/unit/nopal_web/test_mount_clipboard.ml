(* The web backend's clipboard write, driven through [mount].

   Each case mounts an app whose only button asks for the clipboard write of a
   fake key, clicks it, and reads back every message the app received, in
   order. The shim decides what the browser's Clipboard API looks like and
   parks every promise settlement until the case drains it, so "nothing was
   delivered yet" and "exactly one outcome" are both observable.

   The first case pins how each thing a browser can answer becomes the typed
   outcome. The second pins when the write is issued: inside the click's own
   dispatch, before any frame runs, because a browser grants the write only
   within the gesture's activation. The third pins exactly-once delivery when
   one write produces two candidate outcomes on two turns. The fourth pins that
   a failure reason never carries the copied text. The fifth pins that a handler
   passed to the mount replaces the browser one.

   Each case mounts with an id namespace of its own, because the shim's element
   registry is never pruned. *)

let key = "nopal-test-key-7Q2"

type msg = Copy | Copied of (unit, Nopal_mvu.Clipboard.error) result

let show_outcome = function
  | Ok () -> "Ok ()"
  | Error Nopal_mvu.Clipboard.Not_permitted -> "Error Not_permitted"
  | Error Nopal_mvu.Clipboard.Unavailable -> "Error Unavailable"
  | Error (Nopal_mvu.Clipboard.Failed reason) ->
      Printf.sprintf "Error (Failed %S)" reason

let show_msg = function
  | Copy -> "Copy"
  | Copied r -> "Copied (" ^ show_outcome r ^ ")"

let msg =
  Alcotest.testable (fun fmt m -> Format.pp_print_string fmt (show_msg m)) ( = )

module type IDS = sig
  val prefix : string
end

module Make_copier (I : IDS) = struct
  let trigger_id = I.prefix ^ "-copy"

  (* mutable: a mounted runtime's model cannot be read from outside the mount,
     so the app appends every message it receives here for the case to read. *)
  let received : msg list ref = ref []

  type model = unit
  type nonrec msg = msg

  let init () = ((), Nopal_mvu.Cmd.none)

  let update () m =
    received := !received @ [ m ];
    match m with
    | Copy ->
        ((), Nopal_mvu.Cmd.write_clipboard key ~on_result:(fun r -> Copied r))
    | Copied _ -> ((), Nopal_mvu.Cmd.none)

  let view _vp () =
    Nopal_element.Element.button
      ~attrs:[ ("id", trigger_id) ]
      ~button_type:Nopal_element.Element.Push ~disabled:false ~on_click:Copy
      (Nopal_element.Element.text "copy")

  let subscriptions () = Nopal_mvu.Sub.none

  let as_module :
      (module Nopal_mvu.App.S with type model = model and type msg = msg) =
    (module struct
      type nonrec model = model
      type nonrec msg = msg

      let init = init
      let update = update
      let view = view
      let subscriptions = subscriptions
    end)
end

type entry = Mount | Mount_with_telemetry

let show_entry = function
  | Mount -> "mount"
  | Mount_with_telemetry -> "mount_with_telemetry"

let fresh_parent () = Brr.El.v (Jstr.v "div") []
let document () = Jv.get Jv.global "document"
let by_id id = Jv.call (document ()) "getElementById" [| Jv.of_string id |]

let click id =
  let ev = Jv.new' (Jv.get Jv.global "Event") [| Jv.of_string "click" |] in
  ignore (Jv.call (by_id id) "dispatchEvent" [| ev |])

let shim () = Jv.get Jv.global "__nopal_clipboard"

let install ?(name = "") ?(message = "") mode =
  ignore
    (Jv.call (shim ()) "install"
       [| Jv.of_string mode; Jv.of_string name; Jv.of_string message |])

(* Run every parked promise settlement, to quiescence. *)
let flush () = ignore (Jv.call (shim ()) "flush" [||])

(* Click a copier's button and let every promise settlement it parked run. Only
   the case pinning what happens before settlement clicks without this. *)
let copy_and_settle trigger =
  click trigger;
  flush ()

(* The texts [writeText] was called with, in call order. *)
let write_calls () = Jv.to_list Jv.to_string (Jv.get (shim ()) "calls")

(* Mount a fresh copier through [entry] and return the messages it receives. *)
let mount_copier ?write_clipboard entry prefix =
  let module C = Make_copier (struct
    let prefix = prefix
  end) in
  (match entry with
  | Mount ->
      let _mounted : Nopal_web.mounted =
        Nopal_web.mount ?write_clipboard C.as_module (fresh_parent ())
      in
      ()
  | Mount_with_telemetry ->
      let _mounted : Nopal_web.mounted_with_telemetry =
        Nopal_web.mount_with_telemetry ?write_clipboard C.as_module
          (fresh_parent ())
      in
      ());
  (C.trigger_id, C.received)

let check_received label expected received =
  Alcotest.(check (list msg)) label expected !received

(* Each thing a browser can answer, and the outcome the app receives for it.
   The resolving case is the affirmative arm for the two [Unavailable] cases:
   the runtime's own fallback also answers [Unavailable], so only a case where
   the browser's API is present and answers proves the browser handler is the
   one installed. *)
let test_web_decode_maps_each_case () =
  let cases =
    [
      ( "decode-absent",
        (fun () -> install "absent"),
        Error Nopal_mvu.Clipboard.Unavailable );
      ( "decode-no-write-text",
        (fun () -> install "no_write_text"),
        Error Nopal_mvu.Clipboard.Unavailable );
      ( "decode-not-allowed",
        (fun () ->
          install ~name:"NotAllowedError" ~message:"Write permission denied."
            "reject"),
        Error Nopal_mvu.Clipboard.Not_permitted );
      ( "decode-other-name",
        (fun () ->
          install ~name:"DataError" ~message:"The data could not be written."
            "reject"),
        Error (Nopal_mvu.Clipboard.Failed "The data could not be written.") );
      ( "decode-throw",
        (fun () -> install ~message:"The receiver is unusable." "throw"),
        Error (Nopal_mvu.Clipboard.Failed "The receiver is unusable.") );
      ( "decode-reject-string",
        (fun () -> install ~message:"A bare string reason." "reject_string"),
        Error (Nopal_mvu.Clipboard.Failed "A bare string reason.") );
      ("decode-resolve", (fun () -> install "resolve"), Ok ());
    ]
  in
  List.iter
    (fun (prefix, setup, expected) ->
      setup ();
      let trigger, received = mount_copier Mount prefix in
      copy_and_settle trigger;
      check_received prefix [ Copy; Copied expected ] received)
    cases;
  (* A rejection that carries no reason at all still resolves, as a failure
     with something to show. *)
  List.iter
    (fun (mode, prefix) ->
      install mode;
      let trigger, received = mount_copier Mount prefix in
      copy_and_settle trigger;
      match !received with
      | [ Copy; Copied (Error (Nopal_mvu.Clipboard.Failed reason)) ] ->
          Alcotest.(check bool) "the reason is not empty" true (reason <> "")
      | other ->
          Alcotest.failf "expected [Copy; Copied (Error (Failed _))], got [%s]"
            (String.concat "; " (List.map show_msg other)))
    [
      ("reject_none", "decode-no-reason"); ("reject_null", "decode-null-reason");
    ]

(* The write reaches the browser before the click's dispatch returns: no frame
   runs in this case at all, and the outcome is still parked, so the call log
   can only have been written from inside the click. Both entry points. *)
let test_write_issued_within_dispatch () =
  List.iter
    (fun entry ->
      let label = show_entry entry in
      install "resolve";
      let trigger, received = mount_copier entry ("within-" ^ label) in
      click trigger;
      Alcotest.(check (list string))
        (label ^ ": writeText was called during the click")
        [ key ] (write_calls ());
      check_received
        (label ^ ": no outcome before the promise settles")
        [ Copy ] received;
      flush ();
      check_received
        (label ^ ": the outcome after it settles")
        [ Copy; Copied (Ok ()) ] received)
    [ Mount; Mount_with_telemetry ]

(* One write, two candidate outcomes: the platform's [then] throws after
   accepting the callbacks, and the promise it returned is already rejected and
   delivers on a later turn. The app sees the first and only the first. *)
let test_rejected_write_resolves_once () =
  install ~message:"The platform faulted." "reject_then_throw";
  let trigger, received = mount_copier Mount "once" in
  copy_and_settle trigger;
  flush ();
  check_received "exactly one outcome"
    [
      Copy; Copied (Error (Nopal_mvu.Clipboard.Failed "The platform faulted."));
    ]
    received

(* A failure reason is the platform's own words. Both ways a failure arrives —
   a rejection and a synchronous throw — are checked. *)
let test_failed_reason_never_contains_text () =
  let cases =
    [
      ( "reason-rejection",
        fun () ->
          install ~name:"DataError"
            ~message:"The request is not allowed by the user agent." "reject" );
      ( "reason-throw",
        fun () ->
          install ~message:"The request is not allowed by the user agent."
            "throw" );
      ( "reason-throw-string",
        fun () ->
          install ~message:"The request is not allowed by the user agent."
            "throw_string" );
    ]
  in
  List.iter
    (fun (prefix, setup) ->
      setup ();
      let trigger, received = mount_copier Mount prefix in
      copy_and_settle trigger;
      match !received with
      | [ Copy; Copied (Error (Nopal_mvu.Clipboard.Failed reason)) ] ->
          Alcotest.(check bool)
            (prefix ^ ": the reason is not empty")
            true (reason <> "");
          Alcotest.(check bool)
            (prefix ^ ": the reason does not contain the text")
            false
            (Test_util.string_contains reason ~sub:key)
      | other ->
          Alcotest.failf
            "%s: expected [Copy; Copied (Error (Failed _))], got [%s]" prefix
            (String.concat "; " (List.map show_msg other)))
    cases

(* A handler given to the mount is the one that runs. The browser's API is
   present and would answer [Ok], so a mount that ignored the handler would
   both call [writeText] and deliver a different outcome. Both entry points. *)
let test_mount_write_clipboard_override_is_used () =
  List.iter
    (fun entry ->
      let label = show_entry entry in
      install "resolve";
      (* mutable: the texts the supplied handler was asked to write. *)
      let asked = ref [] in
      let write_clipboard text resolve =
        asked := !asked @ [ text ];
        resolve (Error (Nopal_mvu.Clipboard.Failed "supplied handler"))
      in
      let trigger, received =
        mount_copier ~write_clipboard entry ("override-" ^ label)
      in
      copy_and_settle trigger;
      Alcotest.(check (list string))
        (label ^ ": the supplied handler was asked")
        [ key ] !asked;
      Alcotest.(check (list string))
        (label ^ ": the browser API was not called")
        [] (write_calls ());
      check_received
        (label ^ ": the supplied handler's outcome")
        [ Copy; Copied (Error (Nopal_mvu.Clipboard.Failed "supplied handler")) ]
        received)
    [ Mount; Mount_with_telemetry ]

let () =
  Alcotest.run "nopal_web mount clipboard"
    [
      ( "clipboard",
        [
          Alcotest.test_case "web_decode_maps_each_case" `Quick
            test_web_decode_maps_each_case;
          Alcotest.test_case "write_issued_within_dispatch" `Quick
            test_write_issued_within_dispatch;
          Alcotest.test_case "rejected_write_resolves_once" `Quick
            test_rejected_write_resolves_once;
          Alcotest.test_case "failed_reason_never_contains_text" `Quick
            test_failed_reason_never_contains_text;
          Alcotest.test_case "mount_write_clipboard_override_is_used" `Quick
            test_mount_write_clipboard_override_is_used;
        ] );
    ]

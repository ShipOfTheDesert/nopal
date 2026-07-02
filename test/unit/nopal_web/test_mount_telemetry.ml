(* Unit coverage for the [mount] / [mount_with_telemetry] / [drive] path in
   [nopal_web] (RFC 0110, Implementation Decision 2). [drive] is the ~110-line
   DOM-wiring helper both mount entry points share; until now only the Playwright
   specs exercised it. These tests run under the dom_shim + mount_shim (see
   mount_shim.js) so the synchronous startup — bridge install vs not, and that the
   driven runtime's handle actually records dispatched messages — is covered at
   the OCaml level too.

   These are backfilled tests for already-shipped code (C3 from the pre-PR
   review), not new behaviour. *)

module Telemetry = Nopal_runtime.Telemetry

(* A minimal interactive app: the view is a single button whose click dispatches
   [Increment], so a synthetic DOM click drives the real MVU loop. *)
module Counter_app = struct
  type model = int
  type msg = Increment

  let init () = (0, Nopal_mvu.Cmd.none)
  let update model Increment = (model + 1, Nopal_mvu.Cmd.none)

  let view _vp model =
    Nopal_element.Element.Button
      {
        style = Nopal_style.Style.default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        on_click = Some Increment;
        on_dblclick = None;
        child =
          Nopal_element.Element.Text
            { content = string_of_int model; text_style = None };
      }

  let subscriptions _model = Nopal_mvu.Sub.none
end

let counter_module :
    (module Nopal_mvu.App.S
       with type model = Counter_app.model
        and type msg = Counter_app.msg) =
  (module Counter_app)

let fresh_parent () = Brr.El.v (Jstr.v "div") []
let window () = Jv.get Jv.global "window"
let clear_bridge () = Jv.set (window ()) "__nopal_telemetry__" Jv.undefined
let bridge () = Jv.get (window ()) "__nopal_telemetry__"

(* Dispatch a synthetic click on the button [mount] rendered into [target] (its
   first child), driving the runtime through the same path a real click would. *)
let click_first_child target =
  let node = Jv.get (Jv.get (Brr.El.to_jv target) "childNodes") "0" in
  let ev = Jv.new' (Jv.get Jv.global "Event") [| Jv.of_string "click" |] in
  ignore (Jv.call node "dispatchEvent" [| ev |])

let serialize_increment = function
  | Counter_app.Increment -> "Increment"

(* [mount] installs no telemetry bridge (REQ-N2: the surface appears only on the
   explicit [mount_with_telemetry] opt-in). *)
let test_mount_installs_no_bridge () =
  clear_bridge ();
  let target = fresh_parent () in
  Nopal_web.mount counter_module target;
  Alcotest.(check bool)
    "window.__nopal_telemetry__ absent after plain mount" true
    (Jv.is_undefined (bridge ()))

(* [mount_with_telemetry] installs the bridge object with both query methods. *)
let test_mount_with_telemetry_installs_bridge () =
  clear_bridge ();
  let target = fresh_parent () in
  let _handle =
    Nopal_web.mount_with_telemetry counter_module
      ~serialize_msg:serialize_increment target
  in
  let b = bridge () in
  Alcotest.(check bool) "bridge present" true (not (Jv.is_undefined b));
  Alcotest.(check bool)
    "getEvents present" true
    (not (Jv.is_undefined (Jv.get b "getEvents")));
  Alcotest.(check bool)
    "waitForMessage present" true
    (not (Jv.is_undefined (Jv.get b "waitForMessage")))

(* The handle returned by [mount_with_telemetry] backs the runtime [drive]
   actually drives: a synthetic click is recorded as a [Message] + a
   [Model_transition] reflecting the new model. *)
let test_mount_with_telemetry_records_dispatch () =
  clear_bridge ();
  let target = fresh_parent () in
  let handle =
    Nopal_web.mount_with_telemetry counter_module
      ~serialize_msg:serialize_increment ~serialize_model:string_of_int target
  in
  click_first_child target;
  let events = Telemetry.events handle in
  let has_message =
    List.exists
      (function
        | Telemetry.Message "Increment" -> true
        | _ -> false)
      events
  in
  let has_transition =
    List.exists
      (function
        | Telemetry.Model_transition { before = "0"; after = "1" } -> true
        | _ -> false)
      events
  in
  Alcotest.(check bool) "Increment message recorded" true has_message;
  Alcotest.(check bool) "0 -> 1 transition recorded" true has_transition

(* [getEvents] is a NON-draining read (feature 0120 FR-7): a second call returns
   the same log, so it agrees with the Tauri host [get_telemetry] mirror (also
   non-draining). The log does not grow unbounded because
   [Nopal_runtime.Telemetry] drops oldest past its cap, not because the reader
   clears it. *)
let test_bridge_get_events_non_draining () =
  clear_bridge ();
  let target = fresh_parent () in
  let _handle =
    Nopal_web.mount_with_telemetry counter_module
      ~serialize_msg:serialize_increment target
  in
  click_first_child target;
  let b = bridge () in
  let first = Jv.call b "getEvents" [||] in
  Alcotest.(check bool)
    "first getEvents non-empty" true
    (Jv.Int.get first "length" > 0);
  let second = Jv.call b "getEvents" [||] in
  Alcotest.(check int)
    "second getEvents identical — non-draining"
    (Jv.Int.get first "length")
    (Jv.Int.get second "length")

let () =
  Alcotest.run "nopal_web mount telemetry"
    [
      ( "mount",
        [
          Alcotest.test_case "plain mount installs no bridge" `Quick
            test_mount_installs_no_bridge;
          Alcotest.test_case "mount_with_telemetry installs bridge" `Quick
            test_mount_with_telemetry_installs_bridge;
          Alcotest.test_case "mount_with_telemetry handle records dispatch"
            `Quick test_mount_with_telemetry_records_dispatch;
          Alcotest.test_case "bridge getEvents is non-draining" `Quick
            test_bridge_get_events_non_draining;
        ] );
    ]

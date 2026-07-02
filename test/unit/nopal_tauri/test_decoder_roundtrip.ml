(* FR-5 / Decision 3 — property-based round-trip tests for the FFI-boundary
   decoders (the class-2 fix from PR 1). Each decoder recovers a typed value from
   a wire token that crosses the JS/Rust boundary; a future edit that silently
   drops or aliases a case would break [decode (encode v) = v] for that variant.
   QCheck enumerates each decoder's whole domain, so a dropped or aliased case is
   caught as a failing generator input rather than a runtime mis-decode.

   The audit's third class-2 reference impl, [task.ml]'s
   [type 'a outcome = Completed of 'a | Cancelled], is intentionally absent: it is
   a runtime-produced variant with no wire encoding, so [decode] then [encode] is
   undefined for it. Its class-2 guard is the constructor-not-sentinel design, not
   a boundary decoder. See docs/bug-classes/0002-stringly-typed-protocols.md.

   Fixed seed ([Random.State.make]) per the /task instruction, so a failing case
   reproduces. The generators enumerate concrete variant lists ([oneof_list]) and
   printable strings, so no unreachable [result] branch needs a [failwith]
   terminator (qcheck-generator-failwith is N/A here). Printable strings avoid
   js_of_ocaml byte-vs-UTF-16 artifacts unrelated to the field extraction under
   test. *)

module Tray = Nopal_tauri.Tray
module Os = Nopal_tauri.Os
module Event = Nopal_tauri.Event

(* Wire encoders: the exact token a Tauri emitter/plugin places on the boundary,
   i.e. the inverse each decoder is written to accept. Deliberately NOT
   [Os.to_string], which is a display name (["macOS"]) the plugin never sends. *)
let click_to_wire = function
  | Tray.Left -> "Left"
  | Tray.Double -> "Double"
  | Tray.Right -> "Right"
  | Tray.Middle -> "Middle"

let platform_to_wire = function
  | Os.Windows -> "windows"
  | Os.MacOS -> "macos"
  | Os.Linux -> "linux"
  | Os.IOS -> "ios"
  | Os.Android -> "android"

(* [Event.payload_of_jv] reads the [payload] field off a delivered event object;
   its wire encoder is that Tauri event object carrying the string payload. *)
let payload_to_jv s = Jv.obj [| ("payload", Jv.of_string s) |]

let arb_click =
  QCheck.oneof_list ~print:click_to_wire
    [ Tray.Left; Tray.Double; Tray.Right; Tray.Middle ]

let arb_platform =
  QCheck.oneof_list ~print:platform_to_wire
    [ Os.Windows; Os.MacOS; Os.Linux; Os.IOS; Os.Android ]

let prop_click_roundtrip =
  QCheck.Test.make ~count:1000
    ~name:"tray click_type: decode (encode v) = Some v" arb_click (fun c ->
      Tray.click_type_of_string (click_to_wire c) = Some c)

let prop_platform_roundtrip =
  QCheck.Test.make ~count:1000 ~name:"os platform: decode (encode v) = Some v"
    arb_platform (fun p -> Os.platform_of_string (platform_to_wire p) = Some p)

let prop_payload_roundtrip =
  QCheck.Test.make ~count:1000 ~name:"event payload: decode (encode s) = s"
    QCheck.string_printable (fun s ->
      String.equal (Event.payload_of_jv (payload_to_jv s)) s)

let () =
  (* Fixed seed: a counterexample must reproduce across runs (qcheck-alcotest
     otherwise seeds from the clock / QCHECK_SEED). *)
  let rand = Random.State.make [| 0x0120_0006 |] in
  Alcotest.run "nopal_tauri_decoder_roundtrip"
    [
      ( "decoder_roundtrip",
        List.map
          (QCheck_alcotest.to_alcotest ~rand ~speed_level:`Quick)
          [
            prop_click_roundtrip;
            prop_platform_roundtrip;
            prop_payload_roundtrip;
          ] );
    ]

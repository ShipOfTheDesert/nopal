(* Internal browser bridge for telemetry (RFC 0110, Layer 2). Builds the
   [window.__nopal_telemetry__] object that Playwright queries. Installed only by
   {!Nopal_web.mount_with_telemetry}; plain {!Nopal_web.mount} never calls this,
   so the surface appears exactly where the application opted in (REQ-N2). No
   [.mli] — package-internal, never re-exported. *)

module Telemetry = Nopal_runtime.Telemetry

let events_jv handle =
  Nopal_telemetry_wire.events_to_jv (Telemetry.events handle)

(* Substring test via JavaScript [String.prototype.includes], so the matcher is
   byte-for-byte the same as the TS assertion side and there is no hand-rolled
   OCaml scan to drift from it. *)
let includes ~haystack ~needle =
  Jv.to_bool
    (Jv.call (Jv.of_string haystack) "includes" [| Jv.of_string needle |])

let message_matches ~fragment (event : Telemetry.event) =
  match event with
  | Telemetry.Message value -> includes ~haystack:value ~needle:fragment
  | Telemetry.Model_transition _
  | Telemetry.Command _
  | Telemetry.Subscription _ ->
      false

(* Build a JS Promise that resolves on the first matching [Message] — already
   recorded or arriving later via [on_record] — and rejects after [timeout_ms]. *)
let wait_for_message handle fragment timeout_ms =
  let promise_ctor = Jv.get Jv.global "Promise" in
  let window = Jv.get Jv.global "window" in
  let executor =
    Jv.callback ~arity:2 (fun resolve reject ->
        if List.exists (message_matches ~fragment) (Telemetry.events handle)
        then ignore (Jv.apply resolve [| Jv.undefined |])
        else begin
          (* mutable: one-shot guard so whichever of the [on_record] sink or the
             timeout fires first settles the promise and the other becomes a
             no-op (the sink is unregistered via [unsubscribe] when either
             fires). *)
          let settled = ref false in
          (* mutable: the pending setTimeout id, so the [on_record] sink can
             cancel the timeout once the awaited message arrives. *)
          let timer = ref Jv.null in
          (* mutable: holds the [on_record] disposer so settling unregisters the
             sink instead of leaking a dead listener for the page's lifetime. *)
          let unsubscribe = ref (fun () -> ()) in
          unsubscribe :=
            Telemetry.on_record handle (fun event ->
                if (not !settled) && message_matches ~fragment event then begin
                  settled := true;
                  !unsubscribe ();
                  if not (Jv.is_null !timer) then
                    ignore (Jv.call window "clearTimeout" [| !timer |]);
                  ignore (Jv.apply resolve [| Jv.undefined |])
                end);
          let on_timeout =
            Jv.callback ~arity:1 (fun _ ->
                if not !settled then begin
                  settled := true;
                  !unsubscribe ();
                  let message =
                    Printf.sprintf "waitForMessage: %S not seen within %dms"
                      fragment timeout_ms
                  in
                  let error =
                    Jv.new' (Jv.get Jv.global "Error")
                      [| Jv.of_string message |]
                  in
                  ignore (Jv.apply reject [| error |])
                end)
          in
          timer :=
            Jv.call window "setTimeout" [| on_timeout; Jv.of_int timeout_ms |]
        end)
  in
  Jv.new' promise_ctor [| executor |]

let install handle =
  let get_events =
    Jv.callback ~arity:1 (fun _ ->
        let events = events_jv handle in
        (* "full list, then clears" — each query drains, so successive E2E
           checkpoints do not see stale events. *)
        Telemetry.clear handle;
        events)
  in
  let wait_for =
    Jv.callback ~arity:2 (fun fragment timeout ->
        wait_for_message handle (Jv.to_string fragment) (Jv.to_int timeout))
  in
  let bridge =
    Jv.obj [| ("getEvents", get_events); ("waitForMessage", wait_for) |]
  in
  Jv.set (Jv.get Jv.global "window") "__nopal_telemetry__" bridge

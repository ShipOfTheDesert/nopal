(* Lifecycle of an async [plugin:event|listen] registration. The listen IPC
   resolves its unlisten function on a later microtask, so a subscription torn
   down within that window (cleanup before the IPC resolves) would otherwise
   read no unlisten, no-op, and leak the native listener. Tracking the state
   lets a [Cancelled] cleanup be honoured the instant the registration resolves
   (REQ-F8). *)
type registration =
  | Pending  (** listen IPC in flight; no unlisten function yet *)
  | Active of (unit -> unit)  (** registered; holds its unlisten *)
  | Cancelled  (** cleanup ran before the IPC resolved *)

let listen_managed ~event on_event =
  let internals = Jv.get Jv.global "__TAURI_INTERNALS__" in
  let cb = Jv.callback ~arity:1 (fun jv -> on_event jv) in
  let handler_id = Jv.to_int (Jv.call internals "transformCallback" [| cb |]) in
  (* mutable: tracks the async [plugin:event|listen] lifecycle so a cleanup
     firing before the IPC resolves still tears the listener down — it flips the
     state to [Cancelled], and the resolve continuation then unlistens
     immediately. *)
  let state = ref Pending in
  let listen_promise =
    Ipc.invoke "plugin:event|listen"
      [|
        ("event", Jv.of_string event);
        (* Tauri v2's [plugin:event|listen] requires an [EventTarget]; omitting
           it makes the command reject ("missing required key target"). [{ kind
           = "Any" }] mirrors the [@tauri-apps/api] default — listen regardless
           of the emitter. *)
        ("target", Jv.obj [| ("kind", Jv.of_string "Any") |]);
        (* Tauri v2 expects [handler] as the raw callback id (a [u32]), not a
           [{ id }] wrapper. *)
        ("handler", Jv.of_int handler_id);
      |]
  in
  (* A single [then'] directly on the listen IPC — not [Fut.of_promise] +
     [Fut.await], whose second hop is microtask-deferred regardless. With one
     hop the resolution fires as soon as the promise settles, which the test
     shim makes synchronous via a thenable. *)
  ignore
    (Jv.Promise.then' listen_promise
       (fun event_id_jv ->
         let event_id = Jv.to_int event_id_jv in
         let unlisten () =
           ignore
             (Ipc.invoke "plugin:event|unlisten"
                [|
                  ("event", Jv.of_string event); ("eventId", Jv.of_int event_id);
                |])
         in
         (match !state with
         | Cancelled -> unlisten ()
         | Pending
         | Active _ ->
             state := Active unlisten);
         Jv.Promise.resolve Jv.null)
       (fun err ->
         Brr.Console.(
           error
             [
               str ("nopal_tauri: Tauri_subscription listen failed for " ^ event);
               err;
             ]);
         Jv.Promise.resolve Jv.null));
  fun () ->
    match !state with
    | Active unlisten ->
        state := Cancelled;
        unlisten ()
    | Pending -> state := Cancelled
    | Cancelled -> ()

let make ~key ~event ~decode =
  Nopal_mvu.Sub.custom key (fun dispatch ->
      listen_managed ~event (fun jv ->
          match decode jv with
          | Some msg -> dispatch msg
          | None -> ()))

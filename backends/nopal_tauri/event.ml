type event = { payload : string }
type unlisten = unit -> unit

let emit name payload =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut =
        Fut.of_promise
          ~ok:(fun _ -> ())
          (Ipc.invoke "plugin:event|emit"
             [|
               ("event", Jv.of_string name); ("payload", Jv.of_string payload);
             |])
      in
      Fut.await fut (function
        | Ok () -> resolve ()
        | Error err ->
            Brr.Console.(error [ str "nopal_tauri: Event.emit failed"; err ])))

let listen name on_event on_unlisten =
  let internals = Jv.get Jv.global "__TAURI_INTERNALS__" in
  let cb =
    Jv.callback ~arity:1 (fun jv ->
        let payload = Jv.to_string (Jv.get jv "payload") in
        on_event { payload })
  in
  let handler_id = Jv.to_int (Jv.call internals "transformCallback" [| cb |]) in
  let fut =
    Fut.of_promise ~ok:Jv.to_int
      (Ipc.invoke "plugin:event|listen"
         [|
           ("event", Jv.of_string name);
           (* Tauri v2's [plugin:event|listen] requires an [EventTarget]; omitting
              it makes the command reject ("missing required key target") and the
              listener is never registered. [{ kind = "Any" }] mirrors the
              [@tauri-apps/api] default — listen regardless of the emitter. *)
           ("target", Jv.obj [| ("kind", Jv.of_string "Any") |]);
           (* Tauri v2 expects [handler] as the raw callback id (a [u32]), not a
              [{ id }] wrapper — a wrapper rejects with "invalid type: map,
              expected u32". *)
           ("handler", Jv.of_int handler_id);
         |])
  in
  Fut.await fut (function
    | Ok event_id ->
        let unlisten () =
          ignore
            (Ipc.invoke "plugin:event|unlisten"
               [|
                 ("event", Jv.of_string name); ("eventId", Jv.of_int event_id);
               |])
        in
        on_unlisten unlisten
    | Error err ->
        Brr.Console.(error [ str "nopal_tauri: Event.listen failed"; err ]))

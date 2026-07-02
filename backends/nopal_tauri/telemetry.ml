module Telemetry = Nopal_runtime.Telemetry

let expose handle =
  (* The forwarder lives for the whole runtime; its disposer is intentionally
     discarded — mirroring stops only when the page/process ends. *)
  let (_ : unit -> unit) =
    Telemetry.on_record handle (fun event ->
        let fut =
          Fut.of_promise
            ~ok:(fun _ -> ())
            (Ipc.invoke "plugin:event|emit"
               [|
                 ("event", Jv.of_string "nopal:telemetry");
                 ("payload", Nopal_telemetry_wire.event_to_jv event);
               |])
        in
        Fut.await fut (function
          | Ok () -> ()
          | Error err ->
              Brr.Console.(
                error
                  [ str "nopal_tauri: Telemetry.expose forward failed"; err ])))
  in
  ()

let get_telemetry () =
  Nopal_mvu.Task.from_callback (fun resolve ->
      (* A single [then'] directly on the invoke promise — like [Ipc.invoke_result]
         — settles as soon as the promise resolves (no microtask-deferred
         [Fut.await] hop), and the error path renders any rejection via the total
         [Ipc.error_to_string] (Tauri command errors are serde-serialized plain
         strings, not JS [Error]s). Non-draining: this only reads the host mirror
         (feature 0120 FR-7). *)
      ignore
        (Jv.Promise.then'
           (Ipc.invoke "get_telemetry" [||])
           (fun arr ->
             resolve (Nopal_telemetry_wire.events_of_jv arr);
             Jv.Promise.resolve Jv.null)
           (fun err ->
             resolve (Error (Ipc.error_to_string err));
             Jv.Promise.resolve Jv.null)))

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
      let fut = Fut.of_promise ~ok:Fun.id (Ipc.invoke "get_telemetry" [||]) in
      Fut.await fut (function
        | Ok arr -> resolve (Nopal_telemetry_wire.events_of_jv arr)
        | Error err -> resolve (Error (Jstr.to_string (Jv.Error.message err)))))

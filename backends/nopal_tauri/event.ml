type event = { payload : string }
type unlisten = unit -> unit

let emit name payload f =
  let internals = Jv.get Jv.global "__TAURI_INTERNALS__" in
  let args =
    Jv.obj [| ("event", Jv.of_string name); ("payload", Jv.of_string payload) |]
  in
  let fut =
    Fut.of_promise
      ~ok:(fun _ -> ())
      (Jv.call internals "invoke" [| Jv.of_string "plugin:event|emit"; args |])
  in
  Fut.await fut (function
    | Ok () -> f ()
    | Error _err -> ())

let listen name on_event on_unlisten =
  let internals = Jv.get Jv.global "__TAURI_INTERNALS__" in
  let cb =
    Jv.callback ~arity:1 (fun jv ->
        let payload = Jv.to_string (Jv.get jv "payload") in
        on_event { payload })
  in
  let handler_id = Jv.to_int (Jv.call internals "transformCallback" [| cb |]) in
  let args =
    Jv.obj
      [|
        ("event", Jv.of_string name);
        ("handler", Jv.obj [| ("id", Jv.of_int handler_id) |]);
      |]
  in
  let fut =
    Fut.of_promise ~ok:Jv.to_int
      (Jv.call internals "invoke"
         [| Jv.of_string "plugin:event|listen"; args |])
  in
  Fut.await fut (function
    | Ok event_id ->
        let unlisten () =
          let args =
            Jv.obj
              [|
                ("event", Jv.of_string name); ("eventId", Jv.of_int event_id);
              |]
          in
          ignore
            (Jv.call internals "invoke"
               [| Jv.of_string "plugin:event|unlisten"; args |])
        in
        on_unlisten unlisten
    | Error _err -> ())

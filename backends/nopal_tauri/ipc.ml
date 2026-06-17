let invoke cmd args =
  let internals = Jv.get Jv.global "__TAURI_INTERNALS__" in
  match Jv.is_undefined internals with
  | true ->
      Jv.Promise.reject (Jv.Error.v (Jstr.v "Tauri runtime not available"))
  | false -> Jv.call internals "invoke" [| Jv.of_string cmd; Jv.obj args |]

let error_to_string err =
  if Jv.is_none err then "unknown error"
  else
    match Jv.find err "message" with
    | Some msg -> Jv.to_string msg
    | None ->
        (* Tauri command rejections are serde-serialized plain strings, not JS
           [Error]s — String() is total over both (and any other shape). *)
        Jv.to_string (Jv.apply (Jv.get Jv.global "String") [| err |])

let invoke_result ~ok cmd args resolve =
  let promise = invoke cmd args in
  (* A single [then'] directly on the invoke promise — not [Fut.of_promise] +
     [Fut.await], whose second hop is microtask-deferred regardless. One hop
     settles as soon as the promise does, which a test shim can make synchronous
     via a thenable; against real Tauri it is an ordinary async resolution. The
     error continuation resolves [Error] rather than logging-and-hanging, so a
     failed op can never silently stall a [let*] chain (REQ-F5). *)
  ignore
    (Jv.Promise.then' promise
       (fun v ->
         resolve (Ok (ok v));
         Jv.Promise.resolve Jv.null)
       (fun err ->
         resolve (Error (error_to_string err));
         Jv.Promise.resolve Jv.null))

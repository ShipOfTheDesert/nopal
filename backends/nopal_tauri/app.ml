let invoke cmd =
  let internals = Jv.get Jv.global "__TAURI_INTERNALS__" in
  Jv.call internals "invoke" [| Jv.of_string cmd |]

let get_name f =
  let fut = Fut.of_promise ~ok:Jv.to_jstr (invoke "plugin:app|name") in
  Fut.await fut (function
    | Ok name -> f (Jstr.to_string name)
    | Error _err -> ())

let get_version f =
  let fut = Fut.of_promise ~ok:Jv.to_jstr (invoke "plugin:app|version") in
  Fut.await fut (function
    | Ok version -> f (Jstr.to_string version)
    | Error _err -> ())

let get_tauri_version f =
  let fut = Fut.of_promise ~ok:Jv.to_jstr (invoke "plugin:app|tauri_version") in
  Fut.await fut (function
    | Ok version -> f (Jstr.to_string version)
    | Error _err -> ())

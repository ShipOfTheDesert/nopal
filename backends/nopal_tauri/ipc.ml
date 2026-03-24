let invoke cmd args =
  let internals = Jv.get Jv.global "__TAURI_INTERNALS__" in
  match Jv.is_undefined internals with
  | true ->
      Jv.Promise.reject (Jv.Error.v (Jstr.v "Tauri runtime not available"))
  | false -> Jv.call internals "invoke" [| Jv.of_string cmd; Jv.obj args |]

module Make (Store : Storage_intf.S) = struct
  type typed_error = Storage of Storage_intf.error | Decode of string

  let get key ~decode =
    Nopal_mvu.Task.map
      (fun result ->
        match result with
        | Error e -> Error (Storage e)
        | Ok None -> Ok None
        | Ok (Some raw) -> (
            match decode raw with
            | Ok value -> Ok (Some value)
            | Error msg -> Error (Decode msg)))
      (Store.get key)

  let set ~key ~value ~encode = Store.set ~key ~value:(encode value)
end

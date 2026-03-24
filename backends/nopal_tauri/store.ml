let store_path = "nopal_store.json"
let error_to_string err = Jstr.to_string (Jv.Error.message err)

let invoke_store cmd args =
  Ipc.invoke ("plugin:store|" ^ cmd)
    (Array.append [| ("store", Jv.of_string store_path) |] args)

let get key =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut =
        Fut.of_promise ~ok:Fun.id
          (invoke_store "get" [| ("key", Jv.of_string key) |])
      in
      Fut.await fut (function
        | Ok jv ->
            if Jv.is_null jv || Jv.is_undefined jv then resolve (Ok None)
            else resolve (Ok (Some (Jv.to_string jv)))
        | Error jv -> resolve (Error (error_to_string jv))))

let set key value =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut =
        Fut.of_promise
          ~ok:(fun _ -> ())
          (invoke_store "set"
             [| ("key", Jv.of_string key); ("value", Jv.of_string value) |])
      in
      Fut.await fut (function
        | Ok () -> resolve (Ok ())
        | Error jv -> resolve (Error (error_to_string jv))))

let delete key =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut =
        Fut.of_promise
          ~ok:(fun _ -> ())
          (invoke_store "delete" [| ("key", Jv.of_string key) |])
      in
      Fut.await fut (function
        | Ok () -> resolve (Ok ())
        | Error jv -> resolve (Error (error_to_string jv))))

let clear () =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut = Fut.of_promise ~ok:(fun _ -> ()) (invoke_store "clear" [||]) in
      Fut.await fut (function
        | Ok () -> resolve (Ok ())
        | Error jv -> resolve (Error (error_to_string jv))))

let save () =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut = Fut.of_promise ~ok:(fun _ -> ()) (invoke_store "save" [||]) in
      Fut.await fut (function
        | Ok () -> resolve (Ok ())
        | Error jv -> resolve (Error (error_to_string jv))))

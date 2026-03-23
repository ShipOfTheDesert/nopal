type size = { width : int; height : int }

let invoke_window cmd args =
  let internals = Jv.get Jv.global "__TAURI_INTERNALS__" in
  let label = ("label", Jv.of_string "main") in
  let all_args = Jv.obj (Array.append [| label |] args) in
  Jv.call internals "invoke"
    [| Jv.of_string ("plugin:window|" ^ cmd); all_args |]

let set_title title =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut =
        Fut.of_promise
          ~ok:(fun _ -> ())
          (invoke_window "set_title" [| ("value", Jv.of_string title) |])
      in
      Fut.await fut (function
        | Ok () -> resolve ()
        | Error err ->
            Brr.Console.(
              error [ str "nopal_tauri: Window.set_title failed"; err ])))

let set_fullscreen flag =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut =
        Fut.of_promise
          ~ok:(fun _ -> ())
          (invoke_window "set_fullscreen" [| ("value", Jv.of_bool flag) |])
      in
      Fut.await fut (function
        | Ok () -> resolve ()
        | Error err ->
            Brr.Console.(
              error [ str "nopal_tauri: Window.set_fullscreen failed"; err ])))

let is_fullscreen =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut =
        Fut.of_promise ~ok:Jv.to_bool (invoke_window "is_fullscreen" [||])
      in
      Fut.await fut (function
        | Ok v -> resolve v
        | Error err ->
            Brr.Console.(
              error [ str "nopal_tauri: Window.is_fullscreen failed"; err ])))

let minimize =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut =
        Fut.of_promise ~ok:(fun _ -> ()) (invoke_window "minimize" [||])
      in
      Fut.await fut (function
        | Ok () -> resolve ()
        | Error err ->
            Brr.Console.(
              error [ str "nopal_tauri: Window.minimize failed"; err ])))

let maximize =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut =
        Fut.of_promise ~ok:(fun _ -> ()) (invoke_window "maximize" [||])
      in
      Fut.await fut (function
        | Ok () -> resolve ()
        | Error err ->
            Brr.Console.(
              error [ str "nopal_tauri: Window.maximize failed"; err ])))

let unmaximize =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut =
        Fut.of_promise ~ok:(fun _ -> ()) (invoke_window "unmaximize" [||])
      in
      Fut.await fut (function
        | Ok () -> resolve ()
        | Error err ->
            Brr.Console.(
              error [ str "nopal_tauri: Window.unmaximize failed"; err ])))

let is_maximized =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut =
        Fut.of_promise ~ok:Jv.to_bool (invoke_window "is_maximized" [||])
      in
      Fut.await fut (function
        | Ok v -> resolve v
        | Error err ->
            Brr.Console.(
              error [ str "nopal_tauri: Window.is_maximized failed"; err ])))

let close =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut = Fut.of_promise ~ok:(fun _ -> ()) (invoke_window "close" [||]) in
      Fut.await fut (function
        | Ok () -> resolve ()
        | Error err ->
            Brr.Console.(error [ str "nopal_tauri: Window.close failed"; err ])))

let set_size size =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let data =
        Jv.obj
          [|
            ("width", Jv.of_int size.width); ("height", Jv.of_int size.height);
          |]
      in
      let value = Jv.obj [| ("Logical", data) |] in
      let fut =
        Fut.of_promise
          ~ok:(fun _ -> ())
          (invoke_window "set_size" [| ("value", value) |])
      in
      Fut.await fut (function
        | Ok () -> resolve ()
        | Error err ->
            Brr.Console.(
              error [ str "nopal_tauri: Window.set_size failed"; err ])))

let inner_size =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut = Fut.of_promise ~ok:Fun.id (invoke_window "inner_size" [||]) in
      Fut.await fut (function
        | Ok jv ->
            let width = Jv.to_int (Jv.get jv "width") in
            let height = Jv.to_int (Jv.get jv "height") in
            resolve { width; height }
        | Error err ->
            Brr.Console.(
              error [ str "nopal_tauri: Window.inner_size failed"; err ])))

let invoke cmd = Ipc.invoke cmd [||]

let get_name =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut = Fut.of_promise ~ok:Jv.to_jstr (invoke "plugin:app|name") in
      Fut.await fut (function
        | Ok name -> resolve (Jstr.to_string name)
        | Error err ->
            Brr.Console.(error [ str "nopal_tauri: App.get_name failed"; err ])))

let get_version =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut = Fut.of_promise ~ok:Jv.to_jstr (invoke "plugin:app|version") in
      Fut.await fut (function
        | Ok version -> resolve (Jstr.to_string version)
        | Error err ->
            Brr.Console.(
              error [ str "nopal_tauri: App.get_version failed"; err ])))

let get_tauri_version =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut =
        Fut.of_promise ~ok:Jv.to_jstr (invoke "plugin:app|tauri_version")
      in
      Fut.await fut (function
        | Ok version -> resolve (Jstr.to_string version)
        | Error err ->
            Brr.Console.(
              error [ str "nopal_tauri: App.get_tauri_version failed"; err ])))

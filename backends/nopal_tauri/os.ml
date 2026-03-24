type platform = Windows | MacOS | Linux | IOS | Android

let to_string = function
  | Windows -> "Windows"
  | MacOS -> "macOS"
  | Linux -> "Linux"
  | IOS -> "iOS"
  | Android -> "Android"

let platform_of_string = function
  | "windows" -> Some Windows
  | "macos" -> Some MacOS
  | "linux" -> Some Linux
  | "ios" -> Some IOS
  | "android" -> Some Android
  | _ -> None

let platform =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut =
        Fut.of_promise ~ok:Jv.to_jstr (Ipc.invoke "plugin:os|platform" [||])
      in
      Fut.await fut (function
        | Ok s -> (
            match platform_of_string (Jstr.to_string s) with
            | Some p -> resolve p
            | None ->
                Brr.Console.(
                  error [ str "nopal_tauri: Os.platform unknown platform"; s ]))
        | Error err ->
            Brr.Console.(error [ str "nopal_tauri: Os.platform failed"; err ])))

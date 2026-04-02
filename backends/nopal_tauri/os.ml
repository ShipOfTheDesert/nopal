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
      let internals =
        Jv.get Jv.global "__TAURI_OS_PLUGIN_INTERNALS__"
      in
      match Jv.is_undefined internals with
      | true ->
          Brr.Console.(
            error
              [
                str
                  "nopal_tauri: Os.platform — \
                   __TAURI_OS_PLUGIN_INTERNALS__ not found";
              ])
      | false ->
          let s = Jv.to_string (Jv.get internals "platform") in
          (match platform_of_string s with
          | Some p -> resolve p
          | None ->
              Brr.Console.(
                error
                  [
                    str "nopal_tauri: Os.platform unknown platform";
                    Jv.of_string s;
                  ])))

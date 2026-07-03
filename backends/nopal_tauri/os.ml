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

let read_platform_string internals =
  let v = Jv.get internals "platform" in
  match String.equal (Jstr.to_string (Jv.typeof v)) "string" with
  | true -> Some (Jv.to_string v)
  | false -> None

let is_ios () =
  let internals = Jv.get Jv.global "__TAURI_OS_PLUGIN_INTERNALS__" in
  match Jv.is_undefined internals with
  | true -> false
  | false -> (
      match Option.bind (read_platform_string internals) platform_of_string with
      | Some IOS -> true
      | Some (Windows | MacOS | Linux | Android) -> false
      | None -> false)

let platform =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let internals = Jv.get Jv.global "__TAURI_OS_PLUGIN_INTERNALS__" in
      match Jv.is_undefined internals with
      | true ->
          resolve
            (Error
               "nopal_tauri: Os.platform — __TAURI_OS_PLUGIN_INTERNALS__ not \
                found")
      | false -> (
          match read_platform_string internals with
          | None ->
              resolve
                (Error
                   "nopal_tauri: Os.platform — platform field is not a string")
          | Some s -> (
              match platform_of_string s with
              | Some p -> resolve (Ok p)
              | None ->
                  resolve
                    (Error ("nopal_tauri: Os.platform unknown platform: " ^ s)))
          ))

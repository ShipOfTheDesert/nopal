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

let platform f =
  let internals = Jv.get Jv.global "__TAURI_INTERNALS__" in
  let promise =
    Jv.call internals "invoke" [| Jv.of_string "plugin:os|platform" |]
  in
  let fut = Fut.of_promise ~ok:Jv.to_jstr promise in
  Fut.await fut (function
    | Ok s -> (
        match platform_of_string (Jstr.to_string s) with
        | Some p -> f p
        | None -> ())
    | Error _err -> ())

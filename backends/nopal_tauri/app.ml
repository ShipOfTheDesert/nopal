let app_string cmd =
  Nopal_mvu.Task.from_callback
    (Ipc.invoke_result ~ok:(fun v -> Jstr.to_string (Jv.to_jstr v)) cmd [||])

let get_name = app_string "plugin:app|name"
let get_version = app_string "plugin:app|version"
let get_tauri_version = app_string "plugin:app|tauri_version"

let mount ?safe_area_source ?on_error app target =
  Nopal_web.mount ?safe_area_source ?on_error
    ~write_clipboard:Nopal_tauri.Clipboard.write
    ~open_external:Nopal_tauri.Opener.open_url app target

let mount_with_telemetry ?safe_area_source ?on_error app ?serialize_msg
    ?serialize_model target =
  Nopal_web.mount_with_telemetry ?safe_area_source ?on_error
    ~write_clipboard:Nopal_tauri.Clipboard.write
    ~open_external:Nopal_tauri.Opener.open_url app ?serialize_msg
    ?serialize_model target

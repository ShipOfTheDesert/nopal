type click_type = Left | Double | Right | Middle

let click_type_of_string = function
  | "Left" -> Some Left
  | "Double" -> Some Double
  | "Right" -> Some Right
  | "Middle" -> Some Middle
  | _ -> None

(* Each click subscription is an independent, race-free listener on the shared
   [nopal:tray-click] event (REQ-F8, via Tauri_subscription); its decode keeps
   only the click type it cares about and drops the rest. This replaces the old
   shared-listener + nullable-unlisten ref, which leaked the native listener if
   a subscription was removed before its listen IPC resolved. *)
let on_click msg =
  Tauri_subscription.make ~key:"nopal_tauri_tray_click"
    ~event:"nopal:tray-click" ~decode:(fun jv ->
      match click_type_of_string (Event.payload_of_jv jv) with
      | Some Left -> Some msg
      | Some Double
      | Some Right
      | Some Middle
      | None ->
          None)

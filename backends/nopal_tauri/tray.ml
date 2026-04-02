(* mutable: click handler closure, set by on_click Sub.custom setup,
   cleared on cleanup. Stored as unit -> unit to erase the 'msg type
   parameter at module scope. *)
let on_click_handler : (unit -> unit) option ref = ref None

(* mutable: double-click handler closure, set by on_double_click Sub.custom
   setup, cleared on cleanup. *)
let on_double_click_handler : (unit -> unit) option ref = ref None

(* mutable: unlisten function returned by Event.listen, called on cleanup. *)
let unlisten_fn : (unit -> unit) option ref = ref None

type click_type = Left | Double | Right | Middle

let click_type_of_string = function
  | "Left" -> Some Left
  | "Double" -> Some Double
  | "Right" -> Some Right
  | "Middle" -> Some Middle
  | _ -> None

let setup_listener () =
  match !unlisten_fn with
  | Some _ -> ()
  | None ->
      Event.listen "nopal:tray-click"
        (fun ev ->
          match click_type_of_string ev.payload with
          | Some Left -> (
              match !on_click_handler with
              | Some f -> f ()
              | None -> ())
          | Some Double -> (
              match !on_double_click_handler with
              | Some f -> f ()
              | None -> ())
          | Some Right
          | Some Middle
          | None ->
              ())
        (fun f -> unlisten_fn := Some f)

let teardown_listener () =
  match (!on_click_handler, !on_double_click_handler) with
  | None, None -> (
      match !unlisten_fn with
      | Some f ->
          f ();
          unlisten_fn := None
      | None -> ())
  | _ -> ()

let on_click msg =
  Nopal_mvu.Sub.custom "nopal_tauri_tray_click" (fun dispatch ->
      on_click_handler := Some (fun () -> dispatch msg);
      setup_listener ();
      fun () ->
        on_click_handler := None;
        teardown_listener ())

let on_double_click msg =
  Nopal_mvu.Sub.custom "nopal_tauri_tray_double_click" (fun dispatch ->
      on_double_click_handler := Some (fun () -> dispatch msg);
      setup_listener ();
      fun () ->
        on_double_click_handler := None;
        teardown_listener ())

let invoke_tray cmd args =
  (* The Rust-created tray has id "main" — commands that need a tray
     reference use the tray id, not a resource id. For set_icon,
     set_tooltip, set_visible we use the plugin IPC which requires rid.
     Since the tray is created from Rust, we look it up by id. *)
  Ipc.invoke ("plugin:tray|" ^ cmd) args

let set_icon path =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut =
        Fut.of_promise
          ~ok:(fun _ -> ())
          (invoke_tray "set_icon"
             [| ("rid", Jv.of_int 0); ("icon", Jv.of_string path) |])
      in
      Fut.await fut (function
        | Ok () -> resolve ()
        | Error err ->
            Brr.Console.(error [ str "nopal_tauri: Tray.set_icon failed"; err ])))

let set_tooltip text =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut =
        Fut.of_promise
          ~ok:(fun _ -> ())
          (invoke_tray "set_tooltip"
             [| ("rid", Jv.of_int 0); ("tooltip", Jv.of_string text) |])
      in
      Fut.await fut (function
        | Ok () -> resolve ()
        | Error err ->
            Brr.Console.(
              error [ str "nopal_tauri: Tray.set_tooltip failed"; err ])))

let set_visible flag =
  Nopal_mvu.Task.from_callback (fun resolve ->
      let fut =
        Fut.of_promise
          ~ok:(fun _ -> ())
          (invoke_tray "set_visible"
             [| ("rid", Jv.of_int 0); ("visible", Jv.of_bool flag) |])
      in
      Fut.await fut (function
        | Ok () -> resolve ()
        | Error err ->
            Brr.Console.(
              error [ str "nopal_tauri: Tray.set_visible failed"; err ])))

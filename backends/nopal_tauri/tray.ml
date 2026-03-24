(* mutable: shared TrayIcon resource ID, set during Sub.custom setup when
   the first subscription activates, cleared on cleanup when the last
   subscription deactivates. Required because tray icon lifetime is
   managed by the subscription system while task bindings need the
   resource ID synchronously. *)
let tray_rid : int option ref = ref None

(* mutable: click handler closure, set by on_click Sub.custom setup,
   cleared on cleanup. Stored as unit -> unit to erase the 'msg type
   parameter at module scope. *)
let on_click_handler : (unit -> unit) option ref = ref None

(* mutable: double-click handler closure, set by on_double_click Sub.custom
   setup, cleared on cleanup. *)
let on_double_click_handler : (unit -> unit) option ref = ref None

type click_type = Left | Double | Right

let click_type_of_string = function
  | "Left" -> Some Left
  | "Double" -> Some Double
  | "Right" -> Some Right
  | _ -> None

let invoke_tray rid cmd args =
  let internals = Jv.get Jv.global "__TAURI_INTERNALS__" in
  let rid_arg = ("rid", Jv.of_int rid) in
  let all_args = Jv.obj (Array.append [| rid_arg |] args) in
  Jv.call internals "invoke" [| Jv.of_string ("plugin:tray|" ^ cmd); all_args |]

let create_tray_icon () =
  let internals = Jv.get Jv.global "__TAURI_INTERNALS__" in
  let cb =
    Jv.callback ~arity:1 (fun jv ->
        match click_type_of_string (Jv.to_string (Jv.get jv "clickType")) with
        | Some Left -> (
            match !on_click_handler with
            | Some f -> f ()
            | None -> ())
        | Some Double -> (
            match !on_double_click_handler with
            | Some f -> f ()
            | None -> ())
        | Some Right
        | None ->
            ())
  in
  let handler_id = Jv.to_int (Jv.call internals "transformCallback" [| cb |]) in
  let args =
    Jv.obj [| ("handler", Jv.obj [| ("id", Jv.of_int handler_id) |]) |]
  in
  let fut =
    Fut.of_promise ~ok:Jv.to_int
      (Jv.call internals "invoke" [| Jv.of_string "plugin:tray|new"; args |])
  in
  Fut.await fut (function
    | Ok rid -> tray_rid := Some rid
    | Error err ->
        Brr.Console.(error [ str "nopal_tauri: Tray.create failed"; err ]))

let destroy_tray_icon () =
  match !tray_rid with
  | None -> ()
  | Some rid ->
      let internals = Jv.get Jv.global "__TAURI_INTERNALS__" in
      let args = Jv.obj [| ("rid", Jv.of_int rid) |] in
      ignore
        (Jv.call internals "invoke"
           [| Jv.of_string "plugin:resources|close"; args |]);
      tray_rid := None

(* ensure_tray_icon is fire-and-forget: create_tray_icon awaits an async
   promise to obtain the rid, so tray_rid remains None until the microtask
   resolves. This is safe because Sub.custom setup runs synchronously within
   the MVU update cycle, and the next update tick cannot begin until the
   current JS microtask queue drains — by which point the promise has
   resolved and tray_rid is set. If the runtime model ever changes to allow
   update interleaving with pending microtasks, this would need to return a
   Fut.t and callers would need to chain on it. *)
let ensure_tray_icon () =
  match !tray_rid with
  | None -> create_tray_icon ()
  | Some _ -> ()

let maybe_destroy_tray () =
  match (!on_click_handler, !on_double_click_handler) with
  | None, None -> destroy_tray_icon ()
  | _ -> ()

let on_click msg =
  Nopal_mvu.Sub.custom "nopal_tauri_tray_click" (fun dispatch ->
      on_click_handler := Some (fun () -> dispatch msg);
      ensure_tray_icon ();
      fun () ->
        on_click_handler := None;
        maybe_destroy_tray ())

let on_double_click msg =
  Nopal_mvu.Sub.custom "nopal_tauri_tray_double_click" (fun dispatch ->
      on_double_click_handler := Some (fun () -> dispatch msg);
      ensure_tray_icon ();
      fun () ->
        on_double_click_handler := None;
        maybe_destroy_tray ())

let set_icon path =
  Nopal_mvu.Task.from_callback (fun resolve ->
      match !tray_rid with
      | None ->
          Brr.Console.(
            error
              [ str "nopal_tauri: Tray.set_icon called with no active tray" ])
      | Some rid ->
          let fut =
            Fut.of_promise
              ~ok:(fun _ -> ())
              (invoke_tray rid "set_icon" [| ("icon", Jv.of_string path) |])
          in
          Fut.await fut (function
            | Ok () -> resolve ()
            | Error err ->
                Brr.Console.(
                  error [ str "nopal_tauri: Tray.set_icon failed"; err ])))

let set_tooltip text =
  Nopal_mvu.Task.from_callback (fun resolve ->
      match !tray_rid with
      | None ->
          Brr.Console.(
            error
              [ str "nopal_tauri: Tray.set_tooltip called with no active tray" ])
      | Some rid ->
          let fut =
            Fut.of_promise
              ~ok:(fun _ -> ())
              (invoke_tray rid "set_tooltip"
                 [| ("tooltip", Jv.of_string text) |])
          in
          Fut.await fut (function
            | Ok () -> resolve ()
            | Error err ->
                Brr.Console.(
                  error [ str "nopal_tauri: Tray.set_tooltip failed"; err ])))

let set_visible flag =
  Nopal_mvu.Task.from_callback (fun resolve ->
      match !tray_rid with
      | None ->
          Brr.Console.(
            error
              [ str "nopal_tauri: Tray.set_visible called with no active tray" ])
      | Some rid ->
          let fut =
            Fut.of_promise
              ~ok:(fun _ -> ())
              (invoke_tray rid "set_visible" [| ("visible", Jv.of_bool flag) |])
          in
          Fut.await fut (function
            | Ok () -> resolve ()
            | Error err ->
                Brr.Console.(
                  error [ str "nopal_tauri: Tray.set_visible failed"; err ])))

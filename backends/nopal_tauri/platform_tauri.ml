let current_path () =
  let location = Jv.get Jv.global "location" in
  Jv.to_string (Jv.get location "pathname")

let push_state path =
  let history = Jv.get Jv.global "history" in
  ignore
    (Jv.call history "pushState"
       [| Jv.null; Jv.of_string ""; Jv.of_string path |])

let replace_state path =
  let history = Jv.get Jv.global "history" in
  ignore
    (Jv.call history "replaceState"
       [| Jv.null; Jv.of_string ""; Jv.of_string path |])

let back () =
  let history = Jv.get Jv.global "history" in
  ignore (Jv.call history "back" [||])

let on_popstate callback =
  let window = Jv.get Jv.global "window" in
  let listener =
    Jv.callback ~arity:1 (fun _event ->
        let path = current_path () in
        callback path)
  in
  ignore
    (Jv.call window "addEventListener" [| Jv.of_string "popstate"; listener |]);
  fun () ->
    ignore
      (Jv.call window "removeEventListener"
         [| Jv.of_string "popstate"; listener |])

let storage = (module Nopal_storage_tauri.Make () : Nopal_storage.S)

let parse_safe_area payload =
  let fields =
    String.split_on_char ';' payload
    |> List.filter_map (fun fragment ->
        match String.split_on_char '=' fragment with
        | [ key; value ] -> Some (key, value)
        | _ -> None)
  in
  let lookup key = Option.bind (List.assoc_opt key fields) int_of_string_opt in
  match (lookup "top", lookup "right", lookup "bottom", lookup "left") with
  | Some top, Some right, Some bottom, Some left ->
      Some (Nopal_element.Viewport.make_safe_area ~top ~right ~bottom ~left ())
  | _ -> None

let parse_keyboard_height payload = int_of_string_opt payload

(* Lifecycle of an async [Event.listen] registration. [Event.listen] resolves
   its unlisten function on a later microtask, so a subscription torn down within
   that window (cleanup before the listen IPC resolves) would otherwise read a
   [None] unlisten, no-op, and leak the native listener. Tracking the state lets
   a [Cancelled] cleanup be honoured the instant the registration resolves. *)
type listen_state =
  | Pending  (** listen IPC in flight; no unlisten function yet *)
  | Listening of (unit -> unit)  (** registered; holds its unlisten *)
  | Cancelled  (** cleanup ran before the IPC resolved *)

(* Register [name]'s native listener, parsing each payload with [parse] and
   passing successes to [deliver]; returns a cleanup robust to [Event.listen]'s
   async resolution (see [listen_state]). Shared by the safe-area subscription /
   mount hook and the keyboard-height subscription. *)
let listen_signal name parse deliver =
  (* mutable: tracks the async [Event.listen] lifecycle so a cleanup firing
     before the IPC resolves still tears the listener down — it flips the state
     to [Cancelled], and the resolve callback then unlistens immediately. *)
  let state = ref Pending in
  Event.listen name
    (fun ev ->
      match parse ev.payload with
      | Some v -> deliver v
      | None -> ())
    (fun unlisten ->
      match !state with
      | Cancelled -> unlisten ()
      | Pending
      | Listening _ ->
          state := Listening unlisten);
  fun () ->
    match !state with
    | Listening unlisten ->
        state := Cancelled;
        unlisten ()
    | Pending -> state := Cancelled
    | Cancelled -> ()

let listen_safe_area deliver =
  listen_signal "nopal:safe-area" parse_safe_area deliver

let on_safe_area_change to_msg =
  Nopal_mvu.Sub.custom "nopal:safe-area" (fun dispatch ->
      dispatch (to_msg Nopal_element.Viewport.zero_insets);
      listen_safe_area (fun insets -> dispatch (to_msg insets)))

let on_keyboard_height_change to_msg =
  Nopal_mvu.Sub.custom "nopal:keyboard-height" (fun dispatch ->
      dispatch (to_msg 0);
      listen_signal "nopal:keyboard-height" parse_keyboard_height (fun height ->
          dispatch (to_msg height)))

let safe_area_source set =
  set Nopal_element.Viewport.zero_insets;
  listen_safe_area set

(* mutable: tracks whether the back-pressed listener is already registered, so
   enable_hardware_back stays idempotent across repeated calls (REQ-F3). *)
let hardware_back_enabled = ref false

let enable_hardware_back () =
  match !hardware_back_enabled with
  | true -> ()
  | false ->
      hardware_back_enabled := true;
      Event.listen "nopal:back-pressed"
        (fun _ev -> back ())
        (fun _unlisten -> ())

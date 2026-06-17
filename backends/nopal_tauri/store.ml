(* The store handle is the [plugin:store|load] resource id. Kept abstract in the
   .mli so callers must [load] before any op (REQ-F6) and cannot fabricate one. *)
type t = Jv.t

(* The canonical Tauri-rejection renderer lives in [Ipc] so every backend module
   maps rejections identically; re-exported here for the store unit tests. *)
let error_to_string = Ipc.error_to_string

let decode_get_response jv =
  (* tauri-plugin-store v2 [get] resolves with the pair [[value, found]] —
     [found] distinguishes a stored JSON [null] from an absent key. *)
  if Jv.is_none jv then Error "store get: unexpected null response"
  else
    let value = Jv.Jarray.get jv 0 in
    let found = Jv.to_bool (Jv.Jarray.get jv 1) in
    if (not found) || Jv.is_none value then Ok None
    else Ok (Some (Jv.to_string value))

let load path =
  Nopal_mvu.Task.from_callback
    (Ipc.invoke_result ~ok:Fun.id "plugin:store|load"
       [| ("path", Jv.of_string path) |])

(* Run rid-keyed store command [cmd] with [args], mapping the resolution through
   [ok] and any rejection through [Ipc.invoke_result]'s [error_to_string].
   tauri-plugin-store v2 commands are rid-keyed: every call must carry the
   resource id returned by [load] — path-keyed args are rejected ("missing
   required key rid"). *)
let command ~ok cmd (store : t) args =
  Nopal_mvu.Task.from_callback
    (Ipc.invoke_result ~ok ("plugin:store|" ^ cmd)
       (Array.append [| ("rid", store) |] args))

let get store key =
  Nopal_mvu.Task.from_callback (fun resolve ->
      Ipc.invoke_result ~ok:Fun.id "plugin:store|get"
        [| ("rid", store); ("key", Jv.of_string key) |]
        (function
          | Ok jv -> resolve (decode_get_response jv)
          | Error e -> resolve (Error e)))

let set store key value =
  command
    ~ok:(fun _ -> ())
    "set" store
    [| ("key", Jv.of_string key); ("value", Jv.of_string value) |]

(* v2 [delete] resolves with a bool (key existed) — the API contract here is
   "entry absent afterwards", so the flag is dropped. *)
let delete store key =
  command ~ok:(fun _ -> ()) "delete" store [| ("key", Jv.of_string key) |]

let clear store = command ~ok:(fun _ -> ()) "clear" store [||]
let save store = command ~ok:(fun _ -> ()) "save" store [||]

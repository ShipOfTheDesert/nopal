let store_path = "nopal_store.json"

let error_to_string err =
  if Jv.is_none err then "unknown error"
  else
    match Jv.find err "message" with
    | Some msg -> Jv.to_string msg
    | None ->
        (* Tauri command rejections are serde-serialized plain strings, not JS
           [Error]s — String() is total over both (and any other shape). *)
        Jv.to_string (Jv.apply (Jv.get Jv.global "String") [| err |])

let decode_get_response jv =
  (* tauri-plugin-store v2 [get] resolves with the pair [[value, found]] —
     [found] distinguishes a stored JSON [null] from an absent key. *)
  if Jv.is_none jv then Error "store get: unexpected null response"
  else
    let value = Jv.Jarray.get jv 0 in
    let found = Jv.to_bool (Jv.Jarray.get jv 1) in
    if (not found) || Jv.is_none value then Ok None
    else Ok (Some (Jv.to_string value))

(* mutable: caches the [plugin:store|load] resource id so every operation
   shares one loaded store handle instead of paying a load IPC per call. Only a
   successful load is cached — a failure resolves that operation's task with
   [Error] and leaves the cache empty so the next operation retries. Concurrent
   first operations may each issue a load; the plugin returns the same
   already-loaded instance, so the extra round-trip is harmless. *)
let cached_rid = ref None

(* Resolve the store's resource id ([load]ing it on first use), then run [op]
   with it. tauri-plugin-store v2 commands are rid-keyed: every call must carry
   the resource id returned by [plugin:store|load] — path-keyed args are
   rejected ("missing required key rid"). *)
let with_store resolve op =
  match !cached_rid with
  | Some rid -> op rid
  | None ->
      let fut =
        Fut.of_promise ~ok:Fun.id
          (Ipc.invoke "plugin:store|load"
             [| ("path", Jv.of_string store_path) |])
      in
      Fut.await fut (function
        | Ok rid ->
            cached_rid := Some rid;
            op rid
        | Error err -> resolve (Error (error_to_string (Jv.repr err))))

let invoke_store cmd rid args =
  Ipc.invoke ("plugin:store|" ^ cmd) (Array.append [| ("rid", rid) |] args)

(* Run rid-keyed store command [cmd] with [args], mapping the resolution
   through [ok] and any rejection through [error_to_string]. *)
let command ~ok cmd args resolve =
  with_store resolve (fun rid ->
      let fut = Fut.of_promise ~ok (invoke_store cmd rid args) in
      Fut.await fut (function
        | Ok v -> resolve (Ok v)
        | Error err -> resolve (Error (error_to_string (Jv.repr err)))))

let get key =
  Nopal_mvu.Task.from_callback (fun resolve ->
      with_store resolve (fun rid ->
          let fut =
            Fut.of_promise ~ok:Fun.id
              (invoke_store "get" rid [| ("key", Jv.of_string key) |])
          in
          Fut.await fut (function
            | Ok jv -> resolve (decode_get_response jv)
            | Error err -> resolve (Error (error_to_string (Jv.repr err))))))

let set key value =
  Nopal_mvu.Task.from_callback
    (command
       ~ok:(fun _ -> ())
       "set"
       [| ("key", Jv.of_string key); ("value", Jv.of_string value) |])

(* v2 [delete] resolves with a bool (key existed) — the API contract here is
   "entry absent afterwards", so the flag is dropped. *)
let delete key =
  Nopal_mvu.Task.from_callback
    (command ~ok:(fun _ -> ()) "delete" [| ("key", Jv.of_string key) |])

let clear () =
  Nopal_mvu.Task.from_callback (command ~ok:(fun _ -> ()) "clear" [||])

let save () =
  Nopal_mvu.Task.from_callback (command ~ok:(fun _ -> ()) "save" [||])

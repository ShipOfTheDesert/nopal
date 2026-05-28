type db = Jv.t

let indexeddb () = Jv.get Jv.global "indexedDB"
let is_available () = not (Jv.is_undefined (indexeddb ()))

let string_prop jv prop =
  let v = Jv.get jv prop in
  if Jv.is_undefined v || Jv.is_null v then "" else Jv.to_string v

(* Classify a request's [DOMException]. Only confidently-recognised [name]s are
   mapped to a specific case; everything else (including a missing error object)
   falls through to [Backend_error], per RFC 0107's risk note. *)
let error_of_request_error err_jv =
  if Jv.is_undefined err_jv || Jv.is_null err_jv then
    Nopal_storage.Backend_error "unknown IndexedDB error"
  else
    let name = string_prop err_jv "name" in
    let message = string_prop err_jv "message" in
    let detail = if message = "" then name else message in
    match name with
    | "QuotaExceededError" -> Nopal_storage.Quota_exceeded detail
    | "SecurityError" -> Nopal_storage.Permission_denied detail
    | _ -> Nopal_storage.Backend_error detail

(* Maps an exception thrown *synchronously* by an IndexedDB interop call (e.g.
   [transaction]/[objectStore] on a closing connection) to a [Backend_error],
   for {!Nopal_mvu.Task.guard}. *)
let error_of_exn = function
  | Jv.Error e ->
      Nopal_storage.Backend_error (Jstr.to_string (Jv.Error.message e))
  | e -> Nopal_storage.Backend_error (Printexc.to_string e)

(* Bridge a single [IDBRequest] into a Task: [make_request] issues the request,
   [decode] turns its [result] into the task's [result] on success ([decode] may
   itself report an [Error], e.g. for an unexpected value shape). Resolves
   exactly once. *)
let bridge_request make_request ~decode =
  Nopal_mvu.Task.guard ~on_exn:error_of_exn (fun resolve ->
      let req = make_request () in
      Jv.set req "onsuccess"
        (Jv.callback ~arity:1 (fun _event ->
             resolve (decode (Jv.get req "result"))));
      Jv.set req "onerror"
        (Jv.callback ~arity:1 (fun _event ->
             resolve (Error (error_of_request_error (Jv.get req "error"))))))

let open_db ~name ~store =
  Nopal_mvu.Task.guard ~on_exn:error_of_exn (fun resolve ->
      if not (is_available ()) then
        resolve
          (Error
             (Nopal_storage.Backend_unavailable "window.indexedDB is undefined"))
      else begin
        let req =
          Jv.call (indexeddb ()) "open" [| Jv.of_string name; Jv.of_int 1 |]
        in
        Jv.set req "onupgradeneeded"
          (Jv.callback ~arity:1 (fun _event ->
               let db = Jv.get req "result" in
               let names = Jv.get db "objectStoreNames" in
               let has_store =
                 Jv.to_bool (Jv.call names "contains" [| Jv.of_string store |])
               in
               if not has_store then
                 ignore
                   (Jv.call db "createObjectStore" [| Jv.of_string store |])));
        Jv.set req "onsuccess"
          (Jv.callback ~arity:1 (fun _event ->
               resolve (Ok (Jv.get req "result"))));
        Jv.set req "onerror"
          (Jv.callback ~arity:1 (fun _event ->
               resolve (Error (error_of_request_error (Jv.get req "error")))))
      end)

let object_store db ~store ~mode =
  let txn =
    Jv.call db "transaction" [| Jv.of_string store; Jv.of_string mode |]
  in
  Jv.call txn "objectStore" [| Jv.of_string store |]

let get db ~store ~key =
  bridge_request
    (fun () ->
      let os = object_store db ~store ~mode:"readonly" in
      Jv.call os "get" [| Jv.of_string key |])
    ~decode:(fun result ->
      if Jv.is_undefined result || Jv.is_null result then Ok None
      else if Jstr.equal (Jv.typeof result) (Jstr.v "string") then
        Ok (Some (Jv.to_string result))
      else
        (* [put] only ever writes strings, so this store should hold strings
           only. A non-string is an out-of-band write (devtools, another
           library); surface it as an error rather than coercing it to garbage
           or crashing on [Jv.to_string]. *)
        Error (Nopal_storage.Backend_error "stored value is not a string"))

let put db ~store ~key ~value =
  bridge_request
    (fun () ->
      let os = object_store db ~store ~mode:"readwrite" in
      Jv.call os "put" [| Jv.of_string value; Jv.of_string key |])
    ~decode:(fun _result -> Ok ())

let delete db ~store ~key =
  bridge_request
    (fun () ->
      let os = object_store db ~store ~mode:"readwrite" in
      Jv.call os "delete" [| Jv.of_string key |])
    ~decode:(fun _result -> Ok ())

let get_all_keys db ~store =
  bridge_request
    (fun () ->
      let os = object_store db ~store ~mode:"readonly" in
      Jv.call os "getAllKeys" [||])
    ~decode:(fun result -> Ok (Jv.to_list Jv.to_string result))

let clear db ~store =
  bridge_request
    (fun () ->
      let os = object_store db ~store ~mode:"readwrite" in
      Jv.call os "clear" [||])
    ~decode:(fun _result -> Ok ())

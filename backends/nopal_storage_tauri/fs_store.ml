(* [BaseDirectory.AppLocalData] in tauri-plugin-fs; the scoped capability in
   capabilities/default.json grants only [$APPLOCALDATA/nopal_storage]. *)
let base_dir = 15
let dir = "nopal_storage"
let internals () = Jv.get Jv.global "__TAURI_INTERNALS__"
let has_tauri () = not (Jv.is_undefined (internals ()))

let invoke cmd args =
  Jv.call (internals ()) "invoke" [| Jv.of_string cmd; Jv.obj args |]

let invoke_raw cmd body opts =
  Jv.call (internals ()) "invoke" [| Jv.of_string cmd; body; opts |]

(* tauri-plugin-fs surfaces failures as opaque [DOMException]/error strings over
   IPC; none can be reliably classified as quota or permission, so everything
   maps to [Backend_error] carrying the message (RFC 0107 risk note: map only
   confidently-recognised failures). [Backend_unavailable] is the one reliable
   case — no Tauri runtime — handled in {!bridge}. *)
let error_of_jv err =
  Nopal_storage.Backend_error (Jstr.to_string (Jv.Error.message err))

(* Maps an exception thrown *synchronously* while issuing the IPC call (the
   [invoke] construction, [Fut.of_promise]) to a [Backend_error], for
   {!Nopal_mvu.Task.guard}. *)
let error_of_exn = function
  | Jv.Error e -> error_of_jv e
  | e -> Nopal_storage.Backend_error (Printexc.to_string e)

(* Bridge one IPC promise into a Task resolving exactly once. [make_promise] is
   thunked so the [invoke] call (which throws on a missing runtime) runs only
   after the [has_tauri] guard, mirroring [indexeddb.ml]'s lazy request. *)
let bridge ~ok make_promise =
  Nopal_mvu.Task.guard ~on_exn:error_of_exn (fun resolve ->
      if not (has_tauri ()) then
        resolve
          (Error
             (Nopal_storage.Backend_unavailable "Tauri runtime not available"))
      else
        let fut = Fut.of_promise ~ok:Fun.id (make_promise ()) in
        Fut.await fut (function
          | Ok jv -> resolve (Ok (ok jv))
          | Error err -> resolve (Error (error_of_jv err))))

let base_dir_options () = Jv.obj [| ("baseDir", Jv.of_int base_dir) |]

let ensure_dir () =
  bridge
    ~ok:(fun _ -> ())
    (fun () ->
      invoke "plugin:fs|mkdir"
        [|
          ("path", Jv.of_string dir);
          ( "options",
            Jv.obj
              [|
                ("baseDir", Jv.of_int base_dir); ("recursive", Jv.of_bool true);
              |] );
        |])

let read_text ~key =
  let path = dir ^ "/" ^ Nopal_fs_key.encode_key key in
  bridge ~ok:Jv.to_string (fun () ->
      invoke "plugin:fs|read_text_file"
        [| ("path", Jv.of_string path); ("options", base_dir_options ()) |])

let write_text ~key ~value =
  let path = dir ^ "/" ^ Nopal_fs_key.encode_key key in
  bridge
    ~ok:(fun _ -> ())
    (fun () ->
      (* write_text_file takes the content as the raw request body and the path
         + options as request headers (tauri-plugin-fs v2 contract). *)
      let body =
        let encoder = Jv.new' (Jv.get Jv.global "TextEncoder") [||] in
        Jv.call encoder "encode" [| Jv.of_string value |]
      in
      let encoded_path =
        Jv.to_string
          (Jv.apply
             (Jv.get Jv.global "encodeURIComponent")
             [| Jv.of_string path |])
      in
      let options_json = Printf.sprintf {|{"baseDir":%d}|} base_dir in
      let opts =
        Jv.obj
          [|
            ( "headers",
              Jv.obj
                [|
                  ("path", Jv.of_string encoded_path);
                  ("options", Jv.of_string options_json);
                |] );
          |]
      in
      invoke_raw "plugin:fs|write_text_file" body opts)

let remove ~key =
  let path = dir ^ "/" ^ Nopal_fs_key.encode_key key in
  bridge
    ~ok:(fun _ -> ())
    (fun () ->
      invoke "plugin:fs|remove"
        [| ("path", Jv.of_string path); ("options", base_dir_options ()) |])

let list_keys () =
  bridge
    ~ok:(fun entries ->
      Jv.to_list (fun entry -> Jv.to_string (Jv.get entry "name")) entries
      |> List.filter_map Nopal_fs_key.decode_filename)
    (fun () ->
      invoke "plugin:fs|read_dir"
        [| ("path", Jv.of_string dir); ("options", base_dir_options ()) |])

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
   after the [has_tauri] guard, mirroring [indexeddb.ml]'s lazy request.

   [decode] turns the resolved value into the task's result and may itself
   report an [Error] for an unexpected value shape, as [indexeddb.ml]'s [~decode]
   does. It must be {e total}: it runs inside [Fut.await], on the event loop,
   which is past the point {!Nopal_mvu.Task.guard} can help — [guard] catches
   only what is raised synchronously while its body runs, so a decoder that
   raised would resolve nothing at all and leave the task pending forever rather
   than resolving [Error]. *)
let bridge ~decode make_promise =
  Nopal_mvu.Task.guard ~on_exn:error_of_exn (fun resolve ->
      if not (has_tauri ()) then
        resolve
          (Error
             (Nopal_storage.Backend_unavailable "Tauri runtime not available"))
      else
        let fut = Fut.of_promise ~ok:Fun.id (make_promise ()) in
        Fut.await fut (function
          | Ok jv -> resolve (decode jv)
          | Error err -> resolve (Error (error_of_jv err))))

(* [mkdir], [write_text_file] and [remove] answer with a serialized [()]; the
   value carries no information and is dropped without inspection. *)
let decode_unit _jv = Ok ()
let base_dir_options () = Jv.obj [| ("baseDir", Jv.of_int base_dir) |]

let ensure_dir () =
  bridge ~decode:decode_unit (fun () ->
      invoke "plugin:fs|mkdir"
        [|
          ("path", Jv.of_string dir);
          ( "options",
            Jv.obj
              [|
                ("baseDir", Jv.of_int base_dir); ("recursive", Jv.of_bool true);
              |] );
        |])

let is_js_string jv = String.equal (Jstr.to_string (Jv.typeof jv)) "string"

(* [plugin:fs|read_text_file] answers with the file's *bytes*, never with a
   string: the command returns a [tauri::ipc::Response]
   (tauri-plugin-fs/src/commands.rs), which is an [InvokeResponseBody::Raw], and
   tauri hands that to JavaScript in one of two shapes depending on transport:

   - an [ArrayBuffer] — the custom-protocol transport reads the
     [application/octet-stream] body with [response.arrayBuffer()], and the
     postMessage transport (which is what Android uses: tauri's ipc-protocol.js
     sets [canUseCustomProtocol = osName !== 'android']) evals
     [new Uint8Array([…]).buffer] for a small raw payload;
   - a JSON **number array** — macOS and iOS, where a raw body falls through to
     [format_result] and is serialized as [Vec<u8>].

   [Jv.to_string] is an unchecked cast, so applying it to the first shape yields
   a value typed [string] that is really the coercion ["[object ArrayBuffer]"].
   Measured on an Android handset: a stored 128-byte JSON document read back as
   exactly that literal, which is how this was found.

   Decoding with [TextDecoder] is the symmetric partner of {!write_text}'s
   [TextEncoder], and matches what the official [@tauri-apps/plugin-fs] JS
   wrapper does ([arr instanceof ArrayBuffer ? arr : Uint8Array.from(arr)]).
   Handling both shapes is not defensive padding: an ArrayBuffer-only decode
   would be correct on Android and wrong on iOS.

   A string is accepted as itself rather than fed to [Uint8Array.from] (which
   would iterate its characters and yield a zero byte for every non-digit): it
   is the shape a [text/plain] response would take, and coercing it to garbage
   is the failure mode this function exists to remove. Anything that is neither
   text, a buffer, nor a JSON array is reported rather than guessed at —
   [Uint8Array.from] does not raise on an arbitrary object, it silently answers
   with zero bytes, so the shape is discriminated before the conversion rather
   than after it.

   Total: the shape test covers every value, and the two steps that can still
   throw — a hardened or absent [TextDecoder], a [decode] that rejects its
   argument — are caught. Totality is load-bearing here and not merely tidy:
   this decoder runs inside [Fut.await] (see {!bridge}), where a raise resolves
   nothing at all and hangs the task forever. *)
let decode_text jv =
  match
    if is_js_string jv then Ok (Jv.to_string jv)
    else
      let array_buffer = Jv.get Jv.global "ArrayBuffer" in
      let bytes =
        if
          Jv.instanceof jv ~cons:array_buffer
          || Jv.to_bool (Jv.call array_buffer "isView" [| jv |])
        then Some jv
        else if
          Jv.to_bool (Jv.call (Jv.get Jv.global "Array") "isArray" [| jv |])
        then Some (Jv.call (Jv.get Jv.global "Uint8Array") "from" [| jv |])
        else None
      in
      match bytes with
      | None ->
          Error
            (Nopal_storage.Backend_error
               "read_text_file answered with neither text nor bytes")
      | Some bytes ->
          let decoder = Jv.new' (Jv.get Jv.global "TextDecoder") [||] in
          Ok (Jv.to_string (Jv.call decoder "decode" [| bytes |]))
  with
  | decoded -> decoded
  | exception e -> Error (error_of_exn e)

let read_text ~key =
  let path = dir ^ "/" ^ Nopal_fs_key.encode_key key in
  bridge ~decode:decode_text (fun () ->
      invoke "plugin:fs|read_text_file"
        [| ("path", Jv.of_string path); ("options", base_dir_options ()) |])

let write_text ~key ~value =
  let path = dir ^ "/" ^ Nopal_fs_key.encode_key key in
  bridge ~decode:decode_unit (fun () ->
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
  bridge ~decode:decode_unit (fun () ->
      invoke "plugin:fs|remove"
        [| ("path", Jv.of_string path); ("options", base_dir_options ()) |])

(* [plugin:fs|read_dir] answers with a JSON array of [DirEntry] records, so
   unlike {!decode_text} the shape here is already right; what is missing is
   totality. [Jv.to_list] on a value that is not array-like raises, and a raise
   in a decoder leaves the task pending forever (see {!bridge}) — so the
   traversal is guarded, and an entry whose [name] is not a JS string is dropped
   rather than passed through the unchecked cast [Jv.to_string]. Names that do
   not decode are already skipped: the scoped directory is expected to hold only
   files this module wrote. *)
let decode_entries entries =
  match
    Jv.to_list
      (fun entry ->
        let name = Jv.get entry "name" in
        if is_js_string name then
          Nopal_fs_key.decode_filename (Jv.to_string name)
        else None)
      entries
  with
  | names -> Ok (List.filter_map Fun.id names)
  | exception e -> Error (error_of_exn e)

let list_keys () =
  bridge ~decode:decode_entries (fun () ->
      invoke "plugin:fs|read_dir"
        [| ("path", Jv.of_string dir); ("options", base_dir_options ()) |])

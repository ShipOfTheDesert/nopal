let has_content_type (headers : (string * string) list) =
  List.exists (fun (k, _) -> String.lowercase_ascii k = "content-type") headers

let encode_uri_component_fn = Jv.get Jv.global "encodeURIComponent"

let encode_uri_component (s : string) : string =
  Jstr.to_string
    (Jv.to_jstr
       (Jv.apply encode_uri_component_fn [| Jv.of_jstr (Jstr.of_string s) |]))

(* The filename the server should see for a [File] part: the caller's override
   when it gave one, otherwise the name the blob itself reports. Only a [File]
   carries a [name] — a plain [Blob] has none, and neither does the re-typed
   blob a [mime] override produces — so this is read from the stored object
   before any override is applied. Without it, overriding [mime] would also
   reset the filename to the platform's placeholder, and the two overrides are
   specified to be independent. *)
let part_filename ~filename blob =
  match filename with
  | Some name -> Some (Jstr.of_string name)
  | None -> Jv.find_map Jv.to_jstr (Brr.Blob.to_jv blob) "name"

(* Appends one multipart [part] to [form_data]. Fails — as a value, never by
   raising — when a [File] part names a handle the blob store cannot resolve:
   the enclosing {!Nopal_mvu.Task.guard_once} maps every exception to
   [Network_error], so a raise here would be indistinguishable from a genuine
   network failure, which is exactly what [Invalid_blob] exists to prevent. *)
let append_part form_data (part : Nopal_http.part) =
  let append args = ignore (Jv.call form_data "append" args) in
  match part with
  | Nopal_http.Field (name, value) ->
      append
        [|
          Jv.of_jstr (Jstr.of_string name); Jv.of_jstr (Jstr.of_string value);
        |];
      Ok ()
  | Nopal_http.File { name; blob_id; filename; mime } -> (
      match Nopal_blob_web.Blob_store.lookup blob_id with
      | None -> Error (Nopal_http.Invalid_blob blob_id)
      | Some blob ->
          let blob_jv = Brr.Blob.to_jv blob in
          let value =
            match mime with
            | None -> blob_jv
            | Some mime ->
                (* Re-slicing the whole blob is how a [Blob] gets a different
                   MIME type, and [slice] is a view over the same bytes rather
                   than a copy of them. The extent is read straight off the JS
                   [size] property instead of through [Brr.Blob.byte_length],
                   whose OCaml [int] would wrap for a blob of 2 GiB or more and
                   silently truncate the upload. *)
                Jv.call blob_jv "slice"
                  [|
                    Jv.of_int 0;
                    Jv.get blob_jv "size";
                    Jv.of_jstr (Jstr.of_string mime);
                  |]
          in
          let field = Jv.of_jstr (Jstr.of_string name) in
          (* Two arguments when there is no filename to state: passing an absent
             one explicitly would send the string "undefined" as the filename. *)
          (match part_filename ~filename blob with
          | None -> append [| field; value |]
          | Some filename -> append [| field; value; Jv.of_jstr filename |]);
          Ok ())

(* Builds the [FormData] for a multipart body, or fails with the first
   unresolvable handle. A failure abandons the whole body — a partially built
   one is never handed to Fetch, so the request either carries every part or is
   not issued at all. *)
let form_data_of_parts (parts : Nopal_http.part list) =
  let form_data = Jv.new' (Jv.get Jv.global "FormData") [||] in
  let rec append_all = function
    | [] -> Ok form_data
    | part :: rest -> (
        match append_part form_data part with
        | Ok () -> append_all rest
        | Error err -> Error err)
  in
  append_all parts

(** [prepare_request request] extracts the HTTP method, headers, and body from
    [request] into Fetch API values. Returns [Ok (method', headers, body)] where
    [headers] and [body] are [option] types ready for
    [Brr_io.Fetch.Request.init], or [Error (Invalid_blob handle)] when a
    multipart [File] part names a handle with no blob-store entry. *)
let prepare_request (request : Nopal_http.request) =
  let method' =
    Jstr.of_string
      (match request.meth with
      | Nopal_http.GET -> "GET"
      | Nopal_http.POST -> "POST"
      | Nopal_http.PUT -> "PUT"
      | Nopal_http.DELETE -> "DELETE"
      | Nopal_http.PATCH -> "PATCH")
  in
  let content_type_from_body =
    match request.body with
    | Nopal_http.Empty -> None
    | Nopal_http.String { content_type; _ } -> content_type
    | Nopal_http.Json _ -> Some "application/json"
    | Nopal_http.Form_encoded _ -> Some "application/x-www-form-urlencoded"
    | Nopal_http.Multipart _ -> None
  in
  let all_headers =
    match content_type_from_body with
    | Some ct when not (has_content_type request.headers) ->
        ("Content-Type", ct) :: request.headers
    | _ -> request.headers
  in
  let headers =
    match all_headers with
    | [] -> None
    | hdrs ->
        Some
          (Brr_io.Fetch.Headers.of_assoc
             (List.map
                (fun (k, v) -> (Jstr.of_string k, Jstr.of_string v))
                hdrs))
  in
  let body =
    match request.body with
    | Nopal_http.Empty -> Ok None
    | Nopal_http.String { content; _ } ->
        Ok (Some (Brr_io.Fetch.Body.of_jstr (Jstr.of_string content)))
    | Nopal_http.Json s ->
        Ok (Some (Brr_io.Fetch.Body.of_jstr (Jstr.of_string s)))
    | Nopal_http.Form_encoded pairs ->
        let encoded =
          String.concat "&"
            (List.map
               (fun (k, v) ->
                 encode_uri_component k ^ "=" ^ encode_uri_component v)
               pairs)
        in
        Ok (Some (Brr_io.Fetch.Body.of_jstr (Jstr.of_string encoded)))
    | Nopal_http.Multipart parts -> (
        match form_data_of_parts parts with
        | Error err -> Error err
        | Ok form_data ->
            (* Jv.Id.of_jv: safe cast — form_data was created via Jv.new'
               "FormData", so it is a FormData instance that of_form_data
               expects. *)
            Ok (Some (Brr_io.Fetch.Body.of_form_data (Jv.Id.of_jv form_data))))
  in
  Result.map (fun body -> (method', headers, body)) body

(** [read_response response resolve] reads the response body and calls [resolve]
    with the parsed [Nopal_http.outcome]. *)
let read_response response resolve =
  let status = Brr_io.Fetch.Response.status response in
  let resp_headers =
    Brr_io.Fetch.Headers.to_assoc (Brr_io.Fetch.Response.headers response)
    |> List.map (fun (k, v) ->
        (String.lowercase_ascii (Jstr.to_string k), Jstr.to_string v))
  in
  let body_fut =
    Brr_io.Fetch.Body.text (Brr_io.Fetch.Response.as_body response)
  in
  Fut.await body_fut (function
    | Error err ->
        let msg = Jstr.to_string (Jv.Error.message err) in
        resolve (Error (Nopal_http.Network_error msg))
    | Ok body_jstr ->
        let body = Jstr.to_string body_jstr in
        resolve (Ok { Nopal_http.status; body; headers = resp_headers }))

(* Maps an exception thrown *synchronously* while building/issuing the request
   (e.g. [prepare_request], [Fetch.Request.init], [Fetch.url]) to a
   [Network_error], for {!Nopal_mvu.Task.guard_once} — otherwise it would escape the
   task body and leave the request unresolved. *)
let error_of_exn = function
  | Jv.Error e -> Nopal_http.Network_error (Jstr.to_string (Jv.Error.message e))
  | e -> Nopal_http.Network_error (Printexc.to_string e)

(* {!Nopal_mvu.Task.guard_once} rather than {!Nopal_mvu.Task.guard} throughout
   this backend. Any [resolve] called *synchronously* inside the task body sits
   within the guard's own [try]: if the dispatch it triggers raises — an
   application [update] is arbitrary code — a guard that does not deduplicate
   catches the exception and resolves a second time with a [Network_error],
   misattributing an application bug to the network. The blob-handle failure is
   the one synchronous delivery path here; every other [resolve] runs from a
   [Fut.await] callback, outside the [try]. Latching the resolver rather than
   the body is what covers both, because the guard's own handler holds the
   resolver too. {!Nopal_mvu.Task.cancellable} already holds an equivalent
   latch, which is why {!send_cancellable} gains nothing from this beyond
   symmetry. *)

let send (request : Nopal_http.request) =
  Nopal_mvu.Task.guard_once ~on_exn:error_of_exn (fun resolve ->
      (* An unresolvable blob handle resolves the task here and returns: no
         fetch is issued, no timer is armed, and the single resolution the task
         contract allows has already happened. *)
      match prepare_request request with
      | Error err -> resolve (Error err)
      | Ok (method', headers, body) ->
          let signal, timer_id =
            match request.timeout with
            | None -> (None, None)
            | Some seconds ->
                let controller = Brr.Abort.controller () in
                let signal = Brr.Abort.signal controller in
                let ms = int_of_float (seconds *. 1000.0) in
                let tid =
                  Brr.G.set_timeout ~ms (fun () -> Brr.Abort.abort controller)
                in
                (Some signal, Some tid)
          in
          let init =
            Brr_io.Fetch.Request.init ?body ?headers ?signal ~method' ()
          in
          let fut = Brr_io.Fetch.url ~init (Jstr.of_string request.url) in
          Fut.await fut (function
            | Error err ->
                Option.iter Brr.G.stop_timer timer_id;
                let is_abort = Jv.Error.enum err = `Abort_error in
                if is_abort then resolve (Error Nopal_http.Timeout)
                else
                  let msg = Jstr.to_string (Jv.Error.message err) in
                  resolve (Error (Nopal_http.Network_error msg))
            | Ok response ->
                Option.iter Brr.G.stop_timer timer_id;
                read_response response resolve))

let get ?(headers = []) ?timeout url =
  send { Nopal_http.meth = GET; url; headers; body = Empty; timeout }

let post ?(headers = []) ?timeout ~body url =
  send { Nopal_http.meth = POST; url; headers; body; timeout }

let put ?(headers = []) ?timeout ~body url =
  send { Nopal_http.meth = PUT; url; headers; body; timeout }

let delete_ ?(body = Nopal_http.Empty) ?(headers = []) ?timeout url =
  send { Nopal_http.meth = DELETE; url; headers; body; timeout }

let patch ?(headers = []) ?timeout ~body url =
  send { Nopal_http.meth = PATCH; url; headers; body; timeout }

let send_cancellable (request : Nopal_http.request) =
  let controller = Brr.Abort.controller () in
  let signal = Brr.Abort.signal controller in
  let aborted_by_cancel = ref false in
  let token, wrapped_task =
    Nopal_mvu.Task.cancellable (fun token ->
        Nopal_mvu.Task.set_on_cancel token (fun () ->
            aborted_by_cancel := true;
            Brr.Abort.abort controller);
        Nopal_mvu.Task.guard_once ~on_exn:error_of_exn (fun resolve ->
            (* As in {!send}: an unresolvable blob handle resolves the task
               before anything is fetched or any timer is armed. *)
            match prepare_request request with
            | Error err -> resolve (Error err)
            | Ok (method', headers, body) ->
                let timer_id =
                  match request.timeout with
                  | None -> None
                  | Some seconds ->
                      let ms = int_of_float (seconds *. 1000.0) in
                      let tid =
                        Brr.G.set_timeout ~ms (fun () ->
                            Brr.Abort.abort controller)
                      in
                      Some tid
                in
                let init =
                  Brr_io.Fetch.Request.init ?body ?headers ~signal ~method' ()
                in
                let fut = Brr_io.Fetch.url ~init (Jstr.of_string request.url) in
                Fut.await fut (function
                  | Error err ->
                      Option.iter Brr.G.stop_timer timer_id;
                      let is_abort = Jv.Error.enum err = `Abort_error in
                      if is_abort then begin
                        if !aborted_by_cancel then
                          resolve (Error (Nopal_http.Network_error "cancelled"))
                        else resolve (Error Nopal_http.Timeout)
                      end
                      else
                        let msg = Jstr.to_string (Jv.Error.message err) in
                        resolve (Error (Nopal_http.Network_error msg))
                  | Ok response ->
                      Option.iter Brr.G.stop_timer timer_id;
                      read_response response resolve)))
  in
  (* Flatten the outcome of the cancellable wrapper:
     'a outcome where 'a = (response, error) result
     Cancelled -> Error (Network_error "cancelled")
     Completed outcome -> outcome *)
  let task =
    Nopal_mvu.Task.map
      (function
        | Nopal_mvu.Task.Cancelled ->
            Error (Nopal_http.Network_error "cancelled")
        | Nopal_mvu.Task.Completed outcome -> outcome)
      wrapped_task
  in
  (token, task)

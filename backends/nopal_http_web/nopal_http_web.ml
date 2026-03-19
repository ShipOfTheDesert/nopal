let has_content_type (headers : (string * string) list) =
  List.exists (fun (k, _) -> String.lowercase_ascii k = "content-type") headers

let encode_uri_component_fn = Jv.get Jv.global "encodeURIComponent"

let encode_uri_component (s : string) : string =
  Jstr.to_string
    (Jv.to_jstr
       (Jv.apply encode_uri_component_fn [| Jv.of_jstr (Jstr.of_string s) |]))

let send (request : Nopal_http.request) on_result =
  Nopal_mvu.Cmd.task (fun dispatch ->
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
        | Nopal_http.Empty -> None
        | Nopal_http.String { content; _ } ->
            Some (Brr_io.Fetch.Body.of_jstr (Jstr.of_string content))
        | Nopal_http.Json s ->
            Some (Brr_io.Fetch.Body.of_jstr (Jstr.of_string s))
        | Nopal_http.Form_encoded pairs ->
            let encoded =
              String.concat "&"
                (List.map
                   (fun (k, v) ->
                     encode_uri_component k ^ "=" ^ encode_uri_component v)
                   pairs)
            in
            Some (Brr_io.Fetch.Body.of_jstr (Jstr.of_string encoded))
        | Nopal_http.Multipart pairs ->
            let form_data = Jv.new' (Jv.get Jv.global "FormData") [||] in
            List.iter
              (fun (k, v) ->
                ignore
                  (Jv.call form_data "append"
                     [|
                       Jv.of_jstr (Jstr.of_string k);
                       Jv.of_jstr (Jstr.of_string v);
                     |]))
              pairs;
            (* Jv.Id.of_jv: safe cast — form_data was created via Jv.new' "FormData",
               so it is a FormData instance that of_form_data expects. *)
            Some (Brr_io.Fetch.Body.of_form_data (Jv.Id.of_jv form_data))
      in
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
      let init = Brr_io.Fetch.Request.init ?body ?headers ?signal ~method' () in
      let fut = Brr_io.Fetch.url ~init (Jstr.of_string request.url) in
      Fut.await fut (function
        | Error err ->
            Option.iter Brr.G.stop_timer timer_id;
            let is_abort = Jv.Error.enum err = `Abort_error in
            if is_abort then dispatch (on_result (Error Nopal_http.Timeout))
            else
              let msg = Jstr.to_string (Jv.Error.message err) in
              dispatch (on_result (Error (Nopal_http.Network_error msg)))
        | Ok response ->
            Option.iter Brr.G.stop_timer timer_id;
            let status = Brr_io.Fetch.Response.status response in
            let resp_headers =
              Brr_io.Fetch.Headers.to_assoc
                (Brr_io.Fetch.Response.headers response)
              |> List.map (fun (k, v) ->
                  (String.lowercase_ascii (Jstr.to_string k), Jstr.to_string v))
            in
            let body_fut =
              Brr_io.Fetch.Body.text (Brr_io.Fetch.Response.as_body response)
            in
            Fut.await body_fut (function
              | Error err ->
                  let msg = Jstr.to_string (Jv.Error.message err) in
                  dispatch (on_result (Error (Nopal_http.Network_error msg)))
              | Ok body_jstr ->
                  let body = Jstr.to_string body_jstr in
                  dispatch
                    (on_result
                       (Ok { Nopal_http.status; body; headers = resp_headers })))))

let get ?(headers = []) ?timeout url on_result =
  send { Nopal_http.meth = GET; url; headers; body = Empty; timeout } on_result

let post ?(headers = []) ?timeout ~body url on_result =
  send { Nopal_http.meth = POST; url; headers; body; timeout } on_result

let put ?(headers = []) ?timeout ~body url on_result =
  send { Nopal_http.meth = PUT; url; headers; body; timeout } on_result

let delete_ ?(body = Nopal_http.Empty) ?(headers = []) ?timeout url on_result =
  send { Nopal_http.meth = DELETE; url; headers; body; timeout } on_result

let patch ?(headers = []) ?timeout ~body url on_result =
  send { Nopal_http.meth = PATCH; url; headers; body; timeout } on_result

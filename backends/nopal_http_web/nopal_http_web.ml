let send (request : Nopal_http.request) on_result =
  Nopal_mvu.Cmd.task (fun dispatch ->
      let method' =
        Jstr.of_string
          (match request.meth with
          | Nopal_http.GET -> "GET"
          | Nopal_http.POST -> "POST")
      in
      let headers =
        match request.headers with
        | [] -> None
        | hdrs ->
            Some
              (Brr_io.Fetch.Headers.of_assoc
                 (List.map
                    (fun (k, v) -> (Jstr.of_string k, Jstr.of_string v))
                    hdrs))
      in
      let body =
        match request.meth with
        | Nopal_http.GET -> None
        | Nopal_http.POST ->
            Some (Brr_io.Fetch.Body.of_jstr (Jstr.of_string request.body))
      in
      let init = Brr_io.Fetch.Request.init ?body ?headers ~method' () in
      let fut = Brr_io.Fetch.url ~init (Jstr.of_string request.url) in
      Fut.await fut (function
        | Error err ->
            let msg = Jstr.to_string (Jv.Error.message err) in
            dispatch (on_result (Error (Nopal_http.Network_error msg)))
        | Ok response ->
            let status = Brr_io.Fetch.Response.status response in
            let body_fut =
              Brr_io.Fetch.Body.text (Brr_io.Fetch.Response.as_body response)
            in
            Fut.await body_fut (function
              | Error err ->
                  let msg = Jstr.to_string (Jv.Error.message err) in
                  dispatch (on_result (Error (Nopal_http.Network_error msg)))
              | Ok body_jstr ->
                  let body = Jstr.to_string body_jstr in
                  dispatch (on_result (Ok { Nopal_http.status; body })))))

let get ?(headers = []) url on_result =
  send { Nopal_http.meth = GET; url; headers; body = "" } on_result

let post url ?(headers = []) ~body on_result =
  send { Nopal_http.meth = POST; url; headers; body } on_result

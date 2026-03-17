let get url on_result =
  Nopal_mvu.Cmd.task (fun dispatch ->
      let fut = Brr_io.Fetch.url (Jstr.of_string url) in
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

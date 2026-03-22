let () =
  Nopal_http.register_backend { Nopal_http.send = Nopal_http_web.send };
  Nopal_http.register_cancellable_backend
    { Nopal_http.send_cancellable = Nopal_http_web.send_cancellable };
  let open Brr in
  let target =
    match Document.find_el_by_id G.document (Jstr.v "app") with
    | Some el -> el
    | None ->
        let body = Document.body G.document in
        let div = El.div [] in
        El.append_children body [ div ];
        div
  in
  Nopal_web.mount
    (module struct
      type model = Http_demo.model
      type msg = Http_demo.msg

      let init = Http_demo.init
      let update = Http_demo.update
      let view = Http_demo.view
      let subscriptions = Http_demo.subscriptions
    end)
    target

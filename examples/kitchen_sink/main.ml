let () =
  Nopal_http.register_backend { Nopal_http.get = Nopal_http_web.get };
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
      type model = Kitchen_sink_app.model
      type msg = Kitchen_sink_app.msg

      let init = Kitchen_sink_app.init
      let update = Kitchen_sink_app.update
      let view = Kitchen_sink_app.view
      let subscriptions = Kitchen_sink_app.subscriptions
    end)
    target

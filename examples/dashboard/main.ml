let () =
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
      type model = Dashboard_app.model
      type msg = Dashboard_app.msg

      let init = Dashboard_app.init
      let update = Dashboard_app.update
      let view = Dashboard_app.view
      let subscriptions = Dashboard_app.subscriptions
    end)
    target

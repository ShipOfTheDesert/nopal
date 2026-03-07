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
    (module Counter : Nopal_mvu.App.S
      with type model = Counter.model
       and type msg = Counter.msg)
    target

module Storage_local : Todomvc.Storage = struct
  let key = Jstr.v "nopal-todomvc"
  let storage () = Brr_io.Storage.local Brr.G.window

  let load () =
    match Brr_io.Storage.get_item (storage ()) key with
    | None -> []
    | Some json_str -> (
        match Brr.Json.decode json_str with
        | Error _ -> []
        | Ok value ->
            let arr = Jv.to_list Fun.id value in
            List.filter_map
              (fun jv ->
                let id = Jv.Int.get jv "id" in
                let title = Jv.Jstr.get jv "title" |> Jstr.to_string in
                let completed = Jv.Bool.get jv "completed" in
                Some ({ Todomvc.id; title; completed } : Todomvc.todo))
              arr)

  let save todos =
    let arr =
      List.map
        (fun (t : Todomvc.todo) ->
          Jv.obj
            [|
              ("id", Jv.of_int t.id);
              ("title", Jv.of_jstr (Jstr.v t.title));
              ("completed", Jv.of_bool t.completed);
            |])
        todos
    in
    let json = Brr.Json.encode (Jv.of_list Fun.id arr) in
    ignore (Brr_io.Storage.set_item (storage ()) key json)
end

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
  let platform = (module Nopal_web.Platform_web : Nopal_router.Platform.S) in
  let router =
    Nopal_router.Router.create ~platform ~parse:Todomvc.parse
      ~to_path:Todomvc.to_path ~not_found:Todomvc.All_route
  in
  let storage = (module Storage_local : Todomvc.Storage) in
  Nopal_web.mount
    (module struct
      type model = Todomvc.model
      type msg = Todomvc.msg

      let init = Todomvc.init storage router
      let update = Todomvc.update storage
      let view = Todomvc.view
      let subscriptions = Todomvc.subscriptions
    end)
    target

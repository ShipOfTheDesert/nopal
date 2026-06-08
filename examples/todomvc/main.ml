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

let serialize_msg : Todomvc.msg -> string = function
  | Todomvc.Input_changed text -> "Input_changed " ^ text
  | Todomvc.Add_todo -> "Add_todo"
  | Todomvc.Toggle id -> Printf.sprintf "Toggle %d" id
  | Todomvc.Toggle_all -> "Toggle_all"
  | Todomvc.Delete id -> Printf.sprintf "Delete %d" id
  | Todomvc.Start_editing id -> Printf.sprintf "Start_editing %d" id
  | Todomvc.Edit_changed text -> "Edit_changed " ^ text
  | Todomvc.Submit_edit -> "Submit_edit"
  | Todomvc.Cancel_edit -> "Cancel_edit"
  | Todomvc.Clear_completed -> "Clear_completed"
  | Todomvc.Navigate_to _ -> "Navigate_to"
  | Todomvc.Route_changed _ -> "Route_changed"

let serialize_model (model : Todomvc.model) =
  let completed =
    List.length
      (List.filter (fun (t : Todomvc.todo) -> t.completed) model.todos)
  in
  let titles =
    String.concat "|" (List.map (fun (t : Todomvc.todo) -> t.title) model.todos)
  in
  (* Each field is terminated with ';' so substring assertions can't prefix-alias
     (e.g. "completed=1;" does not match "completed=10;"). *)
  Printf.sprintf "completed=%d; titles=[%s];" completed titles

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
  let platform =
    (module Nopal_web.Platform_web : Nopal_platform.Platform.NAV)
  in
  let router =
    Nopal_platform.Router.create ~platform ~parse:Todomvc.parse
      ~to_path:Todomvc.to_path ~not_found:Todomvc.All_route
  in
  let storage = (module Storage_local : Todomvc.Storage) in
  let (_ : Nopal_runtime.Telemetry.handle) =
    Nopal_web.mount_with_telemetry
      (module struct
        type model = Todomvc.model
        type msg = Todomvc.msg

        let init = Todomvc.init storage router
        let update = Todomvc.update storage
        let view = Todomvc.view
        let subscriptions = Todomvc.subscriptions
      end)
      ~serialize_msg ~serialize_model target
  in
  ()

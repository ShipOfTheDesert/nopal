module E = Nopal_element.Element

type todo = { id : int; title : string; completed : bool }
type filter = All | Active | Completed
type editing = { id : int; text : string; original : string }
type route = All_route | Active_route | Completed_route

type model = {
  todos : todo list;
  filter : filter;
  input : string;
  editing : editing option;
  next_id : int;
  router : route Nopal_router.Router.t;
}

type msg =
  | Input_changed of string
  | Add_todo
  | Toggle of int
  | Toggle_all
  | Delete of int
  | Start_editing of int
  | Edit_changed of string
  | Submit_edit
  | Cancel_edit
  | Clear_completed
  | Navigate_to of route
  | Route_changed of route

module type Storage = sig
  val load : unit -> todo list
  val save : todo list -> unit
end

let parse = function
  | "/"
  | "" ->
      Some All_route
  | "/active" -> Some Active_route
  | "/completed" -> Some Completed_route
  | _ -> None

let to_path = function
  | All_route -> "/"
  | Active_route -> "/active"
  | Completed_route -> "/completed"

let filter_of_route = function
  | All_route -> All
  | Active_route -> Active
  | Completed_route -> Completed

let init (module S : Storage) router () =
  let todos = S.load () in
  let next_id =
    match todos with
    | [] -> 1
    | _ -> 1 + List.fold_left (fun acc (t : todo) -> max acc t.id) 0 todos
  in
  let route = Nopal_router.Router.current router in
  ( {
      todos;
      filter = filter_of_route route;
      input = "";
      editing = None;
      next_id;
      router;
    },
    Nopal_mvu.Cmd.none )

let save_and_return (module S : Storage) model =
  S.save model.todos;
  (model, Nopal_mvu.Cmd.none)

let update (module S : Storage) model msg =
  match msg with
  | Input_changed text -> ({ model with input = text }, Nopal_mvu.Cmd.none)
  | Add_todo ->
      let trimmed = String.trim model.input in
      if String.length trimmed = 0 then
        ({ model with input = "" }, Nopal_mvu.Cmd.none)
      else
        let todo = { id = model.next_id; title = trimmed; completed = false } in
        save_and_return
          (module S)
          {
            model with
            todos = todo :: model.todos;
            input = "";
            next_id = model.next_id + 1;
          }
  | Toggle id ->
      let todos =
        List.map
          (fun (t : todo) ->
            if t.id = id then { t with completed = not t.completed } else t)
          model.todos
      in
      save_and_return (module S) { model with todos }
  | Toggle_all ->
      let all_completed =
        List.for_all (fun (t : todo) -> t.completed) model.todos
      in
      let todos =
        List.map
          (fun (t : todo) -> { t with completed = not all_completed })
          model.todos
      in
      save_and_return (module S) { model with todos }
  | Delete id ->
      let todos = List.filter (fun (t : todo) -> t.id <> id) model.todos in
      save_and_return (module S) { model with todos }
  | Start_editing id ->
      let editing =
        match List.find_opt (fun (t : todo) -> t.id = id) model.todos with
        | Some t -> Some { id; text = t.title; original = t.title }
        | None -> None
      in
      ({ model with editing }, Nopal_mvu.Cmd.none)
  | Edit_changed text ->
      let editing =
        match model.editing with
        | Some e -> Some { e with text }
        | None -> None
      in
      ({ model with editing }, Nopal_mvu.Cmd.none)
  | Submit_edit -> (
      match model.editing with
      | None -> (model, Nopal_mvu.Cmd.none)
      | Some { id; text; _ } ->
          let trimmed = String.trim text in
          if String.length trimmed = 0 then
            let todos =
              List.filter (fun (t : todo) -> t.id <> id) model.todos
            in
            save_and_return (module S) { model with todos; editing = None }
          else
            let todos =
              List.map
                (fun (t : todo) ->
                  if t.id = id then { t with title = trimmed } else t)
                model.todos
            in
            save_and_return (module S) { model with todos; editing = None })
  | Cancel_edit ->
      (* Clear editing immediately. When the input is removed from the DOM,
         blur fires Submit_edit, but it sees editing = None and does nothing. *)
      ({ model with editing = None }, Nopal_mvu.Cmd.none)
  | Clear_completed ->
      let todos = List.filter (fun (t : todo) -> not t.completed) model.todos in
      save_and_return (module S) { model with todos }
  | Navigate_to route ->
      ( { model with filter = filter_of_route route },
        Nopal_router.Router.push model.router route )
  | Route_changed route ->
      ({ model with filter = filter_of_route route }, Nopal_mvu.Cmd.none)

let visible_todos model =
  match model.filter with
  | All -> model.todos
  | Active -> List.filter (fun t -> not t.completed) model.todos
  | Completed -> List.filter (fun t -> t.completed) model.todos

let active_count model =
  List.length (List.filter (fun t -> not t.completed) model.todos)

let has_completed model = List.exists (fun t -> t.completed) model.todos

let view_todo_item editing (todo : todo) =
  let is_editing =
    match editing with
    | Some (e : editing) -> e.id = todo.id
    | None -> false
  in
  E.keyed
    ("todo-" ^ string_of_int todo.id)
    (E.row
       (if is_editing then
          let edit_text =
            match editing with
            | Some e -> e.text
            | None -> todo.title
          in
          [
            E.input
              ~attrs:[ ("data-action", "edit-input") ]
              ~on_change:(fun s -> Edit_changed s)
              ~on_blur:Submit_edit
              ~on_keydown:(fun key ->
                match key with
                | "Escape" -> Some Cancel_edit
                | "Enter" -> Some Submit_edit
                | _ -> None)
              edit_text;
          ]
        else
          [
            E.button
              ~attrs:[ ("data-action", "toggle-" ^ string_of_int todo.id) ]
              ~on_click:(Toggle todo.id)
              (E.text (if todo.completed then "[x]" else "[ ]"));
            E.button
              ~attrs:[ ("data-action", "edit-" ^ string_of_int todo.id) ]
              ~on_dblclick:(Start_editing todo.id) (E.text todo.title);
            E.button
              ~attrs:[ ("data-action", "delete-" ^ string_of_int todo.id) ]
              ~on_click:(Delete todo.id) (E.text "x");
          ]))

let view_header model =
  E.row
    [
      E.input ~placeholder:"What needs to be done?"
        ~on_change:(fun s -> Input_changed s)
        ~on_submit:Add_todo model.input;
    ]

let view_main model =
  let todos = visible_todos model in
  E.column
    ~attrs:[ ("data-section", "main") ]
    (E.button
       ~attrs:[ ("data-action", "toggle-all") ]
       ~on_click:Toggle_all (E.text "Toggle all")
    :: List.map (view_todo_item model.editing) todos)

let view_filter_link current_filter filter label =
  let selected = current_filter = filter in
  E.button
    ~attrs:(if selected then [ ("data-selected", "true") ] else [])
    ~on_click:
      (Navigate_to
         (match filter with
         | All -> All_route
         | Active -> Active_route
         | Completed -> Completed_route))
    (E.text label)

let view_footer model =
  let count = active_count model in
  let count_text =
    string_of_int count ^ " item" ^ (if count <> 1 then "s" else "") ^ " left"
  in
  let base =
    [
      E.row ~attrs:[ ("data-section", "todo-count") ] [ E.text count_text ];
      E.row
        [
          view_filter_link model.filter All "All";
          view_filter_link model.filter Active "Active";
          view_filter_link model.filter Completed "Completed";
        ];
    ]
  in
  let children =
    match has_completed model with
    | true ->
        base @ [ E.button ~on_click:Clear_completed (E.text "Clear completed") ]
    | false -> base
  in
  E.column ~attrs:[ ("data-section", "footer") ] children

let view model =
  E.column
    (match model.todos with
    | [] -> [ view_header model ]
    | _ :: _ -> [ view_header model; view_main model; view_footer model ])

let subscriptions model =
  Nopal_router.Router.on_navigate model.router (fun route ->
      Route_changed route)

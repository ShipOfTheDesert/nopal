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

open Nopal_style

(* Colors *)
let bg_page = Style.hex "#faf9f7"
let bg_card = Style.hex "#ffffff"
let border_color = Style.hex "#e5e3df"
let accent = Style.hex "#4a90d9"
let check_green = Style.hex "#5ba85b"

(* Page *)
let page_style =
  Style.default
  |> Style.with_layout (fun l ->
      {
        l with
        width = Some Fill;
        height = Some Fill;
        cross_align = Some Center;
      }
      |> Style.padding 48.0 16.0 32.0 16.0)
  |> Style.with_paint (fun p -> { p with background = Some bg_page })

(* Card *)
let card_style =
  Style.default
  |> Style.with_layout (fun l ->
      {
        l with
        width = Some (Fixed 480.0);
        gap = Some 0.0;
        cross_align = Some Stretch;
      })
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some bg_card;
        border =
          Some
            { width = 1.0; style = Solid; color = border_color; radius = 10.0 };
        shadow =
          Some { x = 0.0; y = 2.0; blur = 12.0; color = Style.rgba 0 0 0 0.06 };
      })

(* Title *)
let title_text =
  Text.default
  |> Text.font_size 2.0
  |> Text.font_weight Font.Thin
  |> Text.font_family System_ui

let title_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with main_align = Some Center; cross_align = Some Center }
      |> Style.padding 24.0 0.0 16.0 0.0)

(* Header input *)
let header_style =
  Style.default
  |> Style.with_layout (fun l -> l |> Style.padding 0.0 16.0 10.0 16.0)

let input_style =
  Style.default
  |> Style.with_layout (fun l -> l |> Style.padding 12.0 16.0 12.0 16.0)
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some (Style.hex "#f8f7f5");
        border =
          Some
            { width = 1.0; style = Solid; color = border_color; radius = 8.0 };
      })
  |> Style.with_text (fun t -> t |> Text.font_size 1.0)

let input_interaction =
  let focused =
    Style.default
    |> Style.with_paint (fun p ->
        {
          p with
          border =
            Some { width = 2.0; style = Solid; color = accent; radius = 8.0 };
          shadow =
            Some
              {
                x = 0.0;
                y = 0.0;
                blur = 6.0;
                color = Style.rgba 74 144 217 0.15;
              };
        })
  in
  { Interaction.default with focused = Some focused }

(* Todo items *)
let todo_row_style =
  Style.default
  |> Style.with_layout (fun l ->
      {
        l with
        direction = Some Row_dir;
        cross_align = Some Center;
        gap = Some 12.0;
      }
      |> Style.padding 12.0 16.0 12.0 16.0)
  |> Style.with_paint (fun p ->
      {
        p with
        border =
          Some
            { width = 0.0; style = Solid; color = border_color; radius = 0.0 };
      })

let todo_row_interaction =
  let hover =
    Style.default
    |> Style.with_paint (fun p ->
        { p with background = Some (Style.hex "#faf9f7") })
  in
  { Interaction.default with hover = Some hover }

let divider_style =
  Style.default
  |> Style.with_layout (fun l -> { l with height = Some (Fixed 1.0) })
  |> Style.with_paint (fun p ->
      { p with background = Some (Style.hex "#f0eeea") })

let checkbox_style completed =
  Style.default
  |> Style.with_layout (fun l ->
      {
        l with
        width = Some (Fixed 24.0);
        height = Some (Fixed 24.0);
        main_align = Some Center;
        cross_align = Some Center;
      })
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some (if completed then check_green else Style.transparent);
        border =
          Some
            {
              width = (if completed then 0.0 else 2.0);
              style = Solid;
              color = (if completed then Style.transparent else border_color);
              radius = 6.0;
            };
      })
  |> Style.with_text (fun t -> t |> Text.font_size 0.7)

let title_button_style completed =
  Style.default
  |> Style.with_layout (fun l ->
      { l with flex_grow = Some 1.0; cross_align = Some Start })
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some Style.transparent;
        border =
          Some
            {
              width = 0.0;
              style = Solid;
              color = Style.transparent;
              radius = 0.0;
            };
      })
  |> Style.with_text (fun t ->
      let t' = t |> Text.font_size 1.0 |> Text.text_align Align_left in
      if completed then t' |> Text.text_decoration Line_through else t')

let delete_style =
  Style.default
  |> Style.with_layout (fun l ->
      {
        l with
        width = Some (Fixed 28.0);
        height = Some (Fixed 28.0);
        main_align = Some Center;
        cross_align = Some Center;
      })
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some Style.transparent;
        border =
          Some
            {
              width = 0.0;
              style = Solid;
              color = Style.transparent;
              radius = 6.0;
            };
        opacity = 0.0;
      })
  |> Style.with_text (fun t -> t |> Text.font_size 0.85)

let delete_interaction =
  let hover =
    Style.default
    |> Style.with_paint (fun p ->
        { p with background = Some (Style.hex "#ffeeed"); opacity = 1.0 })
  in
  { Interaction.default with hover = Some hover }

let edit_input_style =
  Style.default
  |> Style.with_layout (fun l -> l |> Style.padding 10.0 14.0 10.0 14.0)
  |> Style.with_paint (fun p ->
      {
        p with
        border =
          Some { width = 2.0; style = Solid; color = accent; radius = 6.0 };
        shadow =
          Some
            { x = 0.0; y = 0.0; blur = 6.0; color = Style.rgba 74 144 217 0.15 };
      })
  |> Style.with_text (fun t -> t |> Text.font_size 1.0)

(* Toggle all *)
let toggle_all_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with cross_align = Some Start } |> Style.padding 10.0 16.0 10.0 16.0)
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some Style.transparent;
        border =
          Some
            {
              width = 0.0;
              style = Solid;
              color = Style.transparent;
              radius = 0.0;
            };
      })
  |> Style.with_text (fun t ->
      t
      |> Text.font_size 0.8
      |> Text.text_transform Uppercase
      |> Text.letter_spacing (Ls_em 0.05)
      |> Text.font_weight Font.Medium
      |> Text.text_align Align_left)

let toggle_all_interaction =
  let hover =
    Style.default
    |> Style.with_paint (fun p ->
        { p with background = Some (Style.hex "#f5f4f1") })
  in
  { Interaction.default with hover = Some hover }

(* Footer *)
let footer_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = Some 8.0 } |> Style.padding 12.0 16.0 16.0 16.0)
  |> Style.with_paint (fun p ->
      { p with background = Some (Style.hex "#faf9f7") })

let count_text_style = Text.default |> Text.font_size 0.85

let filter_row_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with direction = Some Row_dir; gap = Some 4.0 })

let filter_button_style selected =
  Style.default
  |> Style.with_layout (fun l -> l |> Style.padding 4.0 10.0 4.0 10.0)
  |> Style.with_paint (fun p ->
      {
        p with
        background =
          Some (if selected then Style.hex "#eeedea" else Style.transparent);
        border =
          Some
            {
              width = (if selected then 1.0 else 0.0);
              style = Solid;
              color = (if selected then border_color else Style.transparent);
              radius = 6.0;
            };
      })
  |> Style.with_text (fun t ->
      t
      |> Text.font_size 0.8
      |> Text.font_weight (if selected then Font.Semi_bold else Font.Normal))

let filter_button_interaction =
  let hover =
    Style.default
    |> Style.with_paint (fun p ->
        { p with background = Some (Style.hex "#f0eeea") })
  in
  { Interaction.default with hover = Some hover }

let clear_button_style =
  Style.default
  |> Style.with_layout (fun l -> l |> Style.padding 4.0 10.0 4.0 10.0)
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some Style.transparent;
        border =
          Some
            {
              width = 0.0;
              style = Solid;
              color = Style.transparent;
              radius = 6.0;
            };
      })
  |> Style.with_text (fun t -> t |> Text.font_size 0.8)

let clear_button_interaction =
  let hover =
    Style.default
    |> Style.with_paint (fun p ->
        { p with background = Some (Style.hex "#ffeeed") })
    |> Style.with_text (fun t -> t |> Text.font_weight Font.Medium)
  in
  { Interaction.default with hover = Some hover }

(* View functions *)

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
    (E.row ~style:todo_row_style ~interaction:todo_row_interaction
       (if is_editing then
          let edit_text =
            match editing with
            | Some e -> e.text
            | None -> todo.title
          in
          [
            E.input ~style:edit_input_style
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
              ~style:(checkbox_style todo.completed)
              ~attrs:[ ("data-action", "toggle-" ^ string_of_int todo.id) ]
              ~on_click:(Toggle todo.id)
              (E.text (if todo.completed then "\xe2\x9c\x93" else ""));
            E.button
              ~style:(title_button_style todo.completed)
              ~attrs:[ ("data-action", "edit-" ^ string_of_int todo.id) ]
              ~on_dblclick:(Start_editing todo.id)
              (E.styled_text
                 ~text_style:
                   (if todo.completed then Text.default |> Text.font_size 1.0
                    else Text.default |> Text.font_size 1.0)
                 todo.title);
            E.button ~style:delete_style ~interaction:delete_interaction
              ~attrs:[ ("data-action", "delete-" ^ string_of_int todo.id) ]
              ~on_click:(Delete todo.id) (E.text "\xc3\x97");
          ]))

let view_header model =
  E.column ~style:header_style
    [
      E.input ~style:input_style ~interaction:input_interaction
        ~placeholder:"What needs to be done?"
        ~on_change:(fun s -> Input_changed s)
        ~on_submit:Add_todo model.input;
    ]

let view_main model =
  let todos = visible_todos model in
  let items =
    List.concat_map
      (fun todo ->
        [ E.box ~style:divider_style []; view_todo_item model.editing todo ])
      todos
  in
  E.column
    ~attrs:[ ("data-section", "main") ]
    (E.button ~style:toggle_all_style ~interaction:toggle_all_interaction
       ~attrs:[ ("data-action", "toggle-all") ]
       ~on_click:Toggle_all
       (E.styled_text
          ~text_style:
            (Text.default |> Text.font_size 0.8 |> Text.font_weight Font.Medium)
          "Toggle all")
    :: E.box ~style:divider_style []
    :: items)

let view_filter_link current_filter filter label =
  let selected = current_filter = filter in
  E.button
    ~style:(filter_button_style selected)
    ~interaction:filter_button_interaction
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
      E.row
        ~attrs:[ ("data-section", "todo-count") ]
        [ E.styled_text ~text_style:count_text_style count_text ];
      E.row ~style:filter_row_style
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
        base
        @ [
            E.button ~style:clear_button_style
              ~interaction:clear_button_interaction ~on_click:Clear_completed
              (E.text "Clear completed");
          ]
    | false -> base
  in
  E.column ~style:footer_style ~attrs:[ ("data-section", "footer") ] children

let view _vp model =
  E.column ~style:page_style
    [
      E.column ~style:card_style
        (E.box ~style:title_style
           [ E.styled_text ~text_style:title_text "todos" ]
        ::
        (match model.todos with
        | [] -> [ view_header model ]
        | _ :: _ -> [ view_header model; view_main model; view_footer model ]));
    ]

let subscriptions model =
  Nopal_router.Router.on_navigate model.router (fun route ->
      Route_changed route)

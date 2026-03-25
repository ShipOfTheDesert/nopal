type node =
  | Empty
  | Text of { content : string; text_style : Nopal_style.Text.t option }
  | Element of {
      tag : string;
      attrs : (string * string) list;
      children : node list;
      interaction : Nopal_style.Interaction.t;
    }

type 'msg handler_entry = {
  path : int list;
  on_click : 'msg option;
  on_dblclick : 'msg option;
  on_change : (string -> 'msg) option;
  on_submit : 'msg option;
  on_blur : 'msg option;
  on_keydown : (string -> 'msg option) option;
  on_toggle : (bool -> 'msg) option;
}

type 'msg draw_handler_entry = {
  draw_path : int list;
  on_pointer_move : (Nopal_element.Element.pointer_event -> 'msg) option;
  on_pointer_click : (Nopal_element.Element.pointer_event -> 'msg) option;
  on_pointer_leave : 'msg option;
  on_pointer_down : (Nopal_element.Element.pointer_event -> 'msg) option;
  on_pointer_up : (Nopal_element.Element.pointer_event -> 'msg) option;
  on_wheel : (Nopal_element.Element.wheel_event -> 'msg) option;
}

type 'msg box_handler_entry = {
  box_path : int list;
  on_pointer_move : (Nopal_element.Element.pointer_event -> 'msg) option;
  on_pointer_leave : 'msg option;
  on_pointer_down : (Nopal_element.Element.pointer_event -> 'msg) option;
  on_pointer_up : (Nopal_element.Element.pointer_event -> 'msg) option;
  on_wheel : (Nopal_element.Element.wheel_event -> 'msg) option;
}

type 'msg rendered = {
  tree : node;
  msgs : 'msg list ref;
  (* mutable — justified: accumulates messages across event simulations
     in multi-step interaction tests (PRD Decision 2) *)
  handlers : 'msg handler_entry list;
  draw_handlers : 'msg draw_handler_entry list;
  box_handlers : 'msg box_handler_entry list;
}

let render (element : 'msg Nopal_element.Element.t) : 'msg rendered =
  let handlers = ref [] in
  let draw_handlers = ref [] in
  let box_handlers = ref [] in
  let rec go rev_path (el : 'msg Nopal_element.Element.t) : node =
    match el with
    | Empty -> Empty
    | Text { content; text_style } -> Text { content; text_style }
    | Box
        {
          style = _;
          interaction;
          attrs;
          children;
          on_pointer_move;
          on_pointer_leave;
          on_pointer_down;
          on_pointer_up;
          on_wheel;
        } ->
        let has_handler =
          Option.is_some on_pointer_move
          || Option.is_some on_pointer_leave
          || Option.is_some on_pointer_down
          || Option.is_some on_pointer_up
          || Option.is_some on_wheel
        in
        if has_handler then
          box_handlers :=
            {
              box_path = List.rev rev_path;
              on_pointer_move;
              on_pointer_leave;
              on_pointer_down;
              on_pointer_up;
              on_wheel;
            }
            :: !box_handlers;
        Element
          {
            tag = "box";
            attrs;
            children = go_children rev_path children;
            interaction;
          }
    | Row { style = _; interaction; attrs; children } ->
        Element
          {
            tag = "row";
            attrs;
            children = go_children rev_path children;
            interaction;
          }
    | Column { style = _; interaction; attrs; children } ->
        Element
          {
            tag = "column";
            attrs;
            children = go_children rev_path children;
            interaction;
          }
    | Button { style = _; interaction; attrs; on_click; on_dblclick; child } ->
        handlers :=
          {
            path = List.rev rev_path;
            on_click;
            on_dblclick;
            on_change = None;
            on_submit = None;
            on_blur = None;
            on_keydown = None;
            on_toggle = None;
          }
          :: !handlers;
        Element
          {
            tag = "button";
            attrs;
            children = [ go (0 :: rev_path) child ];
            interaction;
          }
    | Input
        {
          style = _;
          interaction;
          attrs;
          value;
          placeholder;
          on_change;
          on_submit;
          on_blur;
          on_keydown;
        } ->
        handlers :=
          {
            path = List.rev rev_path;
            on_click = None;
            on_dblclick = None;
            on_change;
            on_submit;
            on_blur;
            on_keydown;
            on_toggle = None;
          }
          :: !handlers;
        Element
          {
            tag = "input";
            attrs = [ ("value", value); ("placeholder", placeholder) ] @ attrs;
            children = [];
            interaction;
          }
    | Checkbox { style = _; interaction; attrs; checked; disabled; on_toggle }
      ->
        if not disabled then
          handlers :=
            {
              path = List.rev rev_path;
              on_click = None;
              on_dblclick = None;
              on_change = None;
              on_submit = None;
              on_blur = None;
              on_keydown = None;
              on_toggle;
            }
            :: !handlers;
        Element
          {
            tag = "checkbox";
            attrs =
              [
                ("checked", string_of_bool checked);
                ("disabled", string_of_bool disabled);
              ]
              @ attrs;
            children = [];
            interaction;
          }
    | Radio
        { style = _; interaction; attrs; name; checked; disabled; on_select } ->
        if not disabled then
          handlers :=
            {
              path = List.rev rev_path;
              on_click = on_select;
              on_dblclick = None;
              on_change = None;
              on_submit = None;
              on_blur = None;
              on_keydown = None;
              on_toggle = None;
            }
            :: !handlers;
        Element
          {
            tag = "radio";
            attrs =
              [
                ("name", name);
                ("checked", string_of_bool checked);
                ("disabled", string_of_bool disabled);
              ]
              @ attrs;
            children = [];
            interaction;
          }
    | Select
        {
          style = _;
          interaction;
          attrs;
          options;
          selected;
          disabled;
          on_change;
        } ->
        if not disabled then
          handlers :=
            {
              path = List.rev rev_path;
              on_click = None;
              on_dblclick = None;
              on_change;
              on_submit = None;
              on_blur = None;
              on_keydown = None;
              on_toggle = None;
            }
            :: !handlers;
        let option_children =
          List.map
            (fun (opt : Nopal_element.Element.select_option) ->
              Element
                {
                  tag = "option";
                  attrs =
                    [
                      ("value", opt.value);
                      ("label", opt.label);
                      ("disabled", string_of_bool opt.disabled);
                    ];
                  children = [];
                  interaction = Nopal_style.Interaction.default;
                })
            options
        in
        Element
          {
            tag = "select";
            attrs =
              [ ("selected", selected); ("disabled", string_of_bool disabled) ]
              @ attrs;
            children = option_children;
            interaction;
          }
    | Image { style = _; src; alt } ->
        Element
          {
            tag = "image";
            attrs = [ ("src", src); ("alt", alt) ];
            children = [];
            interaction = Nopal_style.Interaction.default;
          }
    | Scroll { style = _; child } ->
        Element
          {
            tag = "scroll";
            attrs = [];
            children = [ go (0 :: rev_path) child ];
            interaction = Nopal_style.Interaction.default;
          }
    | Keyed { key; child } ->
        Element
          {
            tag = "keyed";
            attrs = [ ("key", key) ];
            children = [ go (0 :: rev_path) child ];
            interaction = Nopal_style.Interaction.default;
          }
    | Draw
        {
          width;
          height;
          scene;
          on_pointer_move;
          on_click;
          on_pointer_leave;
          on_pointer_down;
          on_pointer_up;
          on_wheel;
          _;
        } ->
        draw_handlers :=
          {
            draw_path = List.rev rev_path;
            on_pointer_move;
            on_pointer_click = on_click;
            on_pointer_leave;
            on_pointer_down;
            on_pointer_up;
            on_wheel;
          }
          :: !draw_handlers;
        Element
          {
            tag = "canvas";
            attrs =
              [
                ("width", string_of_float width);
                ("height", string_of_float height);
                ("scene-nodes", string_of_int (List.length scene));
              ];
            children = [];
            interaction = Nopal_style.Interaction.default;
          }
  and go_children rev_path children =
    List.mapi (fun i c -> go (i :: rev_path) c) children
  in
  let tree = go [] element in
  {
    tree;
    msgs = ref [];
    handlers = !handlers;
    draw_handlers = !draw_handlers;
    box_handlers = !box_handlers;
  }

let tree r = r.tree
let messages r = List.rev !(r.msgs)
let clear_messages r = r.msgs := []

type selector =
  | By_tag of string
  | By_text of string
  | By_attr of string * string
  | First_child
  | Nth_child of int

let string_contains ~haystack ~needle =
  let nlen = String.length needle in
  let hlen = String.length haystack in
  if nlen = 0 then true
  else
    let rec check i =
      if i > hlen - nlen then false
      else if String.sub haystack i nlen = needle then true
      else check (i + 1)
    in
    check 0

let rec text_content node =
  match node with
  | Empty -> ""
  | Text { content; _ } -> content
  | Element { children; _ } -> String.concat "" (List.map text_content children)

let text_style node =
  match node with
  | Text { text_style; _ } -> text_style
  | Empty
  | Element _ ->
      None

let rec find sel node =
  match sel with
  | By_tag tag -> (
      match node with
      | Element { tag = t; children; _ } ->
          if String.equal t tag then Some node
          else find_in_children sel children
      | Empty
      | Text _ ->
          None)
  | By_text s -> (
      match node with
      | Text { content; _ } when string_contains ~haystack:content ~needle:s ->
          Some node
      | Element { children; _ } -> find_in_children sel children
      | Empty
      | Text _ ->
          None)
  | By_attr (name, value) -> (
      match node with
      | Element { attrs; children; _ } ->
          if
            List.exists
              (fun (k, v) -> String.equal k name && String.equal v value)
              attrs
          then Some node
          else find_in_children sel children
      | Empty
      | Text _ ->
          None)
  | First_child -> (
      match node with
      | Element { children = c :: _; _ } -> Some c
      | Empty
      | Text _
      | Element { children = []; _ } ->
          None)
  | Nth_child n -> (
      match node with
      | Element { children; _ } -> List.nth_opt children n
      | Empty
      | Text _ ->
          None)

and find_in_children sel children =
  match children with
  | [] -> None
  | c :: rest -> (
      match find sel c with
      | Some _ as result -> result
      | None -> find_in_children sel rest)

let find_all sel node =
  let rec go acc n =
    match sel with
    | By_tag tag -> (
        match n with
        | Element { tag = t; children; _ } ->
            let acc = if String.equal t tag then n :: acc else acc in
            List.fold_left go acc children
        | Empty
        | Text _ ->
            acc)
    | By_text s -> (
        match n with
        | Text { content; _ } when string_contains ~haystack:content ~needle:s
          ->
            n :: acc
        | Element { children; _ } -> List.fold_left go acc children
        | Empty
        | Text _ ->
            acc)
    | By_attr (name, value) -> (
        match n with
        | Element { attrs; children; _ } ->
            let acc =
              if
                List.exists
                  (fun (k, v) -> String.equal k name && String.equal v value)
                  attrs
              then n :: acc
              else acc
            in
            List.fold_left go acc children
        | Empty
        | Text _ ->
            acc)
    | First_child
    | Nth_child _ ->
        acc
  in
  List.rev (go [] node)

let interaction node =
  match node with
  | Element { interaction; _ } -> Some interaction
  | Empty
  | Text _ ->
      None

let has_hover node =
  match interaction node with
  | Some ix -> Option.is_some ix.Nopal_style.Interaction.hover
  | None -> false

let has_pressed node =
  match interaction node with
  | Some ix -> Option.is_some ix.Nopal_style.Interaction.pressed
  | None -> false

let has_focused node =
  match interaction node with
  | Some ix -> Option.is_some ix.Nopal_style.Interaction.focused
  | None -> false

let has_attr name node =
  match node with
  | Element { attrs; _ } ->
      List.exists (fun (k, _) -> String.equal k name) attrs
  | Empty
  | Text _ ->
      false

let attr name node =
  match node with
  | Element { attrs; _ } -> (
      match List.find_opt (fun (k, _) -> String.equal k name) attrs with
      | Some (_, v) -> Some v
      | None -> None)
  | Empty
  | Text _ ->
      None

type error =
  | Not_found of selector
  | No_handler of { tag : string; event : string }

let tag_of_node = function
  | Element { tag; _ } -> tag
  | Text _ -> "text"
  | Empty -> "empty"

let resolve_path sel node =
  let rec go rev_path n =
    match sel with
    | By_tag tag -> (
        match n with
        | Element { tag = t; children; _ } ->
            if String.equal t tag then Some (List.rev rev_path, n)
            else go_children rev_path children
        | Empty
        | Text _ ->
            None)
    | By_text s -> (
        match n with
        | Text { content; _ } when string_contains ~haystack:content ~needle:s
          ->
            Some (List.rev rev_path, n)
        | Element { children; _ } -> go_children rev_path children
        | Empty
        | Text _ ->
            None)
    | By_attr (name, value) -> (
        match n with
        | Element { attrs; children; _ } ->
            if
              List.exists
                (fun (k, v) -> String.equal k name && String.equal v value)
                attrs
            then Some (List.rev rev_path, n)
            else go_children rev_path children
        | Empty
        | Text _ ->
            None)
    | First_child -> (
        match n with
        | Element { children = c :: _; _ } -> Some (List.rev (0 :: rev_path), c)
        | Empty
        | Text _
        | Element { children = []; _ } ->
            None)
    | Nth_child idx -> (
        match n with
        | Element { children; _ } -> (
            match List.nth_opt children idx with
            | Some c -> Some (List.rev (idx :: rev_path), c)
            | None -> None)
        | Empty
        | Text _ ->
            None)
  and go_children rev_path children =
    let rec aux i = function
      | [] -> None
      | c :: rest -> (
          match go (i :: rev_path) c with
          | Some _ as result -> result
          | None -> aux (i + 1) rest)
    in
    aux 0 children
  in
  go [] node

let find_handler_by_path path handlers =
  List.find_opt (fun h -> h.path = path) handlers

let ( let* ) = Result.bind

let click sel r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_handler_by_path path r.handlers
    |> Option.to_result ~none:(No_handler { tag; event = "click" })
  in
  match handler.on_click with
  | None -> Error (No_handler { tag; event = "click" })
  | Some msg ->
      r.msgs := msg :: !(r.msgs);
      Ok ()

let toggle sel r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_handler_by_path path r.handlers
    |> Option.to_result ~none:(No_handler { tag; event = "toggle" })
  in
  match handler.on_toggle with
  | None -> Error (No_handler { tag; event = "toggle" })
  | Some f ->
      let checked =
        match attr "checked" found with
        | Some "true" -> true
        | Some _
        | None ->
            false
      in
      r.msgs := f (not checked) :: !(r.msgs);
      Ok ()

let input sel value r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_handler_by_path path r.handlers
    |> Option.to_result ~none:(No_handler { tag; event = "change" })
  in
  match handler.on_change with
  | None -> Error (No_handler { tag; event = "change" })
  | Some f ->
      r.msgs := f value :: !(r.msgs);
      Ok ()

let submit sel r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_handler_by_path path r.handlers
    |> Option.to_result ~none:(No_handler { tag; event = "submit" })
  in
  match handler.on_submit with
  | None -> Error (No_handler { tag; event = "submit" })
  | Some msg ->
      r.msgs := msg :: !(r.msgs);
      Ok ()

let dblclick sel r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_handler_by_path path r.handlers
    |> Option.to_result ~none:(No_handler { tag; event = "dblclick" })
  in
  match handler.on_dblclick with
  | None -> Error (No_handler { tag; event = "dblclick" })
  | Some msg ->
      r.msgs := msg :: !(r.msgs);
      Ok ()

let blur sel r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_handler_by_path path r.handlers
    |> Option.to_result ~none:(No_handler { tag; event = "blur" })
  in
  match handler.on_blur with
  | None -> Error (No_handler { tag; event = "blur" })
  | Some msg ->
      r.msgs := msg :: !(r.msgs);
      Ok ()

let keydown sel key r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_handler_by_path path r.handlers
    |> Option.to_result ~none:(No_handler { tag; event = "keydown" })
  in
  match handler.on_keydown with
  | None -> Error (No_handler { tag; event = "keydown" })
  | Some f -> (
      match f key with
      | None -> Ok ()
      | Some msg ->
          r.msgs := msg :: !(r.msgs);
          Ok ())

let find_draw_handler_by_path path draw_handlers =
  List.find_opt (fun h -> h.draw_path = path) draw_handlers

let pointer_move sel ~x ~y r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_draw_handler_by_path path r.draw_handlers
    |> Option.to_result ~none:(No_handler { tag; event = "pointer_move" })
  in
  match handler.on_pointer_move with
  | None -> Error (No_handler { tag; event = "pointer_move" })
  | Some f ->
      r.msgs :=
        f { Nopal_element.Element.x; y; client_x = x; client_y = y }
        :: !(r.msgs);
      Ok ()

let pointer_click sel ~x ~y r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_draw_handler_by_path path r.draw_handlers
    |> Option.to_result ~none:(No_handler { tag; event = "pointer_click" })
  in
  match handler.on_pointer_click with
  | None -> Error (No_handler { tag; event = "pointer_click" })
  | Some f ->
      r.msgs :=
        f { Nopal_element.Element.x; y; client_x = x; client_y = y }
        :: !(r.msgs);
      Ok ()

let pointer_leave sel r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_draw_handler_by_path path r.draw_handlers
    |> Option.to_result ~none:(No_handler { tag; event = "pointer_leave" })
  in
  match handler.on_pointer_leave with
  | None -> Error (No_handler { tag; event = "pointer_leave" })
  | Some msg ->
      r.msgs := msg :: !(r.msgs);
      Ok ()

let pointer_down sel ~x ~y r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_draw_handler_by_path path r.draw_handlers
    |> Option.to_result ~none:(No_handler { tag; event = "pointer_down" })
  in
  match handler.on_pointer_down with
  | None -> Error (No_handler { tag; event = "pointer_down" })
  | Some f ->
      r.msgs :=
        f { Nopal_element.Element.x; y; client_x = x; client_y = y }
        :: !(r.msgs);
      Ok ()

let pointer_up sel ~x ~y r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_draw_handler_by_path path r.draw_handlers
    |> Option.to_result ~none:(No_handler { tag; event = "pointer_up" })
  in
  match handler.on_pointer_up with
  | None -> Error (No_handler { tag; event = "pointer_up" })
  | Some f ->
      r.msgs :=
        f { Nopal_element.Element.x; y; client_x = x; client_y = y }
        :: !(r.msgs);
      Ok ()

let draw_wheel sel ~delta_y ~x ~y r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_draw_handler_by_path path r.draw_handlers
    |> Option.to_result ~none:(No_handler { tag; event = "wheel" })
  in
  match handler.on_wheel with
  | None -> Error (No_handler { tag; event = "wheel" })
  | Some f ->
      r.msgs := f { Nopal_element.Element.delta_y; x; y } :: !(r.msgs);
      Ok ()

let find_box_handler_by_path path box_handlers =
  List.find_opt (fun h -> h.box_path = path) box_handlers

let box_pointer_move sel ~x ~y r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_box_handler_by_path path r.box_handlers
    |> Option.to_result ~none:(No_handler { tag; event = "pointer_move" })
  in
  match handler.on_pointer_move with
  | None -> Error (No_handler { tag; event = "pointer_move" })
  | Some f ->
      r.msgs :=
        f { Nopal_element.Element.x; y; client_x = x; client_y = y }
        :: !(r.msgs);
      Ok ()

let box_pointer_leave sel r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_box_handler_by_path path r.box_handlers
    |> Option.to_result ~none:(No_handler { tag; event = "pointer_leave" })
  in
  match handler.on_pointer_leave with
  | None -> Error (No_handler { tag; event = "pointer_leave" })
  | Some msg ->
      r.msgs := msg :: !(r.msgs);
      Ok ()

let box_pointer_down sel ~x ~y r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_box_handler_by_path path r.box_handlers
    |> Option.to_result ~none:(No_handler { tag; event = "pointer_down" })
  in
  match handler.on_pointer_down with
  | None -> Error (No_handler { tag; event = "pointer_down" })
  | Some f ->
      r.msgs :=
        f { Nopal_element.Element.x; y; client_x = x; client_y = y }
        :: !(r.msgs);
      Ok ()

let box_pointer_up sel ~x ~y r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_box_handler_by_path path r.box_handlers
    |> Option.to_result ~none:(No_handler { tag; event = "pointer_up" })
  in
  match handler.on_pointer_up with
  | None -> Error (No_handler { tag; event = "pointer_up" })
  | Some f ->
      r.msgs :=
        f { Nopal_element.Element.x; y; client_x = x; client_y = y }
        :: !(r.msgs);
      Ok ()

let box_wheel sel ~delta_y ~x ~y r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_box_handler_by_path path r.box_handlers
    |> Option.to_result ~none:(No_handler { tag; event = "wheel" })
  in
  match handler.on_wheel with
  | None -> Error (No_handler { tag; event = "wheel" })
  | Some f ->
      r.msgs := f { Nopal_element.Element.delta_y; x; y } :: !(r.msgs);
      Ok ()

let run_app ~init ~update ~view ?(viewport = Nopal_element.Viewport.desktop)
    msgs =
  let model, _cmd = init () in
  let final_model =
    List.fold_left
      (fun m msg ->
        let m', _cmd = update m msg in
        m')
      model msgs
  in
  (final_model, render (view viewport final_model))

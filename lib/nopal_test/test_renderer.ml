type node =
  | Empty
  | Text of { content : string; text_style : Nopal_style.Text.t option }
  | Element of {
      tag : string;
      style : Nopal_style.Style.t;
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
  on_focus : 'msg option;
  on_blur : 'msg option;
  on_keydown : (string -> 'msg option) option;
  on_toggle : (bool -> 'msg) option;
  on_files : (Nopal_element.Element.file_info list -> 'msg) option;
  (* The [on_submit] of the nearest enclosing form, which an Enter nothing on
     the node answered goes on to. Only an input carries one: it is the one
     element the submit contract routes a keydown for, so every other entry
     answers [None] whether or not a form encloses it. [None] too when no form
     encloses the input, or when the nearest one authors no [on_submit] — both
     dispatch nothing. *)
  enclosing_form_submit : 'msg option;
}

(* A form's own submission, kept apart from [handler_entry] so that [submit],
   which pokes a node's [on_submit] there, cannot reach a form's, and
   [submit_form] reaches nothing else. *)
type 'msg form_handler_entry = {
  form_path : int list;
  form_on_submit : 'msg option;
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
  on_focus : 'msg option;
  on_blur : 'msg option;
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
     in multi-step interaction tests *)
  handlers : 'msg handler_entry list;
  form_handlers : 'msg form_handler_entry list;
  draw_handlers : 'msg draw_handler_entry list;
  box_handlers : 'msg box_handler_entry list;
}

(* A pair derived from a typed field is an overlay over the view's own [attrs]
   list, not a replacement for it: it is appended, so a lookup — which resolves
   a duplicate key to the last pair — answers with the derivation wherever the
   two collide, and with the view's own pair everywhere else.

   A derivation asserts a value and never denies one. For the keys the web
   renderer spells as real DOM attributes and whose absence it spells as
   removal — ["disabled"], ["accept"], ["capture"], ["multiple"], an input's
   ["required"], ["aria-required"], ["autocomplete"] and ["type"], and a form's
   ["autocomplete"] and ["novalidate"] — a typed field that declines
   contributes no pair at all, so whatever [attrs] declared for that name is
   uncovered rather than erased and the two renderers cannot disagree about who
   won. [derived_flag] is the boolean spelling of the same rule and also
   carries ["focusable"], whose conditional shape predates it.

   Each arm builds its overlay once and appends it once. *)
let derived_pair name value =
  match value with
  | None -> []
  | Some v -> [ (name, v) ]

let derived_flag name flag =
  match flag with
  | true -> [ (name, "true") ]
  | false -> []

let render (element : 'msg Nopal_element.Element.t) : 'msg rendered =
  let handlers = ref [] in
  let form_handlers = ref [] in
  let draw_handlers = ref [] in
  let box_handlers = ref [] in
  let rec go ~form_submit rev_path (el : 'msg Nopal_element.Element.t) : node =
    match el with
    | Empty -> Empty
    | Text { content; text_style } -> Text { content; text_style }
    | Box
        {
          style;
          interaction;
          attrs;
          children;
          focusable;
          on_focus;
          on_blur;
          on_pointer_move;
          on_pointer_leave;
          on_pointer_down;
          on_pointer_up;
          on_wheel;
        } ->
        let has_handler =
          Option.is_some on_focus
          || Option.is_some on_blur
          || Option.is_some on_pointer_move
          || Option.is_some on_pointer_leave
          || Option.is_some on_pointer_down
          || Option.is_some on_pointer_up
          || Option.is_some on_wheel
        in
        if has_handler then
          box_handlers :=
            {
              box_path = List.rev rev_path;
              on_focus;
              on_blur;
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
            style;
            (* A container's focusability is surfaced for inspection, so a
               structural test can read back that a view asked for a tab stop.
               The DSL says only that the container is focusable; how a platform
               spells a tab stop is that platform's business, so the derived
               pair carries the DSL's own word and no backend's attribute name.
               The pair is appended to the view's own attributes so it wins
               lookup over a caller-supplied key of the same name, the same
               shape [Scroll]'s [reveal] and the input arms use. A container
               that is not focusable carries no pair at all, so every tree that
               rendered before this arm reads back unchanged. Only the flag is
               surfaced: this renderer fires the selected node's own handler and
               models no propagation, so the subtree scoping of a container's
               focus edges is not observable here at all. *)
            attrs = attrs @ derived_flag "focusable" focusable;
            children = go_children ~form_submit rev_path children;
            interaction;
          }
    | Row { style; interaction; attrs; children } ->
        Element
          {
            tag = "row";
            style;
            attrs;
            children = go_children ~form_submit rev_path children;
            interaction;
          }
    | Column { style; interaction; attrs; children } ->
        Element
          {
            tag = "column";
            style;
            attrs;
            children = go_children ~form_submit rev_path children;
            interaction;
          }
    | Form
        {
          style;
          interaction;
          attrs;
          children;
          on_submit;
          autocomplete;
          novalidate;
        } ->
        (* Every form is registered with the [on_submit] it authored, [None]
           included; [submit_form] answers a [None] with [No_handler], as it
           answers a node that is no form at all. *)
        form_handlers :=
          { form_path = List.rev rev_path; form_on_submit = on_submit }
          :: !form_handlers;
        (* The two derivations are spelled by absence as the web renderer
           spells them: [autocomplete] only when authored, [novalidate] only
           when [true], so a form that says nothing about either uncovers
           whatever [attrs] declared under that key. [novalidate] carries
           ["true"] here where the DOM carries a presence attribute, the same
           split [disabled] has. *)
        let form_config =
          derived_pair "autocomplete"
            (Option.map Nopal_element.Element.autocomplete_mode_to_string
               autocomplete)
          @ derived_flag "novalidate" novalidate
        in
        Element
          {
            tag = "form";
            style;
            attrs = attrs @ form_config;
            (* This form is now the nearest enclosing one for everything below
               it, so its [on_submit] — [None] included — replaces any outer
               form's. Forms do not nest, so an outer one exists only in a view
               that broke that rule. *)
            children = go_children ~form_submit:on_submit rev_path children;
            interaction;
          }
    | Button { style; interaction; attrs; on_click; on_dblclick; child } ->
        handlers :=
          {
            path = List.rev rev_path;
            on_click;
            on_dblclick;
            on_change = None;
            on_submit = None;
            on_focus = None;
            on_blur = None;
            on_keydown = None;
            on_toggle = None;
            on_files = None;
            enclosing_form_submit = None;
          }
          :: !handlers;
        Element
          {
            tag = "button";
            style;
            attrs;
            children = [ go ~form_submit (0 :: rev_path) child ];
            interaction;
          }
    | Input
        {
          style;
          interaction;
          attrs;
          value;
          placeholder;
          on_change;
          on_submit;
          on_focus;
          on_blur;
          on_keydown;
          required;
          autocomplete;
          input_type;
        } ->
        handlers :=
          {
            path = List.rev rev_path;
            on_click = None;
            on_dblclick = None;
            on_change;
            on_submit;
            on_focus;
            on_blur;
            on_keydown;
            on_toggle = None;
            on_files = None;
            enclosing_form_submit = form_submit;
          }
          :: !handlers;
        (* The three typed fields are spelled by absence as the web renderer
           spells them: [required] only when [true], carrying ["aria-required"]
           with it; [autocomplete] and [input_type] only when authored. A field
           that says nothing uncovers whatever [attrs] declared under its key.
           [required] carries ["true"] here where the DOM carries a presence
           attribute, the same split [disabled] has. *)
        let input_config =
          derived_flag "required" required
          @ derived_flag "aria-required" required
          @ derived_pair "autocomplete" autocomplete
          @ derived_pair "type"
              (Option.map Nopal_element.Element.input_type_to_string input_type)
        in
        Element
          {
            tag = "input";
            style;
            attrs =
              attrs
              @ ("value", value)
                :: ("placeholder", placeholder)
                :: input_config;
            children = [];
            interaction;
          }
    | Checkbox { style; interaction; attrs; checked; disabled; on_toggle } ->
        if not disabled then
          handlers :=
            {
              path = List.rev rev_path;
              on_click = None;
              on_dblclick = None;
              on_change = None;
              on_submit = None;
              on_focus = None;
              on_blur = None;
              on_keydown = None;
              on_toggle;
              on_files = None;
              enclosing_form_submit = None;
            }
            :: !handlers;
        Element
          {
            tag = "checkbox";
            style;
            attrs =
              attrs
              @ ("checked", string_of_bool checked)
                :: derived_flag "disabled" disabled;
            children = [];
            interaction;
          }
    | Radio { style; interaction; attrs; name; checked; disabled; on_select } ->
        if not disabled then
          handlers :=
            {
              path = List.rev rev_path;
              on_click = on_select;
              on_dblclick = None;
              on_change = None;
              on_submit = None;
              on_focus = None;
              on_blur = None;
              on_keydown = None;
              on_toggle = None;
              on_files = None;
              enclosing_form_submit = None;
            }
            :: !handlers;
        Element
          {
            tag = "radio";
            style;
            attrs =
              attrs
              @ ("name", name)
                :: ("checked", string_of_bool checked)
                :: derived_flag "disabled" disabled;
            children = [];
            interaction;
          }
    | Select
        { style; interaction; attrs; options; selected; disabled; on_change } ->
        if not disabled then
          handlers :=
            {
              path = List.rev rev_path;
              on_click = None;
              on_dblclick = None;
              on_change;
              on_submit = None;
              on_focus = None;
              on_blur = None;
              on_keydown = None;
              on_toggle = None;
              on_files = None;
              enclosing_form_submit = None;
            }
            :: !handlers;
        let option_children =
          List.map
            (fun (opt : Nopal_element.Element.select_option) ->
              Element
                {
                  tag = "option";
                  style = Nopal_style.Style.default;
                  attrs =
                    [ ("value", opt.value); ("label", opt.label) ]
                    @ derived_flag "disabled" opt.disabled;
                  children = [];
                  interaction = Nopal_style.Interaction.default;
                })
            options
        in
        Element
          {
            tag = "select";
            style;
            attrs =
              attrs
              @ (("selected", selected) :: derived_flag "disabled" disabled);
            children = option_children;
            interaction;
          }
    | File_input
        { style; interaction; attrs; accept; capture; multiple; on_change } ->
        handlers :=
          {
            path = List.rev rev_path;
            on_click = None;
            on_dblclick = None;
            on_change = None;
            on_submit = None;
            on_focus = None;
            on_blur = None;
            on_keydown = None;
            on_toggle = None;
            on_files = on_change;
            enclosing_form_submit = None;
          }
          :: !handlers;
        (* Picker configuration is surfaced as node attributes, appended so it
           wins lookup over a caller-supplied key of the same name — the same
           shape as [Input], [Checkbox], [Radio] and [Select]. [accept] is the
           comma-joined form the DOM carries. All three fields have an absent
           form, and each contributes no pair in it, exactly as the web renderer
           writes no such DOM attribute; a view that spelled one through [attrs]
           keeps it for as long as the typed field declines to speak. *)
        let picker_config =
          derived_pair "accept"
            (match accept with
            | [] -> None
            | _ :: _ -> Some (String.concat "," accept))
          @ derived_pair "capture"
              (match capture with
              | None -> None
              | Some c -> Some (Nopal_element.Element.capture_to_string c))
          @ derived_flag "multiple" multiple
        in
        Element
          {
            tag = "file_input";
            style;
            attrs = attrs @ picker_config;
            children = [];
            interaction;
          }
    | Image { style; src; alt } ->
        Element
          {
            tag = "image";
            style;
            attrs = [ ("src", src); ("alt", alt) ];
            children = [];
            interaction = Nopal_style.Interaction.default;
          }
    | Scroll { style; attrs; reveal; child } ->
        Element
          {
            tag = "scroll";
            style;
            (* A reveal request is surfaced for inspection, so a structural test
               can read back which child a view asked to bring into view and
               under which alignment. The key is carried exactly as the view
               wrote it — escaping belongs to whichever backend builds a query
               out of it, and a value escaped here would be escaped twice there
               and resolve to nothing. The derived pair is appended to the
               view's own attributes so it wins lookup over a caller-supplied
               key of the same name, the same shape [Input], [Checkbox],
               [Radio], [Select] and [File_input] use. A container that
               declares neither carries no attributes at all, so every tree
               that renders today reads back unchanged. *)
            attrs =
              (attrs
              @
              match reveal with
              | None -> []
              | Some { Nopal_element.Reveal.key; align } ->
                  [
                    ("reveal", key);
                    ("reveal-align", Nopal_element.Reveal.align_token align);
                  ]);
            children = [ go ~form_submit (0 :: rev_path) child ];
            interaction = Nopal_style.Interaction.default;
          }
    | Keyed { key; child } ->
        Element
          {
            tag = "keyed";
            style = Nopal_style.Style.default;
            attrs = [ ("key", key) ];
            children = [ go ~form_submit (0 :: rev_path) child ];
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
            style = Nopal_style.Style.default;
            attrs =
              [
                ("width", string_of_float width);
                ("height", string_of_float height);
                ("scene-nodes", string_of_int (List.length scene));
              ];
            children = [];
            interaction = Nopal_style.Interaction.default;
          }
    | Virtual_list
        {
          style;
          item_count;
          row_height;
          container_height;
          scroll_state;
          overscan;
          render_item;
          on_scroll;
        } ->
        let range =
          Nopal_element.Virtual_list.visible_range ~scroll_state ~row_height
            ~container_height ~item_count ~overscan
        in
        let has_on_scroll = Option.is_some on_scroll in
        if has_on_scroll then
          handlers :=
            {
              path = List.rev rev_path;
              on_click = None;
              on_dblclick = None;
              on_change = None;
              on_submit = None;
              on_focus = None;
              on_blur = None;
              on_keydown = None;
              on_toggle = None;
              on_files = None;
              enclosing_form_submit = None;
            }
            :: !handlers;
        let children =
          if range.first > range.last then []
          else
            (* Register item handlers through the same positional [go_children]
               walk that [resolve_path] mirrors. [render_item] still receives the
               absolute item index, but the path component is the positional slot
               within the visible window, so registration and resolution cannot
               disagree at a nonzero scroll offset. *)
            go_children ~form_submit rev_path
              (List.init
                 (range.last - range.first + 1)
                 (fun i -> render_item (range.first + i)))
        in
        let ic = Nopal_element.Virtual_list.Natural.to_int item_count in
        let rh =
          Nopal_element.Virtual_list.Positive_float.to_float row_height
        in
        let off = Nopal_element.Virtual_list.offset scroll_state in
        Element
          {
            tag = "virtual_list";
            style;
            attrs =
              [
                ("item-count", string_of_int ic);
                ("row-height", string_of_int (Float.to_int rh));
                ("offset", string_of_int (Float.to_int off));
              ];
            children;
            interaction = Nopal_style.Interaction.default;
          }
  and go_children ~form_submit rev_path children =
    List.mapi (fun i c -> go ~form_submit (i :: rev_path) c) children
  in
  let tree = go ~form_submit:None [] element in
  {
    tree;
    msgs = ref [];
    handlers = !handlers;
    form_handlers = !form_handlers;
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

(* Within an attribute list a duplicate key resolves to the LAST pair, which is
   what a browser does with repeated writes of the same attribute name. Every
   point below that answers a question about an attribute goes through these
   two, so reading a value back, selecting a node by one and dispatching an
   event at one cannot disagree. The fold itself is
   [Nopal_element.Attrs.resolve] — one definition, called from both renderers,
   so the lookup stays total and there is nothing for the two to drift apart
   from on a repeated key. *)
let resolved_attr = Nopal_element.Attrs.resolve

let attr_resolves_to attrs ~name ~value =
  match resolved_attr name attrs with
  | Some resolved -> String.equal resolved value
  | None -> false

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
          if attr_resolves_to attrs ~name ~value then Some node
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
              if attr_resolves_to attrs ~name ~value then n :: acc else acc
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

let style node =
  match node with
  | Element { style; _ } -> Some style
  | Empty
  | Text _ ->
      None

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
  | Element { attrs; _ } -> resolved_attr name attrs
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
            if attr_resolves_to attrs ~name ~value then
              Some (List.rev rev_path, n)
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

let select_files sel files r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_handler_by_path path r.handlers
    |> Option.to_result ~none:(No_handler { tag; event = "change" })
  in
  match handler.on_files with
  | None -> Error (No_handler { tag; event = "change" })
  | Some f ->
      r.msgs := f files :: !(r.msgs);
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

let find_form_handler_by_path path form_handlers =
  List.find_opt (fun h -> h.form_path = path) form_handlers

let submit_form sel r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_form_handler_by_path path r.form_handlers
    |> Option.to_result ~none:(No_handler { tag; event = "submit" })
  in
  match handler.form_on_submit with
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

let focus sel r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_handler_by_path path r.handlers
    |> Option.to_result ~none:(No_handler { tag; event = "focus" })
  in
  match handler.on_focus with
  | None -> Error (No_handler { tag; event = "focus" })
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
  (* The route is [Submit_route]'s, the definition the web renderer answers
     from too, so an Enter [on_keydown] declines reaches [on_submit] here as it
     does there, and an Enter neither answers reaches the nearest enclosing
     form's [on_submit], recorded on the entry at render time. With none of the
     three there is nothing a keydown can reach. This renderer models no
     platform default action, so [prevent_default] has nothing here to
     suppress. *)
  match
    (handler.on_keydown, handler.on_submit, handler.enclosing_form_submit)
  with
  | None, None, None -> Error (No_handler { tag; event = "keydown" })
  | Some _, _, _
  | None, Some _, _
  | None, None, Some _ -> (
      match
        Nopal_element.Submit_route.of_key ~key ~on_keydown:handler.on_keydown
          ~on_submit:handler.on_submit
      with
      | Dispatch { msg; prevent_default = _ } ->
          r.msgs := msg :: !(r.msgs);
          Ok ()
      | To_enclosing_form -> (
          match handler.enclosing_form_submit with
          | Some msg ->
              r.msgs := msg :: !(r.msgs);
              Ok ()
          | None -> Ok ())
      | Nothing -> Ok ())

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

let box_focus sel r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_box_handler_by_path path r.box_handlers
    |> Option.to_result ~none:(No_handler { tag; event = "focus" })
  in
  match handler.on_focus with
  | None -> Error (No_handler { tag; event = "focus" })
  | Some msg ->
      r.msgs := msg :: !(r.msgs);
      Ok ()

let box_blur sel r =
  let* path, found =
    resolve_path sel r.tree |> Option.to_result ~none:(Not_found sel)
  in
  let tag = tag_of_node found in
  let* handler =
    find_box_handler_by_path path r.box_handlers
    |> Option.to_result ~none:(No_handler { tag; event = "blur" })
  in
  match handler.on_blur with
  | None -> Error (No_handler { tag; event = "blur" })
  | Some msg ->
      r.msgs := msg :: !(r.msgs);
      Ok ()

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

let run_app_with_cmds ~init ~update ~view
    ?(viewport = Nopal_element.Viewport.desktop) msgs =
  let model, init_cmd = init () in
  let final_model, cmds =
    List.fold_left
      (fun (m, acc_cmds) msg ->
        let m', cmd = update m msg in
        (m', cmd :: acc_cmds))
      (model, [ init_cmd ]) msgs
  in
  (final_model, render (view viewport final_model), List.rev cmds)

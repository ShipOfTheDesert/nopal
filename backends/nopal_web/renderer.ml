open Nopal_element.Element

type 'msg live_node = {
  dom : Brr.El.t;
  mutable element : 'msg Nopal_element.Element.t;
  (* mutable: updated on reconciliation to reflect the current element
     for variant comparison on subsequent updates *)
  mutable children : 'msg live list;
  (* mutable: children list changes on reconciliation when DOM
     children are added, removed, or reordered *)
  mutable listeners : Brr.Ev.listener list;
      (* mutable: event listeners are detached and reattached on
     reconciliation when handlers change *)
  mutable base_id : Style_sheet.base_id option;
      (* mutable: base style class for interactive elements, injected/removed
     during reconciliation when style or interactivity changes *)
  mutable interaction_id : Style_sheet.interaction_id option;
      (* mutable: interaction style class is injected/removed during
     reconciliation when the element's interaction changes *)
}

and 'msg live_comment = {
  comment : Jv.t;
      (* DOM comment node — Brr has no comment type, so we use raw Jv.t *)
}

and 'msg live_text = {
  text_dom : Brr.El.t;
  mutable text : string;
      (* mutable: text content is updated in place on reconciliation *)
  mutable text_style : Nopal_style.Text.t option;
      (* mutable: text style is updated on reconciliation when the element's
         text_style changes *)
  mutable text_css_props : Style_css.css_prop list;
      (* mutable: tracks the CSS properties currently applied to the span,
         so reconciliation can clear exactly the right properties without
         maintaining a hardcoded list *)
}

and 'msg live =
  | Live_node of 'msg live_node
  | Live_comment of 'msg live_comment
  | Live_text of 'msg live_text

type 'msg t = {
  mutable root : 'msg live;
  (* mutable: root is replaced on reconciliation when element variant changes *)
  parent : Brr.El.t;
  sheet : Style_sheet.t;
}

let doc () = Jv.get Jv.global "document"

let jv_of_live = function
  | Live_node n -> Brr.El.to_jv n.dom
  | Live_comment c -> c.comment
  | Live_text t -> Brr.El.to_jv t.text_dom

let dom_node handle = jv_of_live handle.root

let apply_style el (style : Nopal_style.Style.t) =
  let props = Style_css.of_style style in
  List.iter
    (fun { Style_css.property; value } ->
      Brr.El.set_inline_style (Jstr.v property) (Jstr.v value) el)
    props

let apply_text_style el text_style =
  match text_style with
  | Some ts ->
      let props = Style_css.of_text ts in
      List.iter
        (fun { Style_css.property; value } ->
          Brr.El.set_inline_style (Jstr.v property) (Jstr.v value) el)
        props;
      props
  | None -> []

let apply_container_base_style el =
  Brr.El.set_inline_style (Jstr.v "display") (Jstr.v "flex") el

(* Element.t has no Map constructor — the runtime resolves mapped subtrees
   before they reach the renderer. This match is exhaustive over all
   concrete element variants. *)
let interaction_of (el : 'msg Nopal_element.Element.t) =
  match el with
  | Box { interaction; _ }
  | Row { interaction; _ }
  | Column { interaction; _ }
  | Button { interaction; _ }
  | Input { interaction; _ } ->
      Some interaction
  | Empty
  | Text _
  | Image _
  | Scroll _
  | Keyed _
  | Draw _ ->
      None

let add_class el class_name =
  let cl = Jv.get (Brr.El.to_jv el) "classList" in
  ignore (Jv.call cl "add" [| Jv.of_string class_name |])

let remove_class el class_name =
  let cl = Jv.get (Brr.El.to_jv el) "classList" in
  ignore (Jv.call cl "remove" [| Jv.of_string class_name |])

let inject_base_class sheet el css_props =
  let bid = Style_sheet.inject_base sheet ~css_props in
  add_class el (Style_sheet.base_class_name bid);
  Some bid

let inject_interaction_class sheet el interaction =
  if Nopal_style.Interaction.has_any interaction then
    match Style_sheet.inject_interaction sheet ~interaction with
    | Ok iid ->
        add_class el (Style_sheet.interaction_class_name iid);
        Some iid
    | Error _ ->
        (* Unreachable: the outer has_any guard ensures inject always
           succeeds. Kept for exhaustive result handling. *)
        None
  else None

let apply_styles_for_element ~sheet el (style : Nopal_style.Style.t)
    (interaction : Nopal_style.Interaction.t) =
  if Nopal_style.Interaction.has_any interaction then begin
    let css_props = Style_css.of_style style in
    let bid =
      match css_props with
      | [] -> None
      | _ -> inject_base_class sheet el css_props
    in
    let iid = inject_interaction_class sheet el interaction in
    (bid, iid)
  end
  else begin
    apply_style el style;
    (None, None)
  end

let wire_click ~dispatch el on_click =
  match on_click with
  | None -> []
  | Some msg ->
      let listener =
        Brr.Ev.listen Brr.Ev.click
          (fun _ev -> dispatch msg)
          (Brr.El.as_target el)
      in
      [ listener ]

let wire_dblclick ~dispatch el on_dblclick =
  match on_dblclick with
  | None -> []
  | Some msg ->
      let listener =
        Brr.Ev.listen Brr.Ev.dblclick
          (fun _ev -> dispatch msg)
          (Brr.El.as_target el)
      in
      [ listener ]

let wire_input_events ~dispatch el on_change on_submit on_blur on_keydown =
  let change_l =
    match on_change with
    | None -> []
    | Some f ->
        [
          Brr.Ev.listen Brr.Ev.input
            (fun _ev ->
              let value =
                Jv.Jstr.get (Brr.El.to_jv el) "value" |> Jstr.to_string
              in
              dispatch (f value))
            (Brr.El.as_target el);
        ]
  in
  let submit_l =
    match (on_submit, on_keydown) with
    | None, _
    | _, Some _ ->
        (* When on_keydown is present it receives all key events including
           Enter, so we skip the on_submit keydown listener to avoid
           double-dispatch. Handle Enter in the on_keydown handler instead. *)
        []
    | Some msg, None ->
        [
          Brr.Ev.listen Brr.Ev.keydown
            (fun ev ->
              let key = Jv.Jstr.get (Brr.Ev.to_jv ev) "key" |> Jstr.to_string in
              if String.equal key "Enter" then dispatch msg)
            (Brr.El.as_target el);
        ]
  in
  let blur_l =
    match on_blur with
    | None -> []
    | Some msg ->
        [
          Brr.Ev.listen Brr.Ev.blur
            (fun _ev -> dispatch msg)
            (Brr.El.as_target el);
        ]
  in
  let keydown_l =
    match on_keydown with
    | None -> []
    | Some f ->
        [
          Brr.Ev.listen Brr.Ev.keydown
            (fun ev ->
              let key = Jv.Jstr.get (Brr.Ev.to_jv ev) "key" |> Jstr.to_string in
              match f key with
              | None -> ()
              | Some msg -> dispatch msg)
            (Brr.El.as_target el);
        ]
  in
  change_l @ submit_l @ blur_l @ keydown_l

let pointer_event_of_mouse ev el =
  let rect = Jv.call (Brr.El.to_jv el) "getBoundingClientRect" [||] in
  let client_x = Jv.Float.get (Brr.Ev.to_jv ev) "clientX" in
  let client_y = Jv.Float.get (Brr.Ev.to_jv ev) "clientY" in
  let rect_left = Jv.Float.get rect "left" in
  let rect_top = Jv.Float.get rect "top" in
  Nopal_element.Element.
    { x = client_x -. rect_left; y = client_y -. rect_top; client_x; client_y }

let wire_draw_pointer_events ~dispatch el on_pointer_move on_click
    on_pointer_leave on_pointer_down on_pointer_up on_wheel =
  let move_l =
    match on_pointer_move with
    | None -> []
    | Some f ->
        [
          Brr.Ev.listen Brr.Ev.pointermove
            (fun ev ->
              let pe = pointer_event_of_mouse ev el in
              dispatch (f pe))
            (Brr.El.as_target el);
        ]
  in
  let click_l =
    match on_click with
    | None -> []
    | Some f ->
        [
          Brr.Ev.listen Brr.Ev.click
            (fun ev ->
              let pe = pointer_event_of_mouse ev el in
              dispatch (f pe))
            (Brr.El.as_target el);
        ]
  in
  let leave_l =
    match on_pointer_leave with
    | None -> []
    | Some msg ->
        [
          Brr.Ev.listen Brr.Ev.pointerleave
            (fun _ev -> dispatch msg)
            (Brr.El.as_target el);
        ]
  in
  let down_l =
    match on_pointer_down with
    | None -> []
    | Some f ->
        [
          Brr.Ev.listen Brr.Ev.pointerdown
            (fun ev ->
              let pe = pointer_event_of_mouse ev el in
              dispatch (f pe))
            (Brr.El.as_target el);
        ]
  in
  let up_l =
    match on_pointer_up with
    | None -> []
    | Some f ->
        [
          Brr.Ev.listen Brr.Ev.pointerup
            (fun ev ->
              let pe = pointer_event_of_mouse ev el in
              dispatch (f pe))
            (Brr.El.as_target el);
        ]
  in
  let wheel_l =
    match on_wheel with
    | None -> []
    | Some f ->
        [
          Brr.Ev.listen Brr.Ev.wheel
            (fun ev ->
              Brr.Ev.prevent_default ev;
              let rect =
                Jv.call (Brr.El.to_jv el) "getBoundingClientRect" [||]
              in
              let client_x = Jv.Float.get (Brr.Ev.to_jv ev) "clientX" in
              let client_y = Jv.Float.get (Brr.Ev.to_jv ev) "clientY" in
              let rect_left = Jv.Float.get rect "left" in
              let rect_top = Jv.Float.get rect "top" in
              let delta_y = Jv.Float.get (Brr.Ev.to_jv ev) "deltaY" in
              let we =
                Nopal_element.Element.
                  {
                    delta_y;
                    x = client_x -. rect_left;
                    y = client_y -. rect_top;
                  }
              in
              dispatch (f we))
            (Brr.El.as_target el);
        ]
  in
  move_l @ click_l @ leave_l @ down_l @ up_l @ wheel_l

let wire_box_pointer_events ~dispatch el on_pointer_move on_pointer_leave
    on_pointer_down on_pointer_up on_wheel =
  let move_l =
    match on_pointer_move with
    | None -> []
    | Some f ->
        [
          Brr.Ev.listen Brr.Ev.pointermove
            (fun ev ->
              let pe = pointer_event_of_mouse ev el in
              dispatch (f pe))
            (Brr.El.as_target el);
        ]
  in
  let leave_l =
    match on_pointer_leave with
    | None -> []
    | Some msg ->
        [
          Brr.Ev.listen Brr.Ev.pointerleave
            (fun _ev -> dispatch msg)
            (Brr.El.as_target el);
        ]
  in
  let down_l =
    match on_pointer_down with
    | None -> []
    | Some f ->
        [
          Brr.Ev.listen Brr.Ev.pointerdown
            (fun ev ->
              let pe = pointer_event_of_mouse ev el in
              dispatch (f pe))
            (Brr.El.as_target el);
        ]
  in
  let up_l =
    match on_pointer_up with
    | None -> []
    | Some f ->
        [
          Brr.Ev.listen Brr.Ev.pointerup
            (fun ev ->
              let pe = pointer_event_of_mouse ev el in
              dispatch (f pe))
            (Brr.El.as_target el);
        ]
  in
  let wheel_l =
    match on_wheel with
    | None -> []
    | Some f ->
        [
          Brr.Ev.listen Brr.Ev.wheel
            (fun ev ->
              Brr.Ev.prevent_default ev;
              let rect =
                Jv.call (Brr.El.to_jv el) "getBoundingClientRect" [||]
              in
              let client_x = Jv.Float.get (Brr.Ev.to_jv ev) "clientX" in
              let client_y = Jv.Float.get (Brr.Ev.to_jv ev) "clientY" in
              let rect_left = Jv.Float.get rect "left" in
              let rect_top = Jv.Float.get rect "top" in
              let delta_y = Jv.Float.get (Brr.Ev.to_jv ev) "deltaY" in
              let we =
                Nopal_element.Element.
                  {
                    delta_y;
                    x = client_x -. rect_left;
                    y = client_y -. rect_top;
                  }
              in
              dispatch (f we))
            (Brr.El.as_target el);
        ]
  in
  move_l @ leave_l @ down_l @ up_l @ wheel_l

let rec create_live ~sheet ~dispatch (element : 'msg Nopal_element.Element.t) :
    'msg live =
  match element with
  | Empty ->
      let comment =
        Jv.call (doc ()) "createComment" [| Jv.of_string "empty" |]
      in
      Live_comment { comment }
  | Text { content = s; text_style } ->
      let el = Brr.El.v (Jstr.v "span") [ Brr.El.txt (Jstr.v s) ] in
      let text_css_props = apply_text_style el text_style in
      Live_text { text_dom = el; text = s; text_style; text_css_props }
  | Box
      {
        style;
        interaction;
        attrs;
        children;
        on_pointer_move;
        on_pointer_leave;
        on_pointer_down;
        on_pointer_up;
        on_wheel;
      } ->
      let el = Brr.El.v (Jstr.v "div") [] in
      apply_container_base_style el;
      (* Box must set flex-direction inline: CSS default is "row" but Nopal's
         default is Column_dir.  Row and Column already set direction inline;
         Box needs the same treatment so the style's direction is honoured
         even when the rest of the layout matches the Nopal default. *)
      let dir =
        match style.layout.direction with
        | Nopal_style.Style.Column_dir -> "column"
        | Nopal_style.Style.Row_dir -> "row"
      in
      Brr.El.set_inline_style (Jstr.v "flex-direction") (Jstr.v dir) el;
      let base_id, interaction_id =
        apply_styles_for_element ~sheet el style interaction
      in
      List.iter
        (fun (k, v) -> Brr.El.set_at (Jstr.v k) (Some (Jstr.v v)) el)
        attrs;
      let live_children =
        List.map (create_and_append ~sheet ~dispatch el) children
      in
      let listeners =
        wire_box_pointer_events ~dispatch el on_pointer_move on_pointer_leave
          on_pointer_down on_pointer_up on_wheel
      in
      Live_node
        {
          dom = el;
          element;
          children = live_children;
          listeners;
          base_id;
          interaction_id;
        }
  | Row { style; interaction; attrs; children } ->
      let el = Brr.El.v (Jstr.v "div") [] in
      apply_container_base_style el;
      Brr.El.set_inline_style (Jstr.v "flex-direction") (Jstr.v "row") el;
      let base_id, interaction_id =
        apply_styles_for_element ~sheet el style interaction
      in
      List.iter
        (fun (k, v) -> Brr.El.set_at (Jstr.v k) (Some (Jstr.v v)) el)
        attrs;
      let live_children =
        List.map (create_and_append ~sheet ~dispatch el) children
      in
      Live_node
        {
          dom = el;
          element;
          children = live_children;
          listeners = [];
          base_id;
          interaction_id;
        }
  | Column { style; interaction; attrs; children } ->
      let el = Brr.El.v (Jstr.v "div") [] in
      apply_container_base_style el;
      Brr.El.set_inline_style (Jstr.v "flex-direction") (Jstr.v "column") el;
      let base_id, interaction_id =
        apply_styles_for_element ~sheet el style interaction
      in
      List.iter
        (fun (k, v) -> Brr.El.set_at (Jstr.v k) (Some (Jstr.v v)) el)
        attrs;
      let live_children =
        List.map (create_and_append ~sheet ~dispatch el) children
      in
      Live_node
        {
          dom = el;
          element;
          children = live_children;
          listeners = [];
          base_id;
          interaction_id;
        }
  | Button { style; interaction; attrs; on_click; on_dblclick; child } ->
      let el = Brr.El.v (Jstr.v "button") [] in
      let base_id, interaction_id =
        apply_styles_for_element ~sheet el style interaction
      in
      List.iter
        (fun (k, v) -> Brr.El.set_at (Jstr.v k) (Some (Jstr.v v)) el)
        attrs;
      let live_child = create_and_append ~sheet ~dispatch el child in
      let listeners =
        wire_click ~dispatch el on_click
        @ wire_dblclick ~dispatch el on_dblclick
      in
      Live_node
        {
          dom = el;
          element;
          children = [ live_child ];
          listeners;
          base_id;
          interaction_id;
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
        on_blur;
        on_keydown;
      } ->
      let el = Brr.El.v (Jstr.v "input") [] in
      let base_id, interaction_id =
        apply_styles_for_element ~sheet el style interaction
      in
      Jv.set (Brr.El.to_jv el) "value" (Jv.of_string value);
      Brr.El.set_at (Jstr.v "placeholder") (Some (Jstr.v placeholder)) el;
      List.iter
        (fun (k, v) -> Brr.El.set_at (Jstr.v k) (Some (Jstr.v v)) el)
        attrs;
      let listeners =
        wire_input_events ~dispatch el on_change on_submit on_blur on_keydown
      in
      Live_node
        { dom = el; element; children = []; listeners; base_id; interaction_id }
  | Image { style; src; alt } ->
      let el = Brr.El.v (Jstr.v "img") [] in
      apply_style el style;
      Brr.El.set_at (Jstr.v "src") (Some (Jstr.v src)) el;
      Brr.El.set_at (Jstr.v "alt") (Some (Jstr.v alt)) el;
      Live_node
        {
          dom = el;
          element;
          children = [];
          listeners = [];
          base_id = None;
          interaction_id = None;
        }
  | Scroll { style; child } ->
      let el = Brr.El.v (Jstr.v "div") [] in
      Brr.El.set_inline_style (Jstr.v "overflow") (Jstr.v "auto") el;
      apply_style el style;
      let live_child = create_and_append ~sheet ~dispatch el child in
      Live_node
        {
          dom = el;
          element;
          children = [ live_child ];
          listeners = [];
          base_id = None;
          interaction_id = None;
        }
  | Keyed { key; child } ->
      let live_child = create_live ~sheet ~dispatch child in
      (* Set data-key on the rendered node. For comment nodes, skip
         since they don't support setAttribute. *)
      (match live_child with
      | Live_node n ->
          Brr.El.set_at (Jstr.v "data-key") (Some (Jstr.v key)) n.dom
      | Live_text t ->
          Brr.El.set_at (Jstr.v "data-key") (Some (Jstr.v key)) t.text_dom
      | Live_comment _ -> ());
      live_child
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
        cursor;
        aria_label;
      } ->
      let el = Brr.El.v (Jstr.v "canvas") [] in
      let canvas = Brr_canvas.Canvas.of_el el in
      let ctx = Brr_canvas.C2d.get_context canvas in
      Canvas_renderer.setup_hidpi el ctx ~width ~height;
      Style_css.apply_cursor el cursor;
      (match aria_label with
      | Some label ->
          Brr.El.set_at (Jstr.v "aria-label") (Some (Jstr.v label)) el
      | None -> ());
      Canvas_renderer.render ctx scene;
      let listeners =
        wire_draw_pointer_events ~dispatch el on_pointer_move on_click
          on_pointer_leave on_pointer_down on_pointer_up on_wheel
      in
      Live_node
        {
          dom = el;
          element;
          children = [];
          listeners;
          base_id = None;
          interaction_id = None;
        }

and create_and_append ~sheet ~dispatch parent
    (element : 'msg Nopal_element.Element.t) =
  let live = create_live ~sheet ~dispatch element in
  let jv = jv_of_live live in
  ignore (Jv.call (Brr.El.to_jv parent) "appendChild" [| jv |]);
  live

let create ~dispatch ~parent element =
  let sheet = Style_sheet.create () in
  let live = create_live ~sheet ~dispatch element in
  let jv = jv_of_live live in
  ignore (Jv.call (Brr.El.to_jv parent) "appendChild" [| jv |]);
  { root = live; parent; sheet }

let unlisten_all listeners = List.iter Brr.Ev.unlisten listeners

let rec unlisten_tree ~sheet live =
  match live with
  | Live_node n ->
      unlisten_all n.listeners;
      (match n.base_id with
      | Some bid ->
          Style_sheet.remove_base sheet bid;
          n.base_id <- None
      | None -> ());
      (match n.interaction_id with
      | Some iid ->
          Style_sheet.remove_interaction sheet iid;
          n.interaction_id <- None
      | None -> ());
      List.iter (unlisten_tree ~sheet) n.children
  | Live_comment _
  | Live_text _ ->
      ()

let same_variant (a : 'msg Nopal_element.Element.t)
    (b : 'msg Nopal_element.Element.t) =
  match (a, b) with
  | Empty, Empty
  | Text _, Text _
  | Box _, Box _
  | Row _, Row _
  | Column _, Column _
  | Button _, Button _
  | Input _, Input _
  | Image _, Image _
  | Scroll _, Scroll _
  | Keyed _, Keyed _
  | Draw _, Draw _ ->
      true
  | ( ( Empty | Text _ | Box _ | Row _ | Column _ | Button _ | Input _ | Image _
      | Scroll _ | Keyed _ | Draw _ ),
      _ ) ->
      false

let extract_keyed_pairs elements =
  let rec go acc = function
    | [] -> Some (List.rev acc)
    | Keyed { key; child } :: rest -> go ((key, child) :: acc) rest
    | ( Empty | Text _ | Box _ | Row _ | Column _ | Button _ | Input _ | Image _
      | Scroll _ | Draw _ )
      :: _ ->
        None
  in
  match elements with
  | [] -> None
  | _ -> go [] elements

let set_data_key live key =
  match live with
  | Live_comment _ -> ()
  | Live_node _
  | Live_text _ ->
      let jv = jv_of_live live in
      ignore
        (Jv.call jv "setAttribute"
           [| Jv.of_string "data-key"; Jv.of_string key |])

let equal_attrs a1 a2 =
  a1 == a2
  || List.equal
       (fun (k1, v1) (k2, v2) -> String.equal k1 k2 && String.equal v1 v2)
       a1 a2

let attrs_of (el : 'msg Nopal_element.Element.t) =
  match el with
  | Box { attrs; _ }
  | Row { attrs; _ }
  | Column { attrs; _ }
  | Button { attrs; _ }
  | Input { attrs; _ } ->
      attrs
  | Empty
  | Text _
  | Image _
  | Scroll _
  | Keyed _
  | Draw _ ->
      []

let maybe_apply_attrs el old_element new_element =
  let old_attrs = attrs_of old_element in
  let new_attrs = attrs_of new_element in
  if not (equal_attrs old_attrs new_attrs) then (
    (* Remove attrs present in old but absent in new *)
    List.iter
      (fun (k, _) ->
        if not (List.exists (fun (k2, _) -> String.equal k k2) new_attrs) then
          Brr.El.set_at (Jstr.v k) None el)
      old_attrs;
    (* Set new/changed attrs *)
    List.iter
      (fun (k, v) -> Brr.El.set_at (Jstr.v k) (Some (Jstr.v v)) el)
      new_attrs)

let style_of (el : 'msg Nopal_element.Element.t) =
  match el with
  | Box { style; _ }
  | Row { style; _ }
  | Column { style; _ }
  | Button { style; _ }
  | Input { style; _ }
  | Image { style; _ }
  | Scroll { style; _ } ->
      Some style
  | Empty
  | Text _
  | Keyed _
  | Draw _ ->
      None

let clear_inline_styles dom css_props =
  List.iter
    (fun { Style_css.property; _ } ->
      Brr.El.set_inline_style (Jstr.v property) (Jstr.v "") dom)
    css_props

let maybe_apply_style dom old_el new_el =
  let old_style = style_of old_el in
  let new_style = style_of new_el in
  match (old_style, new_style) with
  | Some os, Some ns when os == ns -> ()
  | _, Some ns -> apply_style dom ns
  | None, None -> ()
  | Some _, None ->
      (* Unreachable: reconcile_live only calls reconcile_node (and thus
         maybe_apply_style) when old and new are the same variant. All
         variants that carry a style always carry a style, and those that
         don't (Empty, Text, Keyed) never reach this path. *)
      ()

let rec reconcile_keyed_children ~sheet ~dispatch parent_el old_children
    new_pairs =
  let parent_jv = Brr.El.to_jv parent_el in
  let old_map = Hashtbl.create (List.length old_children) in
  List.iter (fun (key, live) -> Hashtbl.replace old_map key live) old_children;
  (* Build new list, reusing or creating *)
  let new_lives =
    List.map
      (fun (key, child) ->
        match Hashtbl.find_opt old_map key with
        | Some old_live ->
            Hashtbl.remove old_map key;
            let updated =
              reconcile_live ~sheet ~dispatch parent_el old_live child
            in
            (key, updated)
        | None ->
            let live = create_live ~sheet ~dispatch child in
            set_data_key live key;
            (key, live))
      new_pairs
  in
  (* Remove old nodes that are no longer present *)
  Hashtbl.iter
    (fun _key old_live ->
      let old_jv = jv_of_live old_live in
      ignore (Jv.call parent_jv "removeChild" [| old_jv |]);
      unlisten_tree ~sheet old_live)
    old_map;
  (* Reorder: appendChild moves existing nodes to the correct position *)
  List.iter
    (fun (_key, live) ->
      let jv = jv_of_live live in
      ignore (Jv.call parent_jv "appendChild" [| jv |]))
    new_lives;
  List.map snd new_lives

and reconcile_children ~sheet ~dispatch parent_el old_children new_elements =
  (* If all new elements are Keyed, use keyed reconciliation *)
  match extract_keyed_pairs new_elements with
  | Some keyed_pairs ->
      let get_data_key live =
        match live with
        | Live_comment _ -> None
        | Live_node _
        | Live_text _ ->
            let jv = jv_of_live live in
            let dk = Jv.call jv "getAttribute" [| Jv.of_string "data-key" |] in
            if Jv.is_null dk then None else Some (Jv.to_string dk)
      in
      let old_keyed =
        List.filter_map
          (fun old_live ->
            match get_data_key old_live with
            | Some key -> Some (key, old_live)
            | None -> None)
          old_children
      in
      reconcile_keyed_children ~sheet ~dispatch parent_el old_keyed keyed_pairs
  | None ->
      let rec go olds news acc =
        match (olds, news) with
        | [], [] -> List.rev acc
        | [], new_el :: rest_new ->
            let live = create_and_append ~sheet ~dispatch parent_el new_el in
            go [] rest_new (live :: acc)
        | old_live :: rest_old, [] ->
            let old_jv = jv_of_live old_live in
            ignore (Jv.call (Brr.El.to_jv parent_el) "removeChild" [| old_jv |]);
            unlisten_tree ~sheet old_live;
            go rest_old [] acc
        | old_live :: rest_old, new_el :: rest_new ->
            let updated =
              reconcile_live ~sheet ~dispatch parent_el old_live new_el
            in
            go rest_old rest_new (updated :: acc)
      in
      go old_children new_elements []

and reconcile_live ~sheet ~dispatch parent_el (old_live : 'msg live)
    (new_element : 'msg Nopal_element.Element.t) : 'msg live =
  match (old_live, new_element) with
  | Live_text t, Text { content = s; text_style } ->
      if not (String.equal t.text s) then begin
        Brr.El.set_children t.text_dom [ Brr.El.txt (Jstr.v s) ];
        t.text <- s
      end;
      let style_changed =
        match (t.text_style, text_style) with
        | None, None -> false
        | Some a, Some b -> not (Nopal_style.Text.equal a b)
        | Some _, None
        | None, Some _ ->
            true
      in
      if style_changed then begin
        (* Clear properties from the previous of_text result *)
        List.iter
          (fun { Style_css.property; _ } ->
            Brr.El.set_inline_style (Jstr.v property) (Jstr.v "") t.text_dom)
          t.text_css_props;
        let new_props = apply_text_style t.text_dom text_style in
        t.text_style <- text_style;
        t.text_css_props <- new_props
      end;
      Live_text t
  | Live_comment c, Empty -> Live_comment c
  | Live_node old_n, new_el when same_variant old_n.element new_el ->
      reconcile_node ~sheet ~dispatch old_n new_el;
      Live_node old_n
  | ( Live_text _,
      ( Empty | Box _ | Row _ | Column _ | Button _ | Input _ | Image _
      | Scroll _ | Keyed _ | Draw _ ) )
  | ( Live_comment _,
      ( Text _ | Box _ | Row _ | Column _ | Button _ | Input _ | Image _
      | Scroll _ | Keyed _ | Draw _ ) )
  | Live_node _, _ ->
      (* Different variant or same_variant returned false — replace *)
      let new_live = create_live ~sheet ~dispatch new_element in
      let old_jv = jv_of_live old_live in
      let new_jv = jv_of_live new_live in
      ignore
        (Jv.call (Brr.El.to_jv parent_el) "replaceChild" [| new_jv; old_jv |]);
      unlisten_tree ~sheet old_live;
      new_live

and maybe_reconcile_styles ~sheet (old_n : 'msg live_node)
    (old_el : 'msg Nopal_element.Element.t)
    (new_el : 'msg Nopal_element.Element.t) =
  let old_ix = interaction_of old_el in
  let new_ix = interaction_of new_el in
  let old_interactive =
    match old_ix with
    | Some ix -> Nopal_style.Interaction.has_any ix
    | None -> false
  in
  let new_interactive =
    match new_ix with
    | Some ix -> Nopal_style.Interaction.has_any ix
    | None -> false
  in
  match (old_interactive, new_interactive) with
  | true, true ->
      (* Both interactive: reconcile base class and interaction class *)
      let old_style = style_of old_el in
      let new_style = style_of new_el in
      let style_changed =
        match (old_style, new_style) with
        | Some os, Some ns -> not (os == ns)
        | None, None -> false
        | Some _, None
        | None, Some _ ->
            true
      in
      if style_changed then begin
        (* Remove old base class *)
        (match old_n.base_id with
        | Some bid ->
            remove_class old_n.dom (Style_sheet.base_class_name bid);
            Style_sheet.remove_base sheet bid;
            old_n.base_id <- None
        | None -> ());
        (* Inject new base class if there are style props *)
        match new_style with
        | Some ns ->
            let css_props = Style_css.of_style ns in
            old_n.base_id <-
              (match css_props with
              | [] -> None
              | _ -> inject_base_class sheet old_n.dom css_props)
        | None -> old_n.base_id <- None
      end;
      let ix_changed =
        match (old_ix, new_ix) with
        | Some a, Some b -> not (Nopal_style.Interaction.equal a b)
        | None, None -> false
        | Some _, None
        | None, Some _ ->
            true
      in
      if ix_changed then begin
        (match old_n.interaction_id with
        | Some iid ->
            remove_class old_n.dom (Style_sheet.interaction_class_name iid);
            Style_sheet.remove_interaction sheet iid
        | None -> ());
        match new_ix with
        | Some ix ->
            old_n.interaction_id <- inject_interaction_class sheet old_n.dom ix
        | None -> old_n.interaction_id <- None
      end
  | false, true -> (
      (* Transition non-interactive → interactive: clear inline styles,
         inject class-based styles *)
      let old_style = style_of old_el in
      (match old_style with
      | Some os ->
          let old_props = Style_css.of_style os in
          clear_inline_styles old_n.dom old_props
      | None -> ());
      let new_style = style_of new_el in
      (match new_style with
      | Some ns ->
          let css_props = Style_css.of_style ns in
          old_n.base_id <-
            (match css_props with
            | [] -> None
            | _ -> inject_base_class sheet old_n.dom css_props)
      | None -> old_n.base_id <- None);
      match new_ix with
      | Some ix ->
          old_n.interaction_id <- inject_interaction_class sheet old_n.dom ix
      | None -> old_n.interaction_id <- None)
  | true, false -> (
      (* Transition interactive → non-interactive: remove both classes,
         apply inline styles *)
      (match old_n.base_id with
      | Some bid ->
          remove_class old_n.dom (Style_sheet.base_class_name bid);
          Style_sheet.remove_base sheet bid;
          old_n.base_id <- None
      | None -> ());
      (match old_n.interaction_id with
      | Some iid ->
          remove_class old_n.dom (Style_sheet.interaction_class_name iid);
          Style_sheet.remove_interaction sheet iid;
          old_n.interaction_id <- None
      | None -> ());
      (* Apply inline styles for non-interactive element *)
      let new_style = style_of new_el in
      match new_style with
      | Some ns -> apply_style old_n.dom ns
      | None -> ())
  | false, false ->
      (* Both non-interactive: inline style reconciliation *)
      maybe_apply_style old_n.dom old_el new_el

and reconcile_node ~sheet ~dispatch (old_n : 'msg live_node)
    (new_el : 'msg Nopal_element.Element.t) =
  let el = old_n.dom in
  maybe_reconcile_styles ~sheet old_n old_n.element new_el;
  (match new_el with
  | Box
      {
        style;
        children;
        on_pointer_move;
        on_pointer_leave;
        on_pointer_down;
        on_pointer_up;
        on_wheel;
        _;
      } ->
      maybe_apply_attrs el old_n.element new_el;
      (* Keep inline flex-direction in sync with the style's direction. *)
      let dir =
        match style.layout.direction with
        | Nopal_style.Style.Column_dir -> "column"
        | Nopal_style.Style.Row_dir -> "row"
      in
      Brr.El.set_inline_style (Jstr.v "flex-direction") (Jstr.v dir) el;
      unlisten_all old_n.listeners;
      old_n.listeners <-
        wire_box_pointer_events ~dispatch el on_pointer_move on_pointer_leave
          on_pointer_down on_pointer_up on_wheel;
      old_n.children <-
        reconcile_children ~sheet ~dispatch el old_n.children children
  | Row { children; _ }
  | Column { children; _ } ->
      maybe_apply_attrs el old_n.element new_el;
      old_n.children <-
        reconcile_children ~sheet ~dispatch el old_n.children children
  | Button { on_click; on_dblclick; child; _ } ->
      maybe_apply_attrs el old_n.element new_el;
      unlisten_all old_n.listeners;
      old_n.listeners <-
        wire_click ~dispatch el on_click
        @ wire_dblclick ~dispatch el on_dblclick;
      old_n.children <-
        reconcile_children ~sheet ~dispatch el old_n.children [ child ]
  | Input { value; placeholder; on_change; on_submit; on_blur; on_keydown; _ }
    ->
      Jv.set (Brr.El.to_jv el) "value" (Jv.of_string value);
      (match old_n.element with
      | Input { placeholder = old_ph; _ } ->
          if not (String.equal old_ph placeholder) then
            Brr.El.set_at (Jstr.v "placeholder") (Some (Jstr.v placeholder)) el
      | Empty
      | Text _
      | Box _
      | Row _
      | Column _
      | Button _
      | Image _
      | Scroll _
      | Keyed _
      | Draw _ ->
          Brr.El.set_at (Jstr.v "placeholder") (Some (Jstr.v placeholder)) el);
      maybe_apply_attrs el old_n.element new_el;
      unlisten_all old_n.listeners;
      old_n.listeners <-
        wire_input_events ~dispatch el on_change on_submit on_blur on_keydown
  | Image { src; alt; _ } -> (
      match old_n.element with
      | Image { src = old_src; alt = old_alt; _ } ->
          if not (String.equal old_src src) then
            Brr.El.set_at (Jstr.v "src") (Some (Jstr.v src)) el;
          if not (String.equal old_alt alt) then
            Brr.El.set_at (Jstr.v "alt") (Some (Jstr.v alt)) el
      | Empty
      | Text _
      | Box _
      | Row _
      | Column _
      | Button _
      | Input _
      | Scroll _
      | Keyed _
      | Draw _ ->
          (* Unreachable: reconcile_node is only called when same_variant
             returns true, so old_n.element is always Image here *)
          Brr.El.set_at (Jstr.v "src") (Some (Jstr.v src)) el;
          Brr.El.set_at (Jstr.v "alt") (Some (Jstr.v alt)) el)
  | Scroll { child; _ } ->
      old_n.children <-
        reconcile_children ~sheet ~dispatch el old_n.children [ child ]
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
        cursor;
        aria_label;
      } ->
      let canvas = Brr_canvas.Canvas.of_el el in
      let ctx = Brr_canvas.C2d.get_context canvas in
      let old_w, old_h =
        match old_n.element with
        | Draw { width = ow; height = oh; _ } -> (ow, oh)
        | Empty
        | Text _
        | Box _
        | Row _
        | Column _
        | Button _
        | Input _
        | Image _
        | Scroll _
        | Keyed _ ->
            (0.0, 0.0)
      in
      if (not (Float.equal old_w width)) || not (Float.equal old_h height) then
        Canvas_renderer.setup_hidpi el ctx ~width ~height;
      Style_css.apply_cursor el cursor;
      (match aria_label with
      | Some label ->
          Brr.El.set_at (Jstr.v "aria-label") (Some (Jstr.v label)) el
      | None -> Brr.El.set_at (Jstr.v "aria-label") None el);
      Canvas_renderer.render ctx scene;
      unlisten_all old_n.listeners;
      old_n.listeners <-
        wire_draw_pointer_events ~dispatch el on_pointer_move on_click
          on_pointer_leave on_pointer_down on_pointer_up on_wheel
  | Empty
  | Text _
  | Keyed _ ->
      (* Empty and Text are handled by reconcile_live before reaching
         reconcile_node. Keyed is unwrapped to its inner child by create_live,
         so no live_node ever has element = Keyed _. All three arms are
         unreachable but listed for exhaustiveness. *)
      ());
  old_n.element <- new_el

let update ~dispatch handle new_element =
  handle.root <-
    reconcile_live ~sheet:handle.sheet ~dispatch handle.parent handle.root
      new_element

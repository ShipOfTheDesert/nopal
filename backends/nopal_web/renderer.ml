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
}

and 'msg live_comment = {
  comment : Jv.t;
      (* DOM comment node — Brr has no comment type, so we use raw Jv.t *)
}

and 'msg live_text = {
  text_dom : Brr.El.t;
  mutable text : string;
      (* mutable: text content is updated in place on reconciliation *)
}

and 'msg live =
  | Live_node of 'msg live_node
  | Live_comment of 'msg live_comment
  | Live_text of 'msg live_text

type 'msg t = {
  mutable root : 'msg live;
  (* mutable: root is replaced on reconciliation when element variant changes *)
  parent : Brr.El.t;
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

let apply_container_base_style el =
  Brr.El.set_inline_style (Jstr.v "display") (Jstr.v "flex") el

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

let rec create_live ~dispatch (element : 'msg Nopal_element.Element.t) :
    'msg live =
  match element with
  | Empty ->
      let comment =
        Jv.call (doc ()) "createComment" [| Jv.of_string "empty" |]
      in
      Live_comment { comment }
  | Text s ->
      let el = Brr.El.v (Jstr.v "span") [ Brr.El.txt (Jstr.v s) ] in
      Live_text { text_dom = el; text = s }
  | Box { style; attrs; children } ->
      let el = Brr.El.v (Jstr.v "div") [] in
      apply_container_base_style el;
      apply_style el style;
      List.iter
        (fun (k, v) -> Brr.El.set_at (Jstr.v k) (Some (Jstr.v v)) el)
        attrs;
      let live_children = List.map (create_and_append ~dispatch el) children in
      Live_node { dom = el; element; children = live_children; listeners = [] }
  | Row { style; attrs; children } ->
      let el = Brr.El.v (Jstr.v "div") [] in
      apply_container_base_style el;
      (* Set flex-direction before user style so that layout.direction in
         Style.t can override if the user explicitly sets it. *)
      Brr.El.set_inline_style (Jstr.v "flex-direction") (Jstr.v "row") el;
      apply_style el style;
      List.iter
        (fun (k, v) -> Brr.El.set_at (Jstr.v k) (Some (Jstr.v v)) el)
        attrs;
      let live_children = List.map (create_and_append ~dispatch el) children in
      Live_node { dom = el; element; children = live_children; listeners = [] }
  | Column { style; attrs; children } ->
      let el = Brr.El.v (Jstr.v "div") [] in
      apply_container_base_style el;
      (* Set flex-direction before user style so that layout.direction in
         Style.t can override if the user explicitly sets it. *)
      Brr.El.set_inline_style (Jstr.v "flex-direction") (Jstr.v "column") el;
      apply_style el style;
      List.iter
        (fun (k, v) -> Brr.El.set_at (Jstr.v k) (Some (Jstr.v v)) el)
        attrs;
      let live_children = List.map (create_and_append ~dispatch el) children in
      Live_node { dom = el; element; children = live_children; listeners = [] }
  | Button { style; attrs; on_click; on_dblclick; child } ->
      let el = Brr.El.v (Jstr.v "button") [] in
      apply_style el style;
      List.iter
        (fun (k, v) -> Brr.El.set_at (Jstr.v k) (Some (Jstr.v v)) el)
        attrs;
      let live_child = create_and_append ~dispatch el child in
      let listeners =
        wire_click ~dispatch el on_click
        @ wire_dblclick ~dispatch el on_dblclick
      in
      Live_node { dom = el; element; children = [ live_child ]; listeners }
  | Input
      {
        style;
        attrs;
        value;
        placeholder;
        on_change;
        on_submit;
        on_blur;
        on_keydown;
      } ->
      let el = Brr.El.v (Jstr.v "input") [] in
      apply_style el style;
      Jv.set (Brr.El.to_jv el) "value" (Jv.of_string value);
      Brr.El.set_at (Jstr.v "placeholder") (Some (Jstr.v placeholder)) el;
      List.iter
        (fun (k, v) -> Brr.El.set_at (Jstr.v k) (Some (Jstr.v v)) el)
        attrs;
      let listeners =
        wire_input_events ~dispatch el on_change on_submit on_blur on_keydown
      in
      Live_node { dom = el; element; children = []; listeners }
  | Image { style; src; alt } ->
      let el = Brr.El.v (Jstr.v "img") [] in
      apply_style el style;
      Brr.El.set_at (Jstr.v "src") (Some (Jstr.v src)) el;
      Brr.El.set_at (Jstr.v "alt") (Some (Jstr.v alt)) el;
      Live_node { dom = el; element; children = []; listeners = [] }
  | Scroll { style; child } ->
      let el = Brr.El.v (Jstr.v "div") [] in
      Brr.El.set_inline_style (Jstr.v "overflow") (Jstr.v "auto") el;
      apply_style el style;
      let live_child = create_and_append ~dispatch el child in
      Live_node { dom = el; element; children = [ live_child ]; listeners = [] }
  | Keyed { key; child } ->
      let live_child = create_live ~dispatch child in
      (* Set data-key on the rendered node. For comment nodes, skip
         since they don't support setAttribute. *)
      (match live_child with
      | Live_node n ->
          Brr.El.set_at (Jstr.v "data-key") (Some (Jstr.v key)) n.dom
      | Live_text t ->
          Brr.El.set_at (Jstr.v "data-key") (Some (Jstr.v key)) t.text_dom
      | Live_comment _ -> ());
      live_child

and create_and_append ~dispatch parent (element : 'msg Nopal_element.Element.t)
    =
  let live = create_live ~dispatch element in
  let jv = jv_of_live live in
  ignore (Jv.call (Brr.El.to_jv parent) "appendChild" [| jv |]);
  live

let create ~dispatch ~parent element =
  let live = create_live ~dispatch element in
  let jv = jv_of_live live in
  ignore (Jv.call (Brr.El.to_jv parent) "appendChild" [| jv |]);
  { root = live; parent }

let unlisten_all listeners = List.iter Brr.Ev.unlisten listeners

let rec unlisten_tree live =
  match live with
  | Live_node n ->
      unlisten_all n.listeners;
      List.iter unlisten_tree n.children
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
  | Keyed _, Keyed _ ->
      true
  | ( ( Empty | Text _ | Box _ | Row _ | Column _ | Button _ | Input _ | Image _
      | Scroll _ | Keyed _ ),
      _ ) ->
      false

let extract_keyed_pairs elements =
  let rec go acc = function
    | [] -> Some (List.rev acc)
    | Keyed { key; child } :: rest -> go ((key, child) :: acc) rest
    | ( Empty | Text _ | Box _ | Row _ | Column _ | Button _ | Input _ | Image _
      | Scroll _ )
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
  | Keyed _ ->
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
  | Keyed _ ->
      None

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

let rec reconcile_keyed_children ~dispatch parent_el old_children new_pairs =
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
            let updated = reconcile_live ~dispatch parent_el old_live child in
            (key, updated)
        | None ->
            let live = create_live ~dispatch child in
            set_data_key live key;
            (key, live))
      new_pairs
  in
  (* Remove old nodes that are no longer present *)
  Hashtbl.iter
    (fun _key old_live ->
      let old_jv = jv_of_live old_live in
      ignore (Jv.call parent_jv "removeChild" [| old_jv |]);
      unlisten_tree old_live)
    old_map;
  (* Reorder: appendChild moves existing nodes to the correct position *)
  List.iter
    (fun (_key, live) ->
      let jv = jv_of_live live in
      ignore (Jv.call parent_jv "appendChild" [| jv |]))
    new_lives;
  List.map snd new_lives

and reconcile_children ~dispatch parent_el old_children new_elements =
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
      reconcile_keyed_children ~dispatch parent_el old_keyed keyed_pairs
  | None ->
      let rec go olds news acc =
        match (olds, news) with
        | [], [] -> List.rev acc
        | [], new_el :: rest_new ->
            let live = create_and_append ~dispatch parent_el new_el in
            go [] rest_new (live :: acc)
        | old_live :: rest_old, [] ->
            let old_jv = jv_of_live old_live in
            ignore (Jv.call (Brr.El.to_jv parent_el) "removeChild" [| old_jv |]);
            unlisten_tree old_live;
            go rest_old [] acc
        | old_live :: rest_old, new_el :: rest_new ->
            let updated = reconcile_live ~dispatch parent_el old_live new_el in
            go rest_old rest_new (updated :: acc)
      in
      go old_children new_elements []

and reconcile_live ~dispatch parent_el (old_live : 'msg live)
    (new_element : 'msg Nopal_element.Element.t) : 'msg live =
  match (old_live, new_element) with
  | Live_text t, Text s ->
      if not (String.equal t.text s) then begin
        Brr.El.set_children t.text_dom [ Brr.El.txt (Jstr.v s) ];
        t.text <- s
      end;
      Live_text t
  | Live_comment c, Empty -> Live_comment c
  | Live_node old_n, new_el when same_variant old_n.element new_el ->
      reconcile_node ~dispatch old_n new_el;
      Live_node old_n
  | ( Live_text _,
      ( Empty | Box _ | Row _ | Column _ | Button _ | Input _ | Image _
      | Scroll _ | Keyed _ ) )
  | ( Live_comment _,
      ( Text _ | Box _ | Row _ | Column _ | Button _ | Input _ | Image _
      | Scroll _ | Keyed _ ) )
  | Live_node _, _ ->
      (* Different variant or same_variant returned false — replace *)
      let new_live = create_live ~dispatch new_element in
      let old_jv = jv_of_live old_live in
      let new_jv = jv_of_live new_live in
      ignore
        (Jv.call (Brr.El.to_jv parent_el) "replaceChild" [| new_jv; old_jv |]);
      unlisten_tree old_live;
      new_live

and reconcile_node ~dispatch (old_n : 'msg live_node)
    (new_el : 'msg Nopal_element.Element.t) =
  let el = old_n.dom in
  maybe_apply_style el old_n.element new_el;
  (match new_el with
  | Box { children; _ }
  | Row { children; _ }
  | Column { children; _ } ->
      maybe_apply_attrs el old_n.element new_el;
      old_n.children <- reconcile_children ~dispatch el old_n.children children
  | Button { on_click; on_dblclick; child; _ } ->
      maybe_apply_attrs el old_n.element new_el;
      unlisten_all old_n.listeners;
      old_n.listeners <-
        wire_click ~dispatch el on_click
        @ wire_dblclick ~dispatch el on_dblclick;
      old_n.children <- reconcile_children ~dispatch el old_n.children [ child ]
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
      | Keyed _ ->
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
      | Keyed _ ->
          (* Unreachable: reconcile_node is only called when same_variant
             returns true, so old_n.element is always Image here *)
          Brr.El.set_at (Jstr.v "src") (Some (Jstr.v src)) el;
          Brr.El.set_at (Jstr.v "alt") (Some (Jstr.v alt)) el)
  | Scroll { child; _ } ->
      old_n.children <- reconcile_children ~dispatch el old_n.children [ child ]
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
  handle.root <- reconcile_live ~dispatch handle.parent handle.root new_element

let click ~(button_type : Nopal_element.Element.button_type) ~disabled ~on_click
    ~form_submit =
  match (disabled, button_type) with
  | true, (Submit | Push) -> []
  | false, Push -> Option.to_list on_click
  | false, Submit -> Option.to_list on_click @ Option.to_list form_submit

(* What a walk of a form's controls has seen so far: the default button once
   one is found, and the number of fields that block implicit submission. *)
type 'msg scan = {
  default_button : ('msg option * bool) option;
      (** The first submit button's [on_click] and [disabled]. *)
  fields : int;
}

let rec scan acc (el : 'msg Nopal_element.Element.t) =
  match el with
  | Input _ -> { acc with fields = acc.fields + 1 }
  | Button { button_type; disabled; on_click; child; _ } ->
      (* A button precedes its own label in tree order. *)
      let acc =
        match (acc.default_button, button_type) with
        | None, Submit ->
            { acc with default_button = Some (on_click, disabled) }
        | Some _, (Submit | Push)
        | None, Push ->
            acc
      in
      scan acc child
  | Box { children; _ }
  | Row { children; _ }
  | Column { children; _ } ->
      List.fold_left scan acc children
  | Scroll { child; _ }
  | Keyed { child; _ } ->
      scan acc child
  | Virtual_list
      {
        item_count;
        row_height;
        container_height;
        scroll_state;
        overscan;
        render_item;
        _;
      } ->
      let range =
        Nopal_element.Virtual_list.visible_range ~scroll_state ~row_height
          ~container_height ~item_count ~overscan
      in
      let rec rows acc i =
        match i > range.last with
        | true -> acc
        | false -> rows (scan acc (render_item i)) (i + 1)
      in
      rows acc range.first
  (* A nested form owns the controls inside it. *)
  | Form _
  | Checkbox _
  | Radio _
  | Select _
  | File_input _
  | Empty
  | Text _
  | Image _
  | Draw _ ->
      acc

let deferred_enter ~on_submit children =
  let { default_button; fields } =
    List.fold_left scan { default_button = None; fields = 0 } children
  in
  match default_button with
  | Some (on_click, disabled) ->
      click ~button_type:Submit ~disabled ~on_click ~form_submit:on_submit
  | None -> (
      match fields <= 1 with
      | true -> Option.to_list on_submit
      | false -> [])

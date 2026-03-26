module E = Nopal_element.Element

type 'msg config = {
  label : string;
  value : string;
  placeholder : string option;
  error : string option;
  disabled : bool;
  id : string option;
  on_change : (string -> 'msg) option;
  on_submit : 'msg option;
  on_blur : 'msg option;
  style : Nopal_style.Style.t option;
  interaction : Nopal_style.Interaction.t option;
  attrs : (string * string) list;
}

let make ~label ~value =
  {
    label;
    value;
    placeholder = None;
    error = None;
    disabled = false;
    id = None;
    on_change = None;
    on_submit = None;
    on_blur = None;
    style = None;
    interaction = None;
    attrs = [];
  }

let error_id config =
  let base =
    match config.id with
    | Some id -> id
    | None -> Slug.slugify config.label
  in
  base ^ "-error"

let view config =
  let eid = error_id config in
  let suppressed = config.disabled in
  let on_change = if suppressed then None else config.on_change in
  let on_submit = if suppressed then None else config.on_submit in
  let on_blur = if suppressed then None else config.on_blur in
  let disabled_attrs = if config.disabled then [ ("disabled", "") ] else [] in
  let aria_attrs =
    match config.error with
    | Some _ -> [ ("aria-describedby", eid) ]
    | None -> []
  in
  let label_attrs = [ ("aria-label", config.label) ] in
  let input_attrs = label_attrs @ disabled_attrs @ aria_attrs @ config.attrs in
  let input_el =
    E.input ?style:config.style ?interaction:config.interaction
      ~attrs:input_attrs ?placeholder:config.placeholder ?on_change ?on_submit
      ?on_blur config.value
  in
  let error_el =
    match config.error with
    | Some msg ->
        let error_attrs = [ ("role", "alert"); ("id", eid) ] in
        [ E.box ~attrs:error_attrs [ E.text msg ] ]
    | None -> []
  in
  E.column ([ E.text config.label; input_el ] @ error_el)

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
  label_style : Nopal_style.Style.t option;
  wrapper_style : Nopal_style.Style.t option;
  error_style : Nopal_style.Style.t option;
  on_label_click : 'msg option;
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
    label_style = None;
    wrapper_style = None;
    error_style = None;
    on_label_click = None;
  }

let with_id id config = { config with id = Some id }
let with_label_style style config = { config with label_style = Some style }
let with_wrapper_style style config = { config with wrapper_style = Some style }
let with_error_style style config = { config with error_style = Some style }
let with_on_label_click msg config = { config with on_label_click = Some msg }

let control_id config =
  Slug.derive_id ~explicit:config.id ~label:config.label ()

let label_id config =
  Slug.derive_id ~explicit:config.id ~label:config.label ~suffix:"label" ()

let error_id config =
  Slug.derive_id ~explicit:config.id ~label:config.label ~suffix:"error" ()

let view config =
  let eid = error_id config in
  let iid = control_id config in
  let lid = label_id config in
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
  let naming_attrs = [ ("id", iid); ("aria-labelledby", lid) ] in
  let field_attrs = [ ("data-field", iid) ] in
  let input_attrs =
    naming_attrs @ field_attrs @ disabled_attrs @ aria_attrs @ config.attrs
  in
  let input_el =
    E.input ?style:config.style ?interaction:config.interaction
      ~attrs:input_attrs ?placeholder:config.placeholder ?on_change ?on_submit
      ?on_blur config.value
  in
  let label_text = Text_node.of_style ~style:config.label_style config.label in
  let label_el =
    E.box ?style:config.label_style
      ~attrs:[ ("id", lid) ]
      ?on_pointer_down:
        (Option.map (fun msg _event -> msg) config.on_label_click)
      [ label_text ]
  in
  let error_el =
    match config.error with
    | Some msg ->
        let error_attrs = [ ("role", "alert"); ("id", eid) ] in
        let error_text = Text_node.of_style ~style:config.error_style msg in
        [ E.box ?style:config.error_style ~attrs:error_attrs [ error_text ] ]
    | None -> []
  in
  E.column ?style:config.wrapper_style ([ label_el; input_el ] @ error_el)

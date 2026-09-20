module E = Nopal_element.Element

type 'msg config = {
  label : string;
  options : E.select_option list;
  selected : string;
  placeholder : string option;
  disabled : bool;
  on_change : (string -> 'msg) option;
  style : Nopal_style.Style.t option;
  interaction : Nopal_style.Interaction.t option;
  attrs : (string * string) list;
  id : string option;
  label_style : Nopal_style.Style.t option;
  wrapper_style : Nopal_style.Style.t option;
  on_label_click : 'msg option;
}

let make ~label ~options ~selected =
  {
    label;
    options;
    selected;
    placeholder = None;
    disabled = false;
    on_change = None;
    style = None;
    interaction = None;
    attrs = [];
    id = None;
    label_style = None;
    wrapper_style = None;
    on_label_click = None;
  }

let with_id id config = { config with id = Some id }
let with_label_style style config = { config with label_style = Some style }
let with_wrapper_style style config = { config with wrapper_style = Some style }
let with_on_label_click msg config = { config with on_label_click = Some msg }

let control_id config =
  Slug.derive_id ~explicit:config.id ~label:config.label ()

let label_id config =
  Slug.derive_id ~explicit:config.id ~label:config.label ~suffix:"label" ()

let view config =
  let on_change = if config.disabled then None else config.on_change in
  let options =
    match config.placeholder with
    | Some text ->
        E.select_option ~disabled:true ~value:"" text :: config.options
    | None -> config.options
  in
  let cid = control_id config in
  let lid = label_id config in
  let attrs =
    ("id", cid)
    :: ("aria-labelledby", lid)
    :: ("data-action", "select-open")
    :: ("data-field", Slug.slugify config.label)
    :: config.attrs
  in
  let sel =
    E.select ?style:config.style ?interaction:config.interaction ~attrs
      ~disabled:config.disabled ?on_change ~selected:config.selected options
  in
  let label =
    E.box ?style:config.label_style
      ~attrs:[ ("id", lid) ]
      ?on_pointer_down:
        (Option.map (fun msg _event -> msg) config.on_label_click)
      [ Text_node.of_style ~style:config.label_style config.label ]
  in
  E.column ?style:config.wrapper_style [ label; sel ]

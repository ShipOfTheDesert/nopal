module E = Nopal_element.Element

type 'msg config = {
  label : string;
  checked : bool;
  disabled : bool;
  on_toggle : (bool -> 'msg) option;
  style : Nopal_style.Style.t option;
  interaction : Nopal_style.Interaction.t option;
  attrs : (string * string) list;
  id : string option;
  label_style : Nopal_style.Style.t option;
  row_style : Nopal_style.Style.t option;
  on_label_click : 'msg option;
}

let make ~label ~checked =
  {
    label;
    checked;
    disabled = false;
    on_toggle = None;
    style = None;
    interaction = None;
    attrs = [];
    id = None;
    label_style = None;
    row_style = None;
    on_label_click = None;
  }

let with_id id config = { config with id = Some id }
let with_label_style style config = { config with label_style = Some style }
let with_row_style style config = { config with row_style = Some style }
let with_on_label_click msg config = { config with on_label_click = Some msg }

let control_id config =
  Slug.derive_id ~explicit:config.id ~label:config.label ()

let label_id config =
  Slug.derive_id ~explicit:config.id ~label:config.label ~suffix:"label" ()

let view config =
  let on_toggle = if config.disabled then None else config.on_toggle in
  let cid = control_id config in
  let lid = label_id config in
  let attrs =
    ("id", cid)
    :: ("aria-labelledby", lid)
    :: ("data-field", Slug.slugify config.label)
    :: config.attrs
  in
  let checkbox =
    E.checkbox ?style:config.style ?interaction:config.interaction ~attrs
      ~disabled:config.disabled ?on_toggle config.checked
  in
  let label =
    E.box ?style:config.label_style
      ~attrs:[ ("id", lid) ]
      ?on_pointer_down:
        (Option.map (fun msg _event -> msg) config.on_label_click)
      [ Text_node.of_style ~style:config.label_style config.label ]
  in
  E.row ?style:config.row_style [ checkbox; label ]

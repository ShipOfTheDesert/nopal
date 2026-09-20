module E = Nopal_element.Element

type radio_option = { label : string; value : string; disabled : bool }

type 'msg config = {
  label : string;
  options : radio_option list;
  selected : string;
  disabled : bool;
  name : string option;
  on_select : (string -> 'msg) option;
  style : Nopal_style.Style.t option;
  interaction : Nopal_style.Interaction.t option;
  attrs : (string * string) list;
  id : string option;
  visible_label : bool option;
  label_style : Nopal_style.Style.t option;
  group_style : Nopal_style.Style.t option;
  option_label_style : Nopal_style.Style.t option;
  option_row_style : Nopal_style.Style.t option;
  on_label_click : (string -> 'msg) option;
}

let radio_option ?(disabled = false) ~value label = { label; value; disabled }

let make ~label ~options ~selected =
  {
    label;
    options;
    selected;
    disabled = false;
    name = None;
    on_select = None;
    style = None;
    interaction = None;
    attrs = [];
    id = None;
    visible_label = None;
    label_style = None;
    group_style = None;
    option_label_style = None;
    option_row_style = None;
    on_label_click = None;
  }

let with_id id config = { config with id = Some id }

let with_visible_label visible config =
  { config with visible_label = Some visible }

let with_label_style style config = { config with label_style = Some style }
let with_group_style style config = { config with group_style = Some style }

let with_option_label_style style config =
  { config with option_label_style = Some style }

let with_option_row_style style config =
  { config with option_row_style = Some style }

let with_on_label_click f config = { config with on_label_click = Some f }

let control_id config =
  Slug.derive_id ~explicit:config.id ~label:config.label ()

let group_label_id config =
  Slug.derive_id ~explicit:config.id ~label:config.label ~suffix:"label" ()

let option_id config ~value =
  Slug.derive_id ~explicit:config.id ~label:config.label
    ~suffix:(Slug.slugify value) ()

let option_label_id config ~value =
  Slug.derive_id
    ~explicit:(Some (option_id config ~value))
    ~label:"" ~suffix:"label" ()

let group_name config =
  match config.name with
  | Some n -> n
  | None -> Slug.slugify config.label

let view config =
  let name = group_name config in
  let render_option (opt : radio_option) =
    let disabled = config.disabled || opt.disabled in
    let on_select =
      if disabled then None
      else Option.map (fun f -> f opt.value) config.on_select
    in
    let oid = option_id config ~value:opt.value in
    let olid = option_label_id config ~value:opt.value in
    let radio =
      E.radio ?style:config.style ?interaction:config.interaction
        ~attrs:[ ("id", oid); ("aria-labelledby", olid); ("data-field", name) ]
        ~checked:(config.selected = opt.value)
        ~disabled ?on_select ~name ()
    in
    let label =
      E.box ?style:config.option_label_style
        ~attrs:[ ("id", olid) ]
        ?on_pointer_down:
          (Option.map (fun f _event -> f opt.value) config.on_label_click)
        [ Text_node.of_style ~style:config.option_label_style opt.label ]
    in
    E.row ?style:config.option_row_style [ radio; label ]
  in
  let option_rows = List.map render_option config.options in
  let naming, children =
    match config.visible_label with
    | Some true ->
        let lid = group_label_id config in
        let group_label =
          E.box ?style:config.label_style
            ~attrs:[ ("id", lid) ]
            [ Text_node.of_style ~style:config.label_style config.label ]
        in
        (("aria-labelledby", lid), group_label :: option_rows)
    | Some false
    | None ->
        (("aria-label", config.label), option_rows)
  in
  E.column ?style:config.group_style
    ~attrs:
      ([ ("role", "radiogroup"); naming; ("id", control_id config) ]
      @ config.attrs)
    children

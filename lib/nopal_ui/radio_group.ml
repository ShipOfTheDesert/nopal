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
  }

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
    let radio =
      E.radio ?style:config.style ?interaction:config.interaction
        ~attrs:[ ("aria-label", opt.label) ]
        ~checked:(config.selected = opt.value)
        ~disabled ?on_select ~name ()
    in
    let label = E.text opt.label in
    E.row [ radio; label ]
  in
  let children = List.map render_option config.options in
  E.column
    ~attrs:
      ([ ("role", "radiogroup"); ("aria-label", config.label) ] @ config.attrs)
    children

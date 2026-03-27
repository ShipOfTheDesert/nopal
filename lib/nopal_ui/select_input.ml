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
  }

let view config =
  let on_change = if config.disabled then None else config.on_change in
  let options =
    match config.placeholder with
    | Some text ->
        E.select_option ~disabled:true ~value:"" text :: config.options
    | None -> config.options
  in
  let attrs = ("aria-label", config.label) :: config.attrs in
  let sel =
    E.select ?style:config.style ?interaction:config.interaction ~attrs
      ~disabled:config.disabled ?on_change ~selected:config.selected options
  in
  let label = E.text config.label in
  E.column [ label; sel ]

module E = Nopal_element.Element

type 'msg config = {
  label : string;
  checked : bool;
  disabled : bool;
  on_toggle : (bool -> 'msg) option;
  style : Nopal_style.Style.t option;
  interaction : Nopal_style.Interaction.t option;
  attrs : (string * string) list;
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
  }

let view config =
  let on_toggle = if config.disabled then None else config.on_toggle in
  let attrs = ("aria-label", config.label) :: config.attrs in
  let checkbox =
    E.checkbox ?style:config.style ?interaction:config.interaction ~attrs
      ~disabled:config.disabled ?on_toggle config.checked
  in
  let label = E.text config.label in
  E.row [ checkbox; label ]

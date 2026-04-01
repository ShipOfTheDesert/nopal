module E = Nopal_element.Element

type 'msg item = { id : string; label : string; icon : 'msg E.t option }

type 'msg config = {
  items : 'msg item list;
  active : string;
  on_select : string -> 'msg;
  style : Nopal_style.Style.t option;
  tab_style : Nopal_style.Style.t option;
  active_tab_style : Nopal_style.Style.t option;
  interaction : Nopal_style.Interaction.t option;
  attrs : (string * string) list;
}

let item ?icon ~id label = { id; label; icon }

let make ~items ~active ~on_select =
  {
    items;
    active;
    on_select;
    style = None;
    tab_style = None;
    active_tab_style = None;
    interaction = None;
    attrs = [];
  }

let with_style s config = { config with style = Some s }
let with_tab_style s config = { config with tab_style = Some s }
let with_active_tab_style s config = { config with active_tab_style = Some s }
let with_interaction i config = { config with interaction = Some i }
let with_attrs a config = { config with attrs = a }
let default_inactive_bg = Nopal_style.Style.rgba 240 240 240 1.0
let default_active_bg = Nopal_style.Style.rgba 59 130 246 1.0

let view config =
  let render_item (tab : 'msg item) =
    let is_active = tab.id = config.active in
    let tab_bg = if is_active then default_active_bg else default_inactive_bg in
    let base_style =
      match config.tab_style with
      | Some s -> s
      | None ->
          Nopal_style.Style.default
          |> Nopal_style.Style.with_paint (fun p ->
              { p with background = Some tab_bg })
    in
    let tab_style =
      if is_active then
        match config.active_tab_style with
        | Some s -> s
        | None -> base_style
      else base_style
    in
    let on_click = if is_active then None else Some (config.on_select tab.id) in
    let content =
      match tab.icon with
      | Some icon -> E.row [ icon; E.text tab.label ]
      | None -> E.text tab.label
    in
    E.button ~style:tab_style ?on_click ?interaction:config.interaction
      ~attrs:
        [
          ("role", "tab");
          ("aria-selected", if is_active then "true" else "false");
          ("data-testid", "nav-tab-" ^ tab.id);
        ]
      content
  in
  let children = List.map render_item config.items in
  let container_attrs = [ ("role", "tablist") ] @ config.attrs in
  E.row ?style:config.style ~attrs:container_attrs children

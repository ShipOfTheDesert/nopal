module E = Nopal_element.Element
module Style = Nopal_style.Style
module Nav_stack = Nopal_navigation.Nav_stack

type ('screen, 'msg) tab = {
  id : string;
  label : string;
  icon : 'msg E.t option;
  stack : 'screen Nav_stack.t;
}

type ('screen, 'msg) config = {
  tabs : ('screen, 'msg) tab list;
  active : string;
  render_screen : 'screen -> 'msg E.t;
  on_select : string -> 'msg;
  on_back : 'msg;
  safe_area_bottom : int;
  bar_style : Style.t option;
  bar_interaction : Nopal_style.Interaction.t option;
  bar_attrs : (string * string) list;
  tab_style : Style.t option;
  active_tab_style : Style.t option;
  panel_style : Style.t option;
  gutter_style : Style.t option;
  back_label : string option;
  back_suppressed : bool;
  attrs : (string * string) list;
}

let tab ?icon ~id ~label ~stack () = { id; label; icon; stack }

let make ~tabs ~active ~render_screen ~on_select ~on_back ~safe_area_bottom =
  {
    tabs;
    active;
    render_screen;
    on_select;
    on_back;
    safe_area_bottom;
    bar_style = None;
    bar_interaction = None;
    bar_attrs = [];
    tab_style = None;
    active_tab_style = None;
    panel_style = None;
    gutter_style = None;
    back_label = None;
    back_suppressed = false;
    attrs = [];
  }

let with_bar_style s config = { config with bar_style = Some s }
let with_bar_interaction i config = { config with bar_interaction = Some i }
let with_bar_attrs a config = { config with bar_attrs = a }
let with_tab_style s config = { config with tab_style = Some s }
let with_active_tab_style s config = { config with active_tab_style = Some s }
let with_panel_style s config = { config with panel_style = Some s }
let with_gutter_style s config = { config with gutter_style = Some s }
let with_back_suppressed b config = { config with back_suppressed = b }
let with_back_label l config = { config with back_label = Some l }
let with_attrs a config = { config with attrs = a }
let default_back_label = "Back"

let back_button config =
  let label =
    match config.back_label with
    | Some l -> l
    | None -> default_back_label
  in
  E.button
    ~attrs:[ ("data-action", "nav-back"); ("data-testid", "bottom-tabs-back") ]
    ~on_click:config.on_back (E.text label)

(* The panel takes every pixel the tab bar does not, which is the whole of what
   puts the bar at the *bottom* of the container rather than immediately under
   the content. Without it a full-height root just moves the blank space from
   below the bar to below the panel, and the bar still floats.

   It is applied over [with_panel_style]'s override rather than replaced by it:
   that override is documented as cosmetic, and a caller reaching for a
   background colour is not thereby asking the bar to float. A caller that
   genuinely wants a content-sized panel says so by setting [flex_grow] itself —
   an explicit [Some _] is left alone, including [Some 0.] — so only the absence
   of an opinion is filled in. *)
let grow_panel style =
  Style.with_layout
    (fun l ->
      match l.Style.flex_grow with
      | Some (_ : float) -> l
      | None -> { l with Style.flex_grow = Some 1.0 })
    style

let panel config =
  let children =
    match List.find_opt (fun t -> t.id = config.active) config.tabs with
    | None -> []
    | Some active_tab ->
        let screen =
          config.render_screen (Nav_stack.current active_tab.stack)
        in
        if Nav_stack.can_pop active_tab.stack && not config.back_suppressed then
          [ back_button config; screen ]
        else [ screen ]
  in
  let attrs = [ ("role", "tabpanel"); ("data-field", config.active) ] in
  let style =
    match config.panel_style with
    | Some s -> grow_panel s
    | None -> grow_panel Style.default
  in
  E.box ~style ~attrs children

let bar config =
  let to_item t = Navigation_bar.item ?icon:t.icon ~id:t.id t.label in
  let bar_config =
    Navigation_bar.make
      ~items:(List.map to_item config.tabs)
      ~active:config.active ~on_select:config.on_select
  in
  let bar_config =
    match config.tab_style with
    | Some s -> Navigation_bar.with_tab_style s bar_config
    | None -> bar_config
  in
  let bar_config =
    match config.active_tab_style with
    | Some s -> Navigation_bar.with_active_tab_style s bar_config
    | None -> bar_config
  in
  let bar_config =
    match config.bar_style with
    | Some s -> Navigation_bar.with_style s bar_config
    | None -> bar_config
  in
  let bar_config =
    match config.bar_interaction with
    | Some i -> Navigation_bar.with_interaction i bar_config
    | None -> bar_config
  in
  let bar_config = Navigation_bar.with_attrs config.bar_attrs bar_config in
  Navigation_bar.view bar_config

(* The safe-area inset is *added* to the gutter style's own [padding_bottom]
   rather than replacing it, and this is the one field [with_gutter_style] does
   not simply replace.

   The asymmetry is the same one [grow_panel] makes on the panel, for the same
   reason and with the opposite resolution. That override is cosmetic and the
   panel's growth is structural, so an explicit caller value wins there: asking
   for a content-sized panel is a thing a caller can legitimately want, and it
   costs nothing but layout. Here the structural property is REQ-F4 — the bar
   clears the gesture bar — and a caller who overrides it gets an app whose tabs
   sit underneath the system's own affordance and cannot be tapped. No caller
   wants that, and a cosmetic setter is not where they would go to ask for it.
   So the inset is unconditional and the caller's value is added to it. *)
let inset_gutter safe_area_bottom style =
  Style.with_layout
    (fun l ->
      let own =
        match l.Style.padding_bottom with
        | Some v -> v
        | None -> 0.0
      in
      {
        l with
        Style.padding_bottom = Some (own +. float_of_int safe_area_bottom);
      })
    style

let gutter config =
  let gutter_style =
    match config.gutter_style with
    | Some s -> inset_gutter config.safe_area_bottom s
    | None -> inset_gutter config.safe_area_bottom Style.default
  in
  E.box ~style:gutter_style
    ~attrs:[ ("data-testid", "bottom-tabs-gutter") ]
    [ bar config ]

(* The root fills its container's height, which is the other half of putting the
   bar at the bottom — [grow_panel] distributes the space, this is what there is
   space to distribute. Without it the root is a content-sized block and the two
   children stack at the top of whatever it is mounted in.

   [Fill] rather than a viewport unit, and this is the reason the change is safe
   for a caller who is *not* using the component as a whole screen: [Fill]
   renders as [height: 100%], and a percentage height against a parent whose own
   height is [auto] resolves back to [auto]. So a [Bottom_tabs] embedded as one
   section of a scrolling page is unaffected, and one mounted in a container
   that has been given a height fills it. The caller decides which it is by
   sizing the container, which is where that decision belongs. *)
let root_style =
  Style.default
  |> Style.with_layout (fun l -> { l with Style.height = Some Style.Fill })

let view config =
  E.column ~style:root_style ~attrs:config.attrs [ panel config; gutter config ]

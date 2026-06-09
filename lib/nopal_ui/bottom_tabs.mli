(** Bottom tab navigation with per-tab navigation stacks.

    Renders a content panel ([role="tabpanel"]) above a bottom tab bar
    ([role="tablist"], reusing {!Navigation_bar}). Each tab owns an independent
    {!Nopal_navigation.Nav_stack.t}; the panel renders the active tab's current
    screen. The component is stateless — all navigation state lives in the
    application model (REQ-F2). *)

type ('screen, 'msg) tab
(** A single tab: a string id, a label, an optional icon, and the tab's own
    independent navigation stack. *)

type ('screen, 'msg) config
(** Stateless render configuration. All behavioural fields are required
    parameters of {!make}; the component stores nothing. *)

val tab :
  ?icon:'msg Nopal_element.Element.t ->
  id:string ->
  label:string ->
  stack:'screen Nopal_navigation.Nav_stack.t ->
  unit ->
  ('screen, 'msg) tab
(** [tab ~id ~label ~stack ()] describes one tab. [id] is matched against
    [~active] and echoed in [on_select]; [stack] is this tab's current
    navigation state (owned by the application model). *)

val make :
  tabs:('screen, 'msg) tab list ->
  active:string ->
  render_screen:('screen -> 'msg Nopal_element.Element.t) ->
  on_select:(string -> 'msg) ->
  on_back:'msg ->
  safe_area_bottom:int ->
  ('screen, 'msg) config
(** [make ~tabs ~active ~render_screen ~on_select ~on_back ~safe_area_bottom]
    builds a config. All fields are required (no behavioural defaults).
    @param render_screen How the application draws one screen into content.
    @param on_select Message for selecting a tab by id.
    @param on_back
      Message for the back affordance (component surfaces pop intent; the app
      calls {!Nopal_navigation.Nav_stack.pop}).
    @param safe_area_bottom
      Bottom inset in px (caller passes
      [Viewport.safe_area_bottom (Viewport.safe_area vp)]); 0 leaves layout
      unaffected (REQ-F4). *)

val with_tab_style :
  Nopal_style.Style.t -> ('screen, 'msg) config -> ('screen, 'msg) config
(** Override the base style for all tabs in the bar. Cosmetic only. *)

val with_active_tab_style :
  Nopal_style.Style.t -> ('screen, 'msg) config -> ('screen, 'msg) config
(** Override the style applied to the active tab. Cosmetic only. *)

val with_panel_style :
  Nopal_style.Style.t -> ('screen, 'msg) config -> ('screen, 'msg) config
(** Override the content panel (tabpanel) style. Cosmetic only. *)

val with_back_label : string -> ('screen, 'msg) config -> ('screen, 'msg) config
(** Override the back affordance label (default ["Back"]). Cosmetic only. *)

val with_attrs :
  (string * string) list -> ('screen, 'msg) config -> ('screen, 'msg) config
(** Additional attributes on the root container element. Cosmetic only. *)

val view : ('screen, 'msg) config -> 'msg Nopal_element.Element.t
(** Renders the bottom-tabs structure:

    {[
      Column [root; attrs]
        Box [role="tabpanel"; data-field=<active id>]
          (when active stack can_pop)
            Button [data-action="nav-back"; on_click=on_back] <back label>
          render_screen (Nav_stack.current of active tab's stack)
        Box [data-testid="bottom-tabs-gutter"; padding_bottom=safe_area_bottom]
          Navigation_bar.view (role="tablist" with one role="tab" per tab)
    ]}

    The back affordance is rendered only when the active tab's stack
    {!Nopal_navigation.Nav_stack.can_pop} is [true]; clicking it emits
    [on_back]. Selecting an inactive tab emits [on_select] with its id. *)

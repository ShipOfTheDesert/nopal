(** Bottom tab navigation with per-tab navigation stacks.

    Renders a content panel ([role="tabpanel"]) above a bottom tab bar
    ([role="tablist"], reusing {!Navigation_bar}). Each tab owns an independent
    {!Nopal_navigation.Nav_stack.t}; the panel renders the active tab's current
    screen. The component is stateless — all navigation state lives in the
    application model (REQ-F2).

    {2 Filling the screen}

    The bar sits at the bottom of the component's container, not merely below
    the content: the root is [height: Fill] and the panel takes the leftover
    space, so the two together push the bar down. Neither is reachable through
    the [with_*] overrides, which are cosmetic.

    Whether that container is the screen is the caller's to decide, and the
    caller decides it by sizing the container — the component asks for 100% of a
    height it does not choose. A percentage height against an [auto]-height
    parent resolves to [auto], so mounting this inside an ordinary content-sized
    page leaves it content-sized, exactly as before, while mounting it in a
    container with a real height fills that height.

    For a whole-screen application that means the host page must give the mount
    target one — on the web, [html], [body] and the target element all need a
    height, since none has one by default. Nothing this component can do
    substitutes for that: [height: 100%] of nothing is nothing. *)

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

val with_bar_style :
  Nopal_style.Style.t -> ('screen, 'msg) config -> ('screen, 'msg) config
(** Override the tab bar's own container style — the [role="tablist"] row that
    holds the tabs, not the root and not the panel. This is where bar-level
    geometry lives: padding, gap, border radius, shadow, background.

    Distinct from {!with_attrs}, which targets the root container: a bar style
    set here and attributes set there land on two different elements. Cosmetic
    only — it cannot move the bar off the bottom, which is {!with_panel_style}'s
    [flex_grow] and the root's [Fill] height between them. *)

val with_bar_interaction :
  Nopal_style.Interaction.t -> ('screen, 'msg) config -> ('screen, 'msg) config
(** Override the hover/pressed/focused interaction on the tab buttons.

    One interaction is shared by the whole bar and is applied to {e every} tab,
    the active one included; there is no per-tab interaction. Cosmetic only. *)

val with_bar_attrs :
  (string * string) list -> ('screen, 'msg) config -> ('screen, 'msg) config
(** Additional attributes on the tab bar's container element (the
    [role="tablist"] row). Attributes given here override the bar's internal
    ARIA attributes on conflict (last-writer-wins).

    {!with_attrs} is the analogue for the root container; the two do not
    interfere. Cosmetic only. *)

val with_tab_style :
  Nopal_style.Style.t -> ('screen, 'msg) config -> ('screen, 'msg) config
(** Override the base style for all tabs in the bar. Cosmetic only. *)

val with_active_tab_style :
  Nopal_style.Style.t -> ('screen, 'msg) config -> ('screen, 'msg) config
(** Override the style applied to the active tab. Cosmetic only.

    This style {e replaces} the one from {!with_tab_style} on the active tab
    rather than merging over it, so any property the active tab needs must be
    restated here — [flex_grow], padding, border radius and the rest are not
    inherited from the base tab style. *)

val with_panel_style :
  Nopal_style.Style.t -> ('screen, 'msg) config -> ('screen, 'msg) config
(** Override the content panel (tabpanel) style. Cosmetic only.

    The panel's [flex_grow] is the one field this does not simply replace: the
    panel grows into the space the tab bar leaves, and a style that says nothing
    about [flex_grow] keeps that. Say [Some 0.] to opt out and get a
    content-sized panel; any explicit value, including [Some 0.], is honoured as
    given. *)

val with_gutter_style :
  Nopal_style.Style.t -> ('screen, 'msg) config -> ('screen, 'msg) config
(** Override the style of the wrapper the tab bar sits in — the
    [data-testid="bottom-tabs-gutter"] box between the root and the
    [role="tablist"] row. This is where geometry that must sit {e outside} the
    bar pill lives: the margin between the pill and the screen edges, and the
    space under it.

    {b [padding_bottom] is added to, not replaced by, this style.} The gutter is
    the sole carrier of [~safe_area_bottom] (REQ-F4), and every [with_*] here is
    cosmetic: a cosmetic override must not be able to drop the bar underneath a
    gesture bar. A style saying [padding_bottom = Some 14.] under a 34px inset
    renders 48px; one saying nothing about the bottom edge renders the inset
    unchanged. Every other field replaces as usual.

    Distinct from {!with_bar_style}, which targets the [role="tablist"] row
    inside this box. Cosmetic only. *)

val with_back_label : string -> ('screen, 'msg) config -> ('screen, 'msg) config
(** Override the back affordance label (default ["Back"]). Cosmetic only. *)

val with_back_suppressed :
  bool -> ('screen, 'msg) config -> ('screen, 'msg) config
(** Suppress the component's own back affordance (default [false]).

    With [true] the button described in {!view} is never rendered, whatever the
    active stack's {!Nopal_navigation.Nav_stack.can_pop} says. Nothing else
    changes: the stacks, [~on_back] and the panel's content are untouched, and
    {!with_back_label} simply has nothing to label.

    This exists for an application that draws its own back affordance and needs
    exactly one on screen. The component's button is rendered inside the
    tabpanel and above [~render_screen]'s output, which is a position no style
    override can move it out of — so a caller whose design puts the affordance
    anywhere else has no way to reconcile the two except by turning this one
    off. Suppressing it makes the back path the caller's responsibility: the
    component then surfaces no pop intent of its own, and only the hardware or
    platform back press still reaches [~on_back]. Cosmetic only — it removes an
    element and decides no navigation. *)

val with_attrs :
  (string * string) list -> ('screen, 'msg) config -> ('screen, 'msg) config
(** Additional attributes on the root container element. See {!with_bar_attrs}
    for the tab bar's own container. Cosmetic only. *)

val view : ('screen, 'msg) config -> 'msg Nopal_element.Element.t
(** Renders the bottom-tabs structure:

    {[
      Column [root; attrs; height=Fill]
        Box [role="tabpanel"; data-field=<active id>; flex_grow=1]
          (when active stack can_pop)
            Button [data-action="nav-back"; on_click=on_back] <back label>
          render_screen (Nav_stack.current of active tab's stack)
        Box [data-testid="bottom-tabs-gutter"; padding_bottom=safe_area_bottom]
          Navigation_bar.view (role="tablist" with one role="tab" per tab)
    ]}

    The back affordance is rendered only when the active tab's stack
    {!Nopal_navigation.Nav_stack.can_pop} is [true]; clicking it emits
    [on_back]. Selecting an inactive tab emits [on_select] with its id. *)

(** Accessible navigation bar (tablist) component. *)

type 'msg item
(** A single navigation tab with an ID, label, and optional icon. *)

val item :
  ?icon:'msg Nopal_element.Element.t -> id:string -> string -> 'msg item
(** [item ~id label] creates a navigation item.
    @param id Unique identifier for this tab (used in [on_select] callback)
    @param label Display text for the tab
    @param icon Optional element rendered alongside the label *)

type 'msg config
(** Configuration for the navigation bar. All behavioural fields ([items],
    [active], [on_select]) are required parameters of [make]. Cosmetic fields
    default to [None]. *)

val make :
  items:'msg item list ->
  active:string ->
  on_select:(string -> 'msg) ->
  'msg config
(** [make ~items ~active ~on_select] creates a navigation bar config.
    @param items Non-empty list of navigation items
    @param active ID of the currently active tab
    @param on_select Callback producing a message from the selected tab's ID *)

val with_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** Override the container (tablist) style. *)

val with_tab_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** Override the base style for all tab items. *)

val with_active_tab_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** Override the style applied to the active tab.

    This style {e replaces} the base tab style on the active tab; it is not
    merged over it. Any property the active tab needs must therefore be restated
    here — [flex_grow], padding, border radius and the rest do not carry over
    from {!with_tab_style}, and an active style that sets only a background
    loses whatever geometry the base style gave the other tabs. *)

val with_interaction : Nopal_style.Interaction.t -> 'msg config -> 'msg config
(** Override the hover/pressed/focused interaction on the tab buttons.

    One interaction is shared by the whole bar and is applied to every item the
    {!with_item_interaction} function does not answer for, the active one
    included. With no per-item function it is applied to {e every} item. *)

val with_item_text_style : Nopal_style.Text.t -> 'msg config -> 'msg config
(** [with_item_text_style text config] sets the typography of every item's label
    — the text node inside the item's button, which without this carries no text
    style at all.

    It takes a [Text.t] and not a whole [Style.t] because a text node carries a
    text style and nothing else: every field [text] has reaches the label, and
    there is no component of it that lands nowhere. The button's own style is
    {!with_tab_style} and {!with_active_tab_style}, and the gap between an icon
    and its label is {!with_item_row_style}. The text style {e replaces}
    whatever the label had; nothing is merged.

    It reaches the label whether or not the item has an icon. Without it the
    label is an unstyled [Element.text], exactly as before. *)

val with_item_row_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** [with_item_row_style style config] styles the row that holds an item's icon
    and its label, which is the route to the gap between the two. The style
    {e replaces}; nothing is merged.

    That row exists only for an item built with [~icon]. An item with no icon
    renders its label directly in its button and has no gap to set, and this
    setter adds no element to give it one. *)

val with_item_interaction :
  (string -> Nopal_style.Interaction.t option) -> 'msg config -> 'msg config
(** [with_item_interaction f config] gives one item a different
    hover/pressed/focused interaction from the rest. For every item the bar
    renders, [f] is asked for that item's interaction by the item's [id]:
    [Some i] puts [i] on that item's button, and [None] leaves the item on
    {!with_interaction}'s bar-wide interaction — or on no interaction at all,
    when that is unset. [f] is called once per item per render and must be
    total.

    It is keyed on the [id] string rather than on the item value because
    ['msg item] is abstract and every item has an [id] by construction; a
    function of a value the caller cannot inspect could not tell one item from
    another. An answer of [Some] {e replaces} the bar-wide interaction on that
    item rather than merging with it. *)

val with_attrs : (string * string) list -> 'msg config -> 'msg config
(** Additional attributes on the container element. User attrs override internal
    ARIA attrs on conflict (last-writer-wins). *)

val view : 'msg config -> 'msg Nopal_element.Element.t
(** Renders the navigation bar. Each item carries [data-action="nav-navigate"]
    plus [data-field=<item id>]. These anchors are the E2E selector contract
    (RFC 0112) and are asserted by [test_anchors.ml].

    Renders the navigation bar. The container carries [role="tablist"]. Each
    item is a [Button] with [role="tab"] and [aria-selected] — the ARIA spec
    allows [role="tab"] on button elements. Clicking the active tab produces no
    message (no-op). Clicking an inactive tab invokes [on_select] with that
    tab's ID. *)

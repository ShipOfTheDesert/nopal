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
(** Override the style applied to the active tab (merged atop tab style). *)

val with_interaction : Nopal_style.Interaction.t -> 'msg config -> 'msg config
(** Override hover/pressed interaction for inactive tabs. *)

val with_attrs : (string * string) list -> 'msg config -> 'msg config
(** Additional attributes on the container element. User attrs override internal
    ARIA attrs on conflict (last-writer-wins). *)

val view : 'msg config -> 'msg Nopal_element.Element.t
(** Renders the navigation bar. The container carries [role="tablist"]. Each
    item is a [Button] with [role="tab"] and [aria-selected] — the ARIA spec
    allows [role="tab"] on button elements. Clicking the active tab produces no
    message (no-op). Clicking an inactive tab invokes [on_select] with that
    tab's ID. *)

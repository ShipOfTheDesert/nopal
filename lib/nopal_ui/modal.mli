(** Modal dialog component.

    Renders a dialog overlay with ARIA attributes, optional backdrop, Escape-key
    subscription, and a pure focus-cycling helper. *)

(** {1 Configuration} *)

type 'msg config
(** Configuration for a modal dialog. All behavioural fields ([open_],
    [title_id], [on_close], [body]) are required parameters of [make]. *)

val make :
  open_:bool ->
  title_id:string ->
  on_close:'msg ->
  body:'msg Nopal_element.Element.t ->
  'msg config
(** [make ~open_ ~title_id ~on_close ~body] creates a modal config.
    @param open_ Whether the modal is currently visible
    @param title_id Element ID referenced by [aria-labelledby]
    @param on_close Message dispatched when Escape is pressed
    @param body Content rendered inside the dialog *)

(** {1 Optional overrides} *)

val with_on_backdrop_click : 'msg -> 'msg config -> 'msg config
(** When set, renders a backdrop overlay behind the dialog. Clicking the
    backdrop dispatches the provided message. When not set (default), no
    backdrop is rendered. *)

val with_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** Override the dialog container style. Every field replaces, with one fill-in:
    when a backdrop is present and the style leaves [layout.position] at [None],
    the dialog is given [Pos_relative], because a backdrop is [Pos_absolute] and
    an unpositioned dialog would not stack above it. That is a fill-in and not a
    force — a style that names its own [position] keeps it, and with no backdrop
    nothing is filled in at all. *)

val with_backdrop_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** Override the backdrop overlay style. Every field replaces {e except}
    [layout.position], [layout.top], [layout.left], [layout.width] and
    [layout.height], which are forced back to [Pos_absolute], [0.], [0.], [Fill]
    and [Fill] over whatever the style said: a backdrop that does not cover the
    dialog is not a backdrop, and the dialog's own positioning above depends on
    it. Paint, border, shadow, padding and every other layout field replace as
    usual — this is a partial exemption, not an ignored override. *)

val with_interaction : Nopal_style.Interaction.t -> 'msg config -> 'msg config
(** Override hover/pressed/focused interaction on the dialog container. *)

val with_attrs : (string * string) list -> 'msg config -> 'msg config
(** Additional attributes on the dialog element. User attrs override internal
    ARIA attrs on conflict (last-writer-wins). *)

val with_root_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** [with_root_style style config] styles the outer [data-testid="modal-root"]
    box — the element that holds the backdrop and the dialog and covers the
    viewport. {!with_style} reaches the dialog and {!with_backdrop_style} the
    backdrop, so without this setter the overlay's own placement is unreachable:
    a modal that should sit at the bottom of the screen rather than centred, or
    above or below a different stacking layer, could not be built from this
    component.

    It {e replaces} {!default_root_style} entirely — no field of the default
    survives, including the fixed positioning and the z-index. To keep those and
    change one thing, build the style from {!default_root_style}. *)

val default_root_style : Nopal_style.Style.t
(** The style the root box carries when {!with_root_style} is not used:
    [position: fixed] at [top]/[left] [0.] with [Fill] width and height,
    [z_index] [1000], centred on both axes.

    It is published because {!with_root_style} replaces it wholesale, so a
    caller changing one thing about the overlay composes from here rather than
    re-deriving five fields. The backdrop's default has no counterpart on
    purpose: it consists only of the fields {!val-view} forces back over any
    override, so there is nothing to compose with. *)

(** {1 View} *)

val view : 'msg config -> 'msg Nopal_element.Element.t
(** Renders the modal. The backdrop carries the interaction anchor
    [data-action="modal-dismiss"] — its only clickable dismiss surface (there is
    no dedicated close button). This anchor is the E2E selector contract (RFC
    0112) and is asserted by [test_anchors.ml].

    Renders the modal dialog.

    When [open_ = false], returns [Element.empty].

    When [open_ = true], renders:
    {v
      Box [data-testid="modal-root"]
        +- Box [data-testid="modal-backdrop"; on_pointer_down=on_backdrop_click]
        |     (only when on_backdrop_click is set)
        +- Column [role="dialog"; aria-modal="true";
                   aria-labelledby=title_id;
                   data-testid="modal-dialog"]
              +- body
    v} *)

(** {1 Subscriptions} *)

val subscriptions : 'msg config -> 'msg Nopal_mvu.Sub.t
(** When [open_ = false], returns [Sub.none]. When [open_ = true], returns
    [Sub.on_key] keyed ["modal-escape"] that intercepts bare Escape, dispatching
    [on_close] and preventing default. All other keys are ignored. *)

(** {1 Focus cycling} *)

val next_focus :
  focusable_ids:string list -> current:string -> key:string -> string option
(** Pure helper for Tab cycling within a modal.
    [next_focus ~focusable_ids ~current ~key] returns:
    - [key = "Tab"]: ID of the next element after [current], wrapping from last
      to first
    - [key = "Shift+Tab"]: ID of the previous element before [current], wrapping
      from first to last
    - Other keys: [None]

    Returns [None] if [current] is not in [focusable_ids] or the list is empty.
*)

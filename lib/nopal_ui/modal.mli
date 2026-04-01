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
(** Override the dialog container style. *)

val with_backdrop_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** Override the backdrop overlay style. *)

val with_interaction : Nopal_style.Interaction.t -> 'msg config -> 'msg config
(** Override hover/pressed/focused interaction on the dialog container. *)

val with_attrs : (string * string) list -> 'msg config -> 'msg config
(** Additional attributes on the dialog element. User attrs override internal
    ARIA attrs on conflict (last-writer-wins). *)

(** {1 View} *)

val view : 'msg config -> 'msg Nopal_element.Element.t
(** Renders the modal dialog.

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
    [Sub.on_keydown_prevent] keyed ["modal-escape"] that intercepts Escape ->
    [Some (on_close, true)]. All other keys are ignored ([None]). *)

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

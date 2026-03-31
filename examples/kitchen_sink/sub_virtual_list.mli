(** Virtual list kitchen sink subapp.

    Demonstrates [Element.virtual_list] with 10,000 items, showing current
    scroll offset and visible range. *)

type model = { scroll_offset : float; visible_first : int; visible_last : int }
(** The subapp model. Tracks scroll position and visible range. *)

type msg =
  | Scrolled of float
      (** Fired when the user scrolls the virtual list. Carries the new
          [scrollTop] offset. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** Initial model and command. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** Update function. [Scrolled offset] recomputes the visible range. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** View function. Renders a 10,000-item virtual list with scroll offset and
    visible range displayed above. *)

val subscriptions : model -> msg Nopal_mvu.Sub.t
(** Subscriptions. Currently none. *)

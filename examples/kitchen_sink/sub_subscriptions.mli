(** Subscriptions kitchen sink subapp.

    The living reference for the five built-in subscriptions implemented in the
    web interpreter (RFC 0118, REQ-F3): a live [every] timer behind a toggle, a
    window-resize readout ([on_resize]), a document-visibility flag
    ([on_visibility_change]), and a key-capture demo ([on_keydown]). Toggling
    the timer adds/removes its key from {!subscriptions}, which is what the
    runtime diff keys the [setInterval] lifecycle on. *)

type model = {
  timer_on : bool;  (** whether the live [every] timer is subscribed *)
  ticks : int;  (** number of timer ticks observed since mount *)
  last_size : (int * int) option;  (** most recent window resize dimensions *)
  visible : bool;  (** document visibility from [on_visibility_change] *)
  last_key : string option;  (** most recently captured key from [on_keydown] *)
}
(** The subapp model — one field per built-in subscription's last observation,
    plus the [timer_on] toggle that gates the timer subscription. *)

type msg =
  | ToggleTimer  (** flip whether the [every] timer is subscribed *)
  | Tick  (** one timer fire *)
  | Resized of int * int  (** window resized to width × height *)
  | VisibilityChanged of bool  (** document became visible ([true]) or hidden *)
  | KeyCaptured of string  (** a key was pressed *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** Initial model: timer off, zero ticks, document visible, no resize or key
    observed yet. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** - [ToggleTimer] flips [timer_on].
    - [Tick] increments [ticks].
    - [Resized (w, h)] records the new dimensions.
    - [VisibilityChanged v] records visibility.
    - [KeyCaptured k] records the key. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** Renders the timer toggle, tick count, resize/visibility/key readouts. *)

val subscriptions : model -> msg Nopal_mvu.Sub.t
(** Always subscribes resize, visibility, and key-capture; adds the [every]
    timer only when [timer_on], so the timer key appears in the tree exactly
    when the timer is enabled. *)

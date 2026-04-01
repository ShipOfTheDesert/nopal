(** Modal kitchen sink subapp.

    Demonstrates [Modal] dialog with "Open Modal" button, two inputs and a close
    button inside the dialog, Escape-key close, Tab focus cycling, and backdrop
    click-to-close. *)

type model = { open_ : bool; focused : string }
(** The subapp model. [open_] tracks dialog visibility. [focused] holds the ID
    of the currently focused element inside the modal. *)

type msg =
  | Open
  | Close
  | FocusChanged of string
  | TabCycled of string  (** Messages for the modal demo. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** Initial model and command. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** Update function.
    - [Open] sets [open_ = true] and focuses the first focusable element.
    - [Close] sets [open_ = false].
    - [FocusChanged id] updates [focused].
    - [TabCycled id] updates [focused] and issues [Cmd.focus]. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** View function. Renders an "Open Modal" button and the modal dialog. *)

val subscriptions : model -> msg Nopal_mvu.Sub.t
(** Subscriptions. Wires [Modal.subscriptions] for Escape and
    [Sub.on_keydown_prevent] for Tab/Shift+Tab focus trapping when open. *)

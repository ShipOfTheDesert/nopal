(** Toast kitchen sink subapp.

    Demonstrates [Toast] notifications with info, success, warning, and error
    variants, each auto-dismissing after a timeout. *)

type model = { toasts : Nopal_ui.Toast.toast list; next_id : int }
(** The subapp model. [toasts] holds the active toast list. [next_id] is a
    monotonic counter used to generate unique toast identifiers. *)

type msg =
  | ShowInfo
  | ShowSuccess
  | ShowWarning
  | ShowError
  | Dismiss of string  (** Messages for the toast demo. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** Initial model and command. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** Update function. [Show*] variants add a toast of the corresponding severity.
    [Dismiss id] removes the toast with the given identifier. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** View function. Renders trigger buttons for each toast variant and the active
    toast container. *)

val subscriptions : model -> msg Nopal_mvu.Sub.t
(** Subscriptions. Currently none. *)

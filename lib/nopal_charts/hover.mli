(** Shared hover state for chart interactivity.

    The application model stores [Hover.t option]. Charts receive it as a
    parameter and emit it via [on_hover]. *)

type t = { index : int; series : int; cursor_x : float; cursor_y : float }

val equal : t -> t -> bool
(** Structural equality for hover state. *)

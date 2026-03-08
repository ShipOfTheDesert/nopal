(** Counter example — minimal MVU application.

    Demonstrates the core MVU loop with a non-negative integer counter. The
    model invariant [count >= 0] is enforced by {!update}. *)

type model = { count : int }
(** The application state. [count] is always non-negative. *)

type msg =
  | Increment
  | Decrement
  | Reset  (** Messages the counter can receive. *)

include Nopal_mvu.App.S with type model := model and type msg := msg

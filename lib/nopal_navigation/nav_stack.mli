type 'screen t
(** A non-empty stack of application-defined screens. The type guarantees a
    current (top) screen always exists; there is no empty value. The [pop]
    operation is total — popping a stack holding only its root is a no-op. *)

val create : 'screen -> 'screen t
(** [create root] is a stack containing only [root]; [root] is the current
    screen and [can_pop] is [false]. *)

val push : 'screen -> 'screen t -> 'screen t
(** [push s t] makes [s] the current screen, with the prior current screen one
    level below it. *)

val pop : 'screen t -> 'screen t
(** [pop t] removes the current screen, making the screen below it current. If
    [t] holds only its root, [pop t] returns [t] unchanged — never an error,
    never an absent value (Decision 1, REQ-N2). *)

val current : 'screen t -> 'screen
(** The top screen. Total — always defined. *)

val depth : 'screen t -> int
(** Number of screens, always >= 1. *)

val can_pop : 'screen t -> bool
(** [true] iff [depth t > 1], i.e. a [pop] would change the stack. This is the
    predicate back-button UIs check before offering "back". *)

val screens : 'screen t -> 'screen list
(** All screens, root first, current last. Always non-empty. *)

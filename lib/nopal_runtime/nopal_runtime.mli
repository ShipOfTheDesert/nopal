(** Nopal Runtime — platform-agnostic MVU loop with Lwd reactivity.

    This package wires {!Nopal_mvu.App.S} modules to Lwd's reactive primitives.
    Backends subscribe to the reactive element tree and render it to their
    target platform. *)

module Sub_manager = Sub_manager
(** Subscription lifecycle manager. *)

module Runtime = Runtime
(** MVU runtime functor. *)

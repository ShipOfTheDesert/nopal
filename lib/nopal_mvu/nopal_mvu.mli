(** Nopal MVU — Model-View-Update architecture core.

    This package defines the MVU runtime contract: [Cmd.t] for commands, [Sub.t]
    for subscriptions, and [App.S] for the application signature. It has zero
    platform dependencies and compiles on native OCaml. *)

module Cmd = Cmd
module Sub = Sub
module App = App

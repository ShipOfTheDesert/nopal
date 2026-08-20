(** Nopal MVU — Model-View-Update architecture core.

    This package defines the MVU runtime contract: [Cmd.t] for commands, [Sub.t]
    for subscriptions, [App.S] for the application signature, [Task.t] for
    composable async operations, and [Key_chord] for the modifier-folded key
    string a keydown or keyup subscription handler receives. It has zero
    platform dependencies and compiles on native OCaml. *)

module Cmd = Cmd
module Sub = Sub
module App = App
module Task = Task
module Key_chord = Key_chord

(** Chart benchmarks — measures rendering performance of chart extensions. *)

type msg
type model

val init : unit -> model * msg Nopal_mvu.Cmd.t
val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
val view : model -> msg Nopal_element.Element.t
val subscriptions : model -> msg Nopal_mvu.Sub.t

(** Virtual list benchmark app — 10,000-item virtual list for measuring initial
    render time and scroll performance. *)

type model
type msg = Scrolled of float

val init : unit -> model * msg Nopal_mvu.Cmd.t
val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
val subscriptions : model -> msg Nopal_mvu.Sub.t

(** The MVU application signature. *)

module type S = sig
  type model
  type msg

  val init : unit -> model * msg Cmd.t
  val update : model -> msg -> model * msg Cmd.t
  val view : model -> msg Nopal_element.Element.t
  val subscriptions : model -> msg Sub.t
end

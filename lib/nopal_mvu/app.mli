(** The MVU application signature. *)

module type S = sig
  type model
  type msg

  val init : unit -> model * msg Cmd.t
  val update : model -> msg -> model * msg Cmd.t
  val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t

  val subscriptions : model -> msg Sub.t
  (** The set of active event sources, as a pure function of the model. The
      runtime re-evaluates this and diffs the result only when the model may
      have changed (once per dispatch-loop iteration), never per render frame —
      so a subscription that must come and go with runtime state expresses that
      through the model (e.g. add/remove an atom, or change its key), not
      through transient state invisible to the model. *)
end

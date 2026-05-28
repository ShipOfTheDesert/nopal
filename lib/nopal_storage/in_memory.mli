(** In-memory storage backend for native tests (REQ-F3). *)

(** Generative: each application of [Make] yields an isolated store whose
    [Task.t]s resolve synchronously. Native-clean — no browser or OS deps. *)
module Make () : sig
  include Storage_intf.S

  val reset : unit -> unit
  (** [reset ()] empties the store, for test isolation. *)
end

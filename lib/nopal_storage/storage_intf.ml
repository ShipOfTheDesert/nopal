(* Shared error type and storage signature, kept in their own internal module so
   that [In_memory] and [With_codec] can both depend on them without forming a
   cycle with the top-level [Nopal_storage] module that re-exports them. This
   module carries no functions and is not part of the public surface. *)

type error =
  | Quota_exceeded of string
  | Permission_denied of string
  | Backend_unavailable of string
  | Backend_error of string

module type S = sig
  val get : string -> (string option, error) result Nopal_mvu.Task.t
  val set : key:string -> value:string -> (unit, error) result Nopal_mvu.Task.t
  val delete : string -> (unit, error) result Nopal_mvu.Task.t

  val keys :
    ?prefix:string -> unit -> (string list, error) result Nopal_mvu.Task.t

  val clear : unit -> (unit, error) result Nopal_mvu.Task.t
end

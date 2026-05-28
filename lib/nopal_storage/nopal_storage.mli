(** Backend-agnostic, asynchronous key-value storage.

    Application code targets {!S} unchanged on every platform; the concrete
    backend is supplied at the entry point through
    [Nopal_platform.Platform.S.storage]. Operations return {!Nopal_mvu.Task.t};
    the application lifts them into commands with [Cmd.task] from [update].

    {!S} is intentionally a pure [string]-to-[string] interface. Encryption,
    compression, and any other value transform are {e wrapper} concerns layered
    over {!S}, never backend concerns — so a backend never sees anything but
    opaque strings. *)

type error =
  | Quota_exceeded of string
  | Permission_denied of string
  | Backend_unavailable of string
  | Backend_error of string

val message : error -> string
(** Human-readable description of an [error], for display. *)

module type S = sig
  val get : string -> (string option, error) result Nopal_mvu.Task.t
  (** [get key] resolves [Ok (Some v)] when present, [Ok None] when absent. *)

  val set : key:string -> value:string -> (unit, error) result Nopal_mvu.Task.t
  (** [set ~key ~value] stores [value] under [key]. Labelled because both
      arguments are [string] (positional order would be ambiguous). *)

  val delete : string -> (unit, error) result Nopal_mvu.Task.t
  (** [delete key] removes [key]; deleting an absent key resolves [Ok ()]. *)

  val keys :
    ?prefix:string -> unit -> (string list, error) result Nopal_mvu.Task.t
  (** [keys ?prefix ()] lists stored keys, optionally restricted to those
      beginning with [prefix]. Order is unspecified. *)

  val clear : unit -> (unit, error) result Nopal_mvu.Task.t
  (** [clear ()] removes every key in {e this abstraction's own namespace only},
      never touching [Web.Storage]/[localStorage] or [Nopal_tauri.Store]. *)
end

(** Generative in-memory backend; each application gets an isolated store and
    [Task.t]s resolve synchronously. Native-clean. *)
module In_memory () : sig
  include S

  val reset : unit -> unit
  (** [reset ()] empties the store, for test isolation (REQ-F3). *)
end

(* [Store] is consumed only operationally (its values), never in the result
   types, so warning 67 cannot see the dependency; suppressed here. *)
module With_codec (Store : S) : sig
  type typed_error =
    | Storage of error  (** the backend failed *)
    | Decode of string  (** a value existed but failed to deserialise *)

  val get :
    string ->
    decode:(string -> ('a, string) result) ->
    ('a option, typed_error) result Nopal_mvu.Task.t
  (** Retrieves and decodes. [Ok None] when absent (decode not attempted);
      [Error (Decode msg)] when the stored string fails to decode;
      [Error (Storage e)] on backend failure. Never raises. *)

  val set :
    key:string ->
    value:'a ->
    encode:('a -> string) ->
    (unit, error) result Nopal_mvu.Task.t
  (** Encodes then stores. Encoding is total, so [set] surfaces only backend
      [error]s. *)
end
[@@warning "-67"]

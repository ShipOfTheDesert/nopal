(** Typed convenience wrapper over any {!Storage_intf.S} backend (REQ-F4).

    Stores and retrieves a domain value through application-supplied
    encode/decode functions, hiding the string conversion. *)

(* [Store] is consumed only operationally (its values), never in the result
   types, so warning 67 cannot see the dependency; suppressed here. *)
module Make (Store : Storage_intf.S) : sig
  type typed_error =
    | Storage of Storage_intf.error  (** the backend failed *)
    | Decode of string  (** a value existed but failed to deserialise *)

  val get :
    string ->
    decode:(string -> ('a, string) result) ->
    ('a option, typed_error) result Nopal_mvu.Task.t
  (** [get key ~decode] resolves [Ok None] when absent (decode not attempted),
      [Error (Decode msg)] when the stored string fails to decode, and
      [Error (Storage e)] on backend failure. Never raises. *)

  val set :
    key:string ->
    value:'a ->
    encode:('a -> string) ->
    (unit, Storage_intf.error) result Nopal_mvu.Task.t
  (** [set ~key ~value ~encode] encodes then stores. Encoding is total, so only
      backend errors can surface. *)
end
[@@warning "-67"]

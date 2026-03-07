(** Platform navigation signature.

    Each platform backend provides a module satisfying this signature.
    [nopal_web] provides [Platform_web]. Future backends (Tauri, native) provide
    their own implementations. Application code and [nopal_router] never call
    platform navigation directly — they go through [Router.t]. *)

module type S = sig
  val current_path : unit -> string
  val push_state : string -> unit
  val replace_state : string -> unit
  val back : unit -> unit
  val on_popstate : (string -> unit) -> unit -> unit
end

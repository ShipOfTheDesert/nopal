module type NAV = sig
  val current_path : unit -> string
  val push_state : string -> unit
  val replace_state : string -> unit
  val back : unit -> unit
  val on_popstate : (string -> unit) -> unit -> unit
end

module type S = sig
  include NAV

  val storage : (module Nopal_storage.S)
end

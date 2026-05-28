(** Platform capability signatures.

    Each platform backend provides a module satisfying these signatures.
    [nopal_web] provides [Platform_web]; [nopal_tauri] provides
    [Platform_tauri]. Application code and [nopal_platform] never call platform
    navigation directly — they go through [Router.t]. *)

(** Navigation capability. Consumed by {!Router}. *)
module type NAV = sig
  val current_path : unit -> string
  val push_state : string -> unit
  val replace_state : string -> unit
  val back : unit -> unit
  val on_popstate : (string -> unit) -> unit -> unit
end

(** The full platform-capability bundle a backend must satisfy. Phase 3 adds
    further capability fields here (filesystem, camera, notifications). *)
module type S = sig
  include NAV

  val storage : (module Nopal_storage.S)
end

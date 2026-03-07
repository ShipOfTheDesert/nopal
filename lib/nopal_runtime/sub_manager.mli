(** Subscription lifecycle manager.

    Tracks active subscriptions by key. Diffing a new subscription spec against
    the current set starts new subscriptions and stops removed ones. *)

type cleanup = unit -> unit
(** Teardown function for an active subscription. *)

type 'msg t
(** A mutable table of active subscriptions indexed by key. *)

val create : unit -> 'msg t
(** Create an empty subscription manager. *)

val diff : dispatch:('msg -> unit) -> 'msg Nopal_mvu.Sub.t -> 'msg t -> unit
(** [diff ~dispatch new_subs mgr] compares [new_subs] against currently active
    subscriptions. Starts subscriptions whose keys are new, stops subscriptions
    whose keys disappeared, leaves stable keys untouched.

    Each new subscription's setup function is called with [dispatch] and the
    returned cleanup is stored.

    Only {!Nopal_mvu.Sub.custom} subscriptions are managed here. Built-in
    subscription types ([every], [on_keydown], [on_keyup], [on_resize],
    [on_visibility_change]) require platform-specific interpreters (e.g.
    [setInterval], DOM event listeners) and are handled by the platform backend
    ([nopal_web], etc.), not the platform-agnostic runtime.

    Complexity is O(n * m) where n = old keys and m = new keys, using linear
    scans. This is appropriate for typical subscription counts (< 20 keys). If
    subscription counts grow significantly, replace with a set-based diff. *)

val stop_all : 'msg t -> unit
(** Stop every active subscription by calling its cleanup function and clearing
    the table. *)

val active_keys : 'msg t -> string list
(** Return the keys of all currently active subscriptions, sorted
    alphabetically. For testing. *)

(** Subscription lifecycle manager.

    Tracks active subscriptions by key. Diffing a new subscription spec against
    the current set starts new subscriptions and stops removed ones. *)

type cleanup = unit -> unit
(** Teardown function for an active subscription. *)

type 'msg t
(** A mutable table of active subscriptions indexed by key. *)

val create : unit -> 'msg t
(** Create an empty subscription manager. *)

val diff :
  ?on_error:(string -> unit) ->
  interpret:('msg Nopal_mvu.Sub.atom -> (cleanup, string) result) ->
  'msg Nopal_mvu.Sub.t ->
  'msg t ->
  unit
(** [diff ~interpret new_subs mgr] normalizes [new_subs] to atoms
    ({!Nopal_mvu.Sub.atoms}) and reconciles them against the active set: keys
    that are new are set up via [interpret], keys that disappeared are cleaned
    up exactly once, and stable keys are left untouched.

    [interpret atom] sets up one atom — registering whatever platform resource
    it needs and wiring dispatch into its handlers — and returns either its
    teardown [cleanup] or [Error reason]. The backend matches [atom]
    exhaustively (no catch-all, repo rule), so adding an {!Nopal_mvu.Sub.atom}
    constructor is a compile error in every backend until handled, never a
    silent no-op (REQ-F3).

    Failure policy (REQ-F4):
    - [interpret] returns [Error]: reported via [on_error] and the key is NOT
      registered, so the next diff retries it.
    - the same key appears twice in one tree: the first occurrence wins, each
      later duplicate is reported via [on_error] and skipped.

    [on_error] defaults to a no-op; the runtime passes its own error sink so
    setup failures and duplicates surface through the same channel as other
    runtime errors. The firing seam (the {!Nopal_runtime.Telemetry}
    [Subscription] event recorded before each dispatched message) is woven into
    the dispatch the runtime hands [interpret], not into this function — [diff]
    owns key lifecycle and failure policy only.

    Complexity is O(n * m) where n = old keys and m = new keys, using linear
    scans. This is appropriate for typical subscription counts (< 20 keys). If
    subscription counts grow significantly, replace with a set-based diff. *)

val stop_all : 'msg t -> unit
(** Stop every active subscription by calling its cleanup function and clearing
    the table. *)

val active_keys : 'msg t -> string list
(** Return the keys of all currently active subscriptions, sorted
    alphabetically. For testing. *)

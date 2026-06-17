(** Subscriptions — ongoing event sources managed by the runtime. *)

type 'msg dispatch = 'msg -> unit
(** A function that sends a message to the MVU runtime for processing. *)

type 'msg t
(** Abstract subscription type. Application code cannot pattern-match on this.
*)

val none : 'msg t
(** No subscription. *)

val batch : 'msg t list -> 'msg t
(** Combine multiple subscriptions. *)

val every : string -> int -> (unit -> 'msg) -> 'msg t
(** [every key ms f] fires [f ()] every [ms] milliseconds. The [key] is used for
    diffing between renders. *)

val on_keydown : string -> (string -> ('msg * bool) option) -> 'msg t
(** [on_keydown key f] subscribes to global keydown events. [f] receives the key
    string and returns:
    - [Some (msg, true)] to dispatch [msg] and call [preventDefault]
    - [Some (msg, false)] to dispatch [msg] without preventing default
    - [None] to ignore the key entirely

    This unifies the former plain-keydown and preventDefault-capable forms into
    a single constructor. *)

val on_key : string -> key:string -> prevent:bool -> 'msg -> 'msg t
(** [on_key sub_key ~key ~prevent msg] is a convenience over {!on_keydown} for
    the match-one-key case: it dispatches [msg] (preventing default when
    [prevent]) on the keydown of [key] and ignores every other key. [prevent] is
    required — there is no behavioural default. *)

val on_keyup : string -> (string -> 'msg option) -> 'msg t
(** [on_keyup key f] subscribes to global keyup events. [f] returns [None] to
    ignore the key. There is no prevent flag — keyup has no default action to
    prevent. *)

val on_resize : string -> (int -> int -> 'msg) -> 'msg t
(** [on_resize key f] subscribes to window resize events. [f] receives width and
    height. *)

val on_visibility_change : string -> (bool -> 'msg) -> 'msg t
(** [on_visibility_change key f] subscribes to document visibility changes. [f]
    receives [true] when visible. *)

val on_viewport_change : string -> (Nopal_element.Viewport.t -> 'msg) -> 'msg t
(** [on_viewport_change key f] subscribes to viewport changes. [f] receives the
    new viewport. *)

val custom : string -> ('msg dispatch -> unit -> unit) -> 'msg t
(** [custom key setup] creates an arbitrary subscription. [setup] receives a
    dispatch function and returns a cleanup function. *)

val keys : 'msg t -> string list
(** Extract all identity keys from a subscription tree. Used by the runtime for
    subscription diffing (REQ-F14). *)

val map : ('a -> 'b) -> 'a t -> 'b t
(** Transform the message type of a subscription. *)

val describe : 'msg t -> string
(** A stable label naming the subscription's top-level constructor ([none] |
    [batch] | [every] | [on_keydown] | [on_keyup] | [on_resize] |
    [on_visibility_change] | [on_viewport_change] | [custom]), for telemetry
    [Subscription] events. Total over the variant. *)

(** A normalized subscription leaf. [atoms] flattens a subscription tree into
    these, so backends interpret one exhaustive variant instead of walking the
    [t] tree per constructor. Adding a constructor here breaks every backend's
    match until it is handled. Keydown unifies the plain and preventDefault
    forms: [handler] returns [Some (msg, prevent)] to dispatch (preventing
    default when [prevent]) or [None] to ignore the key. *)
type 'msg atom =
  | Every of { key : string; interval_ms : int; tick : unit -> 'msg }
  | Keydown of { key : string; handler : string -> ('msg * bool) option }
  | Keyup of { key : string; handler : string -> 'msg option }
  | Resize of { key : string; handler : int -> int -> 'msg }
  | Visibility of { key : string; handler : bool -> 'msg }
  | Viewport of { key : string; handler : Nopal_element.Viewport.t -> 'msg }
  | Custom of { key : string; setup : 'msg dispatch -> unit -> unit }

val atom_key : 'msg atom -> string
(** The identity key of an atom, used by the runtime's subscription diff to add,
    keep, and remove subscriptions as the model changes (the diff runs once per
    dispatch-loop iteration, not per frame — see
    {!Nopal_mvu.App.S.subscriptions}). Total over the variant. *)

val describe_atom : 'msg atom -> string
(** A stable label naming an atom's constructor ([every] | [keydown] | [keyup] |
    [resize] | [visibility] | [viewport] | [custom]), for telemetry
    [Subscription] events recorded at the firing seam. Total over the variant.
    The atom-side counterpart to {!describe}. *)

val atoms : 'msg t -> 'msg atom list
(** [atoms sub] normalizes a subscription tree into a flat list of atoms,
    flattening [batch] nodes (depth-first, order-preserving) and carrying any
    [map] transformations into the atom handlers. Keys are not deduplicated —
    that policy lives in the runtime diff, not here. This is the sole
    interpreter over the opaque {!t}: backends and tests consume subscriptions
    through it. *)

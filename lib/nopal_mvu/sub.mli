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

val on_keydown : string -> (string -> 'msg) -> 'msg t
(** [on_keydown key f] subscribes to global keydown events. [f] receives the key
    string. *)

val on_keyup : string -> (string -> 'msg) -> 'msg t
(** [on_keyup key f] subscribes to global keyup events. *)

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

val extract_every : 'msg t -> (int * (unit -> 'msg)) option
(** [extract_every sub] extracts the interval and callback from an [every]
    subscription. Returns [None] if [sub] is not an [every]. *)

val extract_on_keydown : 'msg t -> (string -> 'msg) option
(** [extract_on_keydown sub] extracts the callback from an [on_keydown]
    subscription. Returns [None] if [sub] is not an [on_keydown]. *)

val extract_on_keyup : 'msg t -> (string -> 'msg) option
(** [extract_on_keyup sub] extracts the callback from an [on_keyup]
    subscription. Returns [None] if [sub] is not an [on_keyup]. *)

val extract_on_resize : 'msg t -> (int -> int -> 'msg) option
(** [extract_on_resize sub] extracts the callback from an [on_resize]
    subscription. Returns [None] if [sub] is not an [on_resize]. *)

val extract_on_visibility_change : 'msg t -> (bool -> 'msg) option
(** [extract_on_visibility_change sub] extracts the callback from an
    [on_visibility_change] subscription. Returns [None] if [sub] is not an
    [on_visibility_change]. *)

val extract_on_viewport_change :
  'msg t -> (Nopal_element.Viewport.t -> 'msg) option
(** [extract_on_viewport_change sub] extracts the callback from an
    [on_viewport_change] subscription. Returns [None] if [sub] is not an
    [on_viewport_change]. *)

val extract_custom : 'msg t -> ('msg dispatch -> unit -> unit) option
(** [extract_custom sub] extracts the setup function from a [custom]
    subscription. Returns [None] if [sub] is not a [custom]. *)

val extract_customs : 'msg t -> (string * ('msg dispatch -> unit -> unit)) list
(** [extract_customs sub] flattens [sub] and returns all [custom] entries as
    [(key, setup)] pairs. Traverses [batch] nodes recursively. *)

val extract_on_viewport_changes :
  'msg t -> (string * (Nopal_element.Viewport.t -> 'msg)) list
(** [extract_on_viewport_changes sub] flattens [sub] and returns all
    [on_viewport_change] entries as [(key, f)] pairs. Traverses [batch] nodes
    recursively. *)

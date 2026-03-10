type t

val create : unit -> t
(** Creates the stylesheet manager. Inserts a single [<style>] element into the
    document [<head>] that will hold all base-style and interaction CSS rules.
*)

type base_id
(** Opaque identifier for a base-style class rule. Each interactive element gets
    its own [base_id]. Becomes invalid after {!remove_base}. *)

type interaction_id
(** Opaque identifier for a shared interaction-style class rule set. Multiple
    elements with structurally identical interaction styles share the same
    [interaction_id]. Reference-counted — rules are removed from the stylesheet
    only when the last reference is released via {!remove_interaction}. *)

val inject_base : t -> css_props:Style_css.css_prop list -> base_id
(** Generates a unique class name, creates a CSS class rule from [css_props],
    and inserts it into the stylesheet. The returned [base_id] should be added
    to the DOM element's classList via {!base_class_name}. *)

val inject_interaction :
  t -> interaction:Nopal_style.Interaction.t -> (interaction_id, string) result
(** If an identical interaction style is already in the cache (compared by
    generated CSS text), increments its reference count and returns the existing
    [interaction_id]. Otherwise generates a new class name, inserts pseudo-class
    rules ([:hover], [:focus-visible], [:active]) into the stylesheet, and
    caches the entry. Returns [Error] if the interaction has no states
    ([has_any] is false). Precedence is encoded by rule order: hover first, then
    focused, then pressed. *)

val base_class_name : base_id -> string
(** The CSS class name to add to the DOM element for base styles. *)

val interaction_class_name : interaction_id -> string
(** The CSS class name to add to the DOM element for interaction styles. *)

val remove_base : t -> base_id -> unit
(** Removes the base-style class rule from the stylesheet and updates rule
    indices. Safe to call multiple times — subsequent calls are no-ops. *)

val remove_interaction : t -> interaction_id -> unit
(** Decrements the reference count for the interaction entry. When it reaches
    zero, removes all pseudo-class rules from the stylesheet, removes the entry
    from the cache, and updates rule indices. Safe to call multiple times after
    the refcount reaches zero. *)

type t

val create : unit -> t
(** Creates the stylesheet manager. Interaction rules are injected as individual
    [<style>] elements in the document [<head>]. *)

type class_id
(** Opaque identifier for an injected interaction stylesheet rule. A [class_id]
    becomes invalid after {!remove} is called on it — using an invalidated
    [class_id] with {!class_name} or {!remove} is safe (returns the original
    name or is a no-op respectively) but the rules are no longer in the DOM. Do
    not retain [class_id] values beyond the lifetime of the element they were
    injected for. *)

val inject :
  t -> interaction:Nopal_style.Interaction.t -> (class_id, string) result
(** Generates a unique class name, creates a [<style>] element with [:hover],
    [:active], and/or [:focus-visible] rules, and appends it to [<head>].
    Returns [Error] only if the interaction has no states ([has_any] is false).
    Precedence is encoded by rule order: hover, then focused, then pressed
    (later rules win for equal specificity). *)

val class_name : class_id -> string
(** The CSS class name string to add to the DOM element. *)

val remove : t -> class_id -> unit
(** Removes the [<style>] element for [class_id] from the document head. Called
    during reconciliation when an element's interaction changes or is removed.
    Safe to call multiple times on the same [class_id] — subsequent calls after
    the first are no-ops. *)

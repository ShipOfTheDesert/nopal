type t

val create : unit -> t
(** Creates the stylesheet manager. Inserts a single [<style>] element into the
    document [<head>] that will hold all base-style and interaction CSS rules.

    The sheet opens with one heading reset,
    [:where([data-nopal-heading]){margin:0;font-size:inherit;font-weight:inherit}],
    so a heading Nopal renders carries none of the user agent's heading margin,
    size or weight. It is scoped to the [data-nopal-heading] marker the renderer
    writes on its own headings, so headings on the host page that Nopal did not
    render are left alone. The whole selector sits inside [:where], which gives
    the rule zero specificity: it beats only the user agent's defaults, and a
    heading's own style beats it whether that style is written inline or as a
    class rule. Each sheet carries its own copy, so a second mount adds a
    second, identical reset. The reset is never removed.

    The heading reset is followed by a drawn-checkbox reset,
    [:where([data-nopal-drawn-checkbox]){appearance:none;margin:0}], on the same
    terms: scoped to the marker the renderer writes on a checkbox whose
    appearance is drawn, and of zero specificity, so the checkbox's own base
    rule beats it. It removes the platform's checkbox drawing, so the base style
    paints the box, and the platform's margin, which [appearance:none] alone
    leaves in place and [Style.layout] cannot remove. A native checkbox carries
    no marker and keeps both.

    Then comes a forced-colours fallback:
    [@media (forced-colors: active){[data-nopal-drawn-checkbox]{appearance:auto}
     [data-nopal-drawn-checkbox]:checked{background-image:none !important}}].
    Where the user has forced a system palette, a drawn checkbox becomes the
    platform's again and its ticked state paints no tick image, so the platform
    checkbox shows the ticked state in system colours. The removal is
    [!important] because it must beat the ticked rule, whose specificity is
    (0,3,0) against this selector's (0,2,0), and a caller's [style] attribute
    (see {!Style_css.ticked_rule}).

    Last comes a hide rule, [:where([data-nopal-visually-hidden])] inside
    [@media not (forced-colors: active)], declaring [position:absolute],
    [width:1px], [height:1px], [margin:-1px], [overflow:hidden],
    [clip-path:inset(50%)], [white-space:nowrap], [border:0] and [padding:0]. It
    is scoped to the marker the renderer writes on a visually hidden radio, and
    clips it to a 1px box taken out of the flow, so it is not painted and takes
    no layout space, while it stays focusable, in its group and in the
    accessibility tree: nothing in it is [display], [visibility] or
    [aria-hidden]. With no offsets the box stays at its static position, so
    focusing the radio never scrolls the page. The rule is of zero specificity,
    so a radio's own style beats it, inline or as a class rule. Where the user
    has forced a system palette the media query does not match and the rule does
    not apply, so the radio is the platform's again, drawn in system colours and
    taking its layout space. That reveal declares nothing, which is why it needs
    no [!important]: there is no hiding declaration left to beat. Per Media
    Queries Level 4 (not observed on such an engine): an engine that cannot
    evaluate [forced-colors] does not match the query either, and shows the
    radio.

    The resets and the fallback are the only user-agent defaults Nopal
    neutralises: [Style.layout] has no margin, so a heading's or a checkbox's
    browser margin could not otherwise be removed, while an unstyled button or
    link still shows the browser's defaults. The hide rule neutralises no
    default; it acts only on a radio that asked to be hidden. All four rules are
    installed once per sheet and never removed. *)

val heading_marker : string
(** The attribute name the heading reset selects on. The renderer writes it,
    with an empty value, on every heading it renders. *)

val drawn_checkbox_marker : string
(** The attribute name the drawn-checkbox reset and the forced-colours fallback
    select on. The renderer writes it, with an empty value, on every checkbox
    whose appearance is drawn, over any pair of the same name in the element's
    attribute list. *)

val visually_hidden_marker : string
(** The attribute name the hide rule selects on. The renderer writes it, with an
    empty value, on every radio whose presentation is visually hidden, over any
    pair of the same name in the element's attribute list. A visible radio
    carries none, so a pair of that name in its attribute list is left standing.
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
    rules ([:hover], [:focus-within], [:focus-visible], [:active]) into the
    stylesheet, and caches the entry. Returns [Error] if the interaction has no
    states ([has_any] is false). Precedence is encoded by rule order: hover
    first, then focused_within, then focused, then pressed. *)

type ticked_id
(** Opaque identifier for a shared ticked-state rule. Drawn checkboxes with
    structurally identical ticked styles and tick colours share one [ticked_id].
    Reference-counted on the same terms as {!interaction_id}. *)

val inject_ticked :
  t -> checked:Nopal_style.Style.t -> mark:Nopal_style.Color.t -> ticked_id
(** If an identical ticked rule is already in the cache (compared by generated
    CSS text), increments its reference count and returns the existing
    [ticked_id]. Otherwise generates a class name and inserts
    {!Style_css.ticked_rule} for [checked], carrying {!Tick_image.css_url}
    [mark] as the tick. The rule is appended, so on a checkbox that injects its
    interaction rules first it also follows them in the sheet; its specificity,
    not its position, is what makes it win. *)

val ticked_class_name : ticked_id -> string
(** The CSS class name to add to the DOM element for its ticked rule. *)

val remove_ticked : t -> ticked_id -> unit
(** Releases one reference, removing the rule when the last is released, on the
    same terms as {!remove_interaction}. *)

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

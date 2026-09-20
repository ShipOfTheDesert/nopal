(** A text node whose text style is taken from the style of the element that
    wraps it.

    Every labelled control in this library renders its label, and its error
    message, as a text node inside a box the caller can restyle. The box takes
    the whole {!Nopal_style.Style.t}; the text node has to be handed that
    style's [text] component explicitly, because [Nopal_test]'s renderer has no
    inheritance — a text node styled only by its parent reads as unstyled
    structurally while rendering correctly in a browser — the failure shape the
    attribute-precedence work removed from the two renderers, and the one this
    module keeps out of the component layer. This module is the one place that
    hand-off is written. *)

val of_text_style :
  text_style:Nopal_style.Text.t option -> string -> 'msg Nopal_element.Element.t
(** [of_text_style ~text_style text] is the text node for [text], taking the
    text style directly rather than lifting it out of a whole
    {!Nopal_style.Style.t}.

    It is the arm {!of_style} resolves to, and it is what a component whose
    override is the typography alone exposes: a setter that accepted a whole
    style would take four components of which three reach nothing. [None] is
    {!Nopal_element.Element.text}; [Some t] is
    {!Nopal_element.Element.styled_text} carrying [t], whatever [t]'s own fields
    say. *)

val of_style :
  style:Nopal_style.Style.t option -> string -> 'msg Nopal_element.Element.t
(** [of_style ~style text] is the text node for [text].

    With [style = None] it is {!Nopal_element.Element.text}: a text node with no
    text style at all, byte for byte what a control with no style override has
    always rendered. With [style = Some s] it is
    {!Nopal_element.Element.styled_text} carrying [s.text].

    Which arm applies is decided by the option alone and never by the contents
    of [s.text]: [Some] with an all-[None] text component still produces a
    styled text node, so adding a style override never leaves the node looking
    unstyled. *)

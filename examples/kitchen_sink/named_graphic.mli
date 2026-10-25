(** The one way the kitchen sink names a graphic from a literal.

    Only a blank name is refused, and a refusal is shown where the graphic would
    have been rather than drawn as decorative, which would hide the mistake from
    everyone. *)

val refusal_message : string -> string
(** [refusal_message input] is the text shown for a refused blank [input]. *)

val named_graphic :
  string ->
  (Nopal_element.Graphic_name.t -> 'msg Nopal_element.Element.t) ->
  'msg Nopal_element.Element.t
(** [named_graphic label graphic] is [graphic name] when [label] makes a name,
    and a text element carrying {!refusal_message} otherwise. *)

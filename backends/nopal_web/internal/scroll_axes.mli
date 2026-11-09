(** Which physical scroll axes of a container run reversed.

    A scroll axis is reversed when its offset runs from [-max] to [0] instead of
    from [0] to [max]: the container starts at its far edge and scrolls towards
    negative offsets. Offset arithmetic that clamps to [[0, max]] drags such an
    axis back to its start edge, so a reveal leaves a reversed axis untouched.

    Reversal follows from the container's computed [writing-mode] and
    [direction]. Both are decoded once into the variants below, and
    {!reversed_axes} reads the answer from them. Nothing here touches the DOM:
    the caller reads the two computed strings, and no offset is ever written to
    find out. *)

(** A computed [writing-mode] value. *)
type writing_mode =
  | Horizontal_tb  (** [horizontal-tb] *)
  | Vertical_rl  (** [vertical-rl] *)
  | Vertical_lr  (** [vertical-lr] *)
  | Sideways_rl  (** [sideways-rl] *)
  | Sideways_lr  (** [sideways-lr] *)
  | Other_writing_mode
      (** Any other string, including the empty string a computed style yields
          for an element outside the document. *)

(** A computed [direction] value. *)
type direction =
  | Ltr  (** [ltr] *)
  | Rtl  (** [rtl] *)
  | Other_direction  (** Any other string, including the empty string. *)

(** Whether one axis's scroll offset runs forward, [[0, max]], or reversed,
    [[-max, 0]]. An unknown value, including the [""] a detached element or a
    null computed style yields, is reported as [Reversed] so that it is skipped.
*)
type orientation = Forward | Reversed

type axes = {
  x : orientation;  (** The horizontal axis: width and [scrollLeft]. *)
  y : orientation;  (** The vertical axis: height and [scrollTop]. *)
}
(** The orientation of each physical axis, decided independently. *)

val writing_mode_of_string : string -> writing_mode
(** [writing_mode_of_string s] decodes a computed [writing-mode] value. Only the
    exact lowercase keyword matches, which is how a computed style serialises
    it; anything else, a legacy alias or stray whitespace included, is
    [Other_writing_mode]. Total over every string. *)

val direction_of_string : string -> direction
(** [direction_of_string s] decodes a computed [direction] value. Only the exact
    lowercase keyword matches; anything else is [Other_direction]. Total over
    every string. *)

val reversed_axes : writing_mode -> direction -> axes
(** [reversed_axes writing_mode direction] is the orientation of each axis:

    {v
    writing-mode    direction: ltr   direction: rtl
    horizontal-tb   neither          x
    vertical-rl     x                x and y
    vertical-lr     neither          y
    sideways-rl     x                x and y
    sideways-lr     y                neither
    v}

    The table was observed in Chromium, by reading the scroll range each
    combination actually offers; other engines are assumed to agree.

    An unknown value on either side, [Other_writing_mode] or [Other_direction],
    marks both axes [Reversed], so a reveal leaves both alone rather than guess.
    Total. *)

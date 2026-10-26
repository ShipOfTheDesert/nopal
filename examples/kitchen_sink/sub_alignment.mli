(** Alignment on each axis — kitchen sink section.

    One row per value either axis accepts, each carrying a [data-testid] and
    preceded by a label naming it. Every row is a [row] with no padding and no
    border, an 8px gap, and three boxes 40px wide.

    - Main rows, [align-main-start], [align-main-center], [align-main-end] and
      [align-main-space-between], each set [main_align] to their value. Each is
      300px wide, so the boxes have room to move along it, and each box is 24px
      tall.
    - Cross rows, [align-cross-start], [align-cross-center], [align-cross-end]
      and [align-cross-stretch], each set [cross_align] to their value. Each is
      100px tall, so the boxes have room to move across it. In the start, center
      and end rows the boxes are 20px, 40px and 60px tall, so the three values
      place them differently. The stretch row's boxes declare no height, so the
      row's own height is the one they take. *)

val view : unit -> 'msg Nopal_element.Element.t
(** The section's body: the four main rows, then the four cross rows. *)

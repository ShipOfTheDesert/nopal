(** A [Fixed] size must not shrink — kitchen sink subapp.

    A flex item at the default shrink is squeezed below the size it declares as
    soon as a sibling wants more room than the container has, and an item with
    nothing in it collapses to its automatic minimum of zero and disappears
    outright. A [Fixed] size therefore has to hold on the axis its parent lays
    out along, while [Fill], [Fraction] and [Hug] keep giving way — [Fill]
    resolves two siblings to half each only by shrinking.

    Two demonstrations, one rule. The pair is a box declaring both a fixed width
    and a fixed height, next to a [Fill] sibling whose text holds a token with
    no break opportunity anywhere in it. One control stops the sibling's line
    breaking, which is what makes it demand far more room than the pair has; the
    other flips the pair's own axis, which moves the fixed box's main axis from
    its width to its height without the box's own style changing at all. The
    columns are a row of three boxes whose declared widths add up to more than
    the row's: they keep those widths and the row overflows, rather than the row
    quietly turning fluid.

    Nothing here is assertable from the element tree. Whether a declared size
    survived is a measurement of rendered geometry, so this section exists to be
    measured in a browser; the structural suite beside it pins only that the two
    controls reach the styles they claim to and that each fixture is still
    overconstrained enough for the measurement to mean anything. *)

val unbreakable_token : string
(** The part of the sibling's text that carries no break opportunity: no space,
    no hyphen, nothing a line may be divided at. It is what makes the sibling's
    minimum width a property of its content rather than of the layout.

    It is deliberately short. With the sibling allowed to wrap, its minimum
    width is this token, and it has to fit the room left beside the fixed box
    for the flexible half of the rule to be measurable at all; a token wider
    than that remainder would clamp the sibling at its own minimum and there
    would be nothing left to read. The long sentence around it is what supplies
    the pressure in the other direction, by refusing to break when wrapping is
    off. *)

type model = {
  sibling_wraps : bool;
      (** Whether the sibling's line may break. [false] is the reported shape:
          one unbroken line demanding several times the width the pair has. *)
  stacked : bool;
      (** Whether the pair lays its children down the page instead of across it.
          Flipping it moves which of the fixed box's two dimensions is the one
          at risk, and it does so without touching that box's own style. *)
}
(** The subapp model: two independent controls over one pair of boxes. Neither
    flag is a size — the sizes are fixed properties of the section, and a
    control that could change them would make the section's own claim
    unfalsifiable. *)

(** The subapp's messages. *)
type msg =
  | Wrap_toggled of bool
      (** Let the sibling's line break, or stop it breaking. *)
  | Stack_toggled of bool  (** Flip the pair's own axis. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** The reported shape: the sibling's line unbroken, and the pair laid out
    across the page. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** Sets one of the two flags. Nothing else happens: no size moves, and no
    command is produced. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** Renders the two controls, the pair, and the row of fixed columns. Every box
    a browser case measures carries a [data-testid], and neither the measured
    boxes nor the containers holding them carry padding or a border, so a
    measured bounding box is the declared size rather than the declared size
    plus trim. *)

(** Headings at every level — kitchen sink section.

    A heading's level is semantics and its look is its style, so this section
    shows the two apart. The body goes under a section titled at [H2] by its
    caller, and holds, in this order:

    - a chain of one heading per level from [H3] to [H6], each sized from one
      small type scale and reading ["Heading level three"] through
      ["Heading level six"];
    - an unstyled [H3] reading ["An unstyled heading"], carrying the
      [data-testid] [headings-unstyled], beside a plain text reading
      ["Plain text beside it"] in a box carrying [headings-plain-text]. Both sit
      in one row carrying [headings-unstyled-pair], so they inherit the same
      text properties, and nothing in the row has a style of its own;
    - an [H3] reading ["A styled heading"], carrying [headings-styled], whose
      base style sets a 1.5rem font size and which also has a hover state, so
      its style is applied as a class rule rather than inline.

    Every heading after the chain goes back up to [H3], so the section's outline
    skips no level on the way down. *)

val view : unit -> 'msg Nopal_element.Element.t
(** The section's body: the chain, the unstyled pair and the styled heading. *)

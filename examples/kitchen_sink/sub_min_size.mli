(** A floor of zero lets a scrolling descendant scroll — kitchen sink subapp.

    An element this framework lays out is an item of its container's layout, and
    the platform gives such an item an automatic minimum equal to its own
    content. An element holding a scrolling child therefore grows to fit that
    child rather than letting it scroll, and whatever follows it inside a
    container of a settled height is pushed out of that container. Declaring a
    floor of zero is what hands the overflow back to the scrolling descendant.

    The fixture is a bounded column of a settled height holding two children: a
    holding column wrapped around a scrolling pane whose content is taller than
    the room the bounded column can give it, and a band beneath that column.
    With no floor declared the holding column cannot be reduced below its own
    content, so it takes the whole fixture, the pane never scrolls, and the band
    is laid out past the bounded column's bottom edge. One control declares the
    floor at zero on the holding column; that column is then free to be reduced,
    the pane scrolls, and the band comes back inside.

    The floor belongs on the holding column and on neither of the other two, and
    both exclusions were measured rather than assumed. OBSERVED, headless
    Chromium, 2026-09-15: with the pane placed directly inside the bounded
    column and the floor declared on that column, the band's bottom edge still
    measured 300 against the column's 208 and the pane still reported a
    [scrollHeight] and a [clientHeight] of 260 apiece — the same numbers the
    same fixture gives with no floor declared at all. The pane is a scrolling
    container, so its own automatic minimum already resolves to zero and a floor
    there changes nothing. The bounded column declares a height of its own,
    which already caps its automatic minimum, so a floor there changes nothing
    either. That is why the fixture has three levels rather than two: with the
    pane placed directly inside the bounded column there is no defect left to
    show.

    Nothing here is assertable from the element tree. Whether the band left its
    container and whether the pane scrolls are measurements of rendered
    geometry, so this section exists to be measured in a browser; the structural
    suite beside it pins only that the control reaches the column it claims to,
    that it reaches nothing else, and that the fixture is still overconstrained
    enough for that measurement to mean anything. *)

type model = {
  floor_lifted : bool;
      (** Whether the holding column declares a floor of zero. [false] is the
          reported shape: no floor, so the column carries its content's own
          minimum, the pane has no room to scroll in, and the band is laid out
          past the bounded column's bottom edge. *)
}
(** The subapp model: one control over one column. The flag is not a size — the
    sizes are settled properties of the section, and a control that could change
    them would make the section's own claim unfalsifiable. *)

(** The subapp's messages. *)
type msg =
  | Floor_toggled of bool
      (** Declare the floor at zero on the holding column, or take it away
          again. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** The reported shape: no floor declared. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** Sets the flag. Nothing else happens: no size moves, and no command is
    produced. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** Renders the control and the fixture. Every box a browser case measures
    carries a [data-testid], and neither the measured boxes nor the containers
    holding them carry padding or a border, so a measured bounding box is the
    declared geometry rather than the geometry plus trim.

    The section's own root declares a height large enough to hold the reported
    shape, in which the band is laid out well past the bounded column's bottom
    edge. Overflow there is visible — clipping it would hide the very thing the
    section exists to show — so without that reservation the escaped band would
    paint over the section below and take its pointer events. It cannot compress
    the fixture: the bounded column declares a height on the axis its own
    container lays out along, which is not reduced. *)

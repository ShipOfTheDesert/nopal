(** How a checkbox is painted: by the platform, or drawn from typed values.

    A drawn checkbox is still the platform's checkbox control — its role,
    checked state, keyboard toggle and form participation are unchanged. Only
    its paint moves from the platform to the description below.

    Platform-agnostic: no CSS, DOM or browser concepts here. Each backend draws
    the description in whatever its target needs. *)

type t =
  | Native
      (** The platform's own checkbox. The element's style reaches it for
          layout, but the platform paints the box and the tick. *)
  | Drawn of { checked : Style.t; mark : Color.t }
      (** A box drawn from styles instead of the platform checkbox.

          The element's base style paints the unticked box: its size, border,
          radius and background. Styles are layered in this order: the base
          style, then the element's {!Interaction.t} states, then [checked]
          while the box is ticked. Only the properties [checked] sets take
          effect, so an interaction state still applies, ticked or not, to every
          property [checked] leaves unset; a property [checked] does set wins
          over every interaction state while the box is ticked.

          [mark] is the colour of the tick. The tick's shape is Nopal's, scaled
          to the box; only its colour is configurable.

          Sizes in [checked] carry no flex-shrink guard, on the same terms as
          interaction styles (see D-9 in CONTRIBUTING.md). *)

val equal : t -> t -> bool
(** Structural equality: [Native] equals only [Native], and two [Drawn] values
    are equal when their [checked] styles are equal under {!Style.equal} and
    their marks under {!Color.equal}. *)

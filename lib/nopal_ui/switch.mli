(** An on/off switch: a button announced with the switch role, named by a
    visible label beside it.

    The switch shows the value it is given, never what the platform last showed:
    {!make} takes it as [on], and a press asks for the opposite value through
    the toggle message {!make} requires. The application decides whether to
    accept it, and the switch shows whatever value it is next given.

    {b Tree.} {!view} renders:
    {v
    box                                  with_attrs pairs land here
    ├─ box (laid out as a row)
    │  ├─ label  for = control_id        the label text
    │  └─ button id = control_id         role=switch, aria-checked,
    │     │                              aria-describedby
    │     └─ box (track)
    │        └─ box (knob)
    ├─ box id = control_id ^ "-reason"   the reason text      (disabled only)
    └─ box id = control_id ^ "-hint"     the hint             (when set)
    v}
    The reason and the hint are siblings of the label and the button, never
    inside either, so a link in the hint is not nested in a label or a button.
    Every container is a box.

    {b Description.} The button's [aria-describedby] lists the reason box's id
    and then the hint box's id, separated by a space, naming only the boxes that
    are rendered. With neither, the button carries no [aria-describedby]. It is
    written on the button, which {!with_attrs} never reaches, so a caller cannot
    replace it and the reason is never dropped from the description. *)

type 'msg t
(** A switch's configuration. It is abstract: build it with {!make} and change
    it with the setters below. *)

(** Whether the switch can be pressed. *)
type availability =
  | Enabled  (** A press dispatches the toggle message. *)
  | Disabled of { reason : string }
      (** A press dispatches nothing, by pointer, keyboard or label. The switch
          stays focusable and in the tab order, and [reason] is shown as visible
          text beneath it and is part of its accessible description. A disabled
          switch cannot be built without a reason. *)

val make : label:string -> on:bool -> on_toggle:(bool -> 'msg) -> 'msg t
(** [make ~label ~on ~on_toggle] is an enabled switch named by the visible
    [label], drawn on when [on] is [true] and off when it is [false].

    A press — on the switch, on its label, or by keyboard — dispatches
    [on_toggle (not on)]: the message carries the value being asked for, so the
    update does not derive it. A press on the label dispatches it once. The
    message is required, so a switch that cannot toggle cannot be built.

    No hint, id or attribute is set: the id derives from [label] (see
    {!control_id}). *)

val with_availability : availability -> 'msg t -> 'msg t
(** [with_availability availability switch] makes [switch] enabled or disabled.
    A switch is [Enabled] until this says otherwise. *)

val with_hint : 'msg Nopal_element.Element.t -> 'msg t -> 'msg t
(** [with_hint hint switch] shows [hint] beneath the switch, in a box whose id
    is [control_id switch ^ "-hint"], and adds that id to the button's
    [aria-describedby], after the reason's. The hint may hold a link: it sits
    outside the label and the button. *)

val with_id : string -> 'msg t -> 'msg t
(** [with_id id switch] sets the button's id to [id] verbatim, and with it every
    id the switch derives: the label's [for] becomes [id], the reason box
    [id ^ "-reason"] and the hint box [id ^ "-hint"], and the button's
    [aria-describedby] names those. *)

val control_id : 'msg t -> string
(** [control_id switch] is the button's id: the {!with_id} value when set,
    otherwise the slugified label. *)

(** {1 Appearance}

    Every style setter replaces the whole style of its node, default included:
    nothing of the default survives a call except the structural fill-ins named
    at {!with_track_style}, {!with_button_style} and {!with_row_style}. *)

val with_track_style :
  off:Nopal_style.Style.t -> on:Nopal_style.Style.t -> 'msg t -> 'msg t
(** [with_track_style ~off ~on switch] styles the track, the box inside the
    button that holds the knob: [off] while the switch is off and [on] while it
    is on. The default is a 44 by 24 pixel pill with a 2 pixel solid border,
    grey off and green on. The border is what still tells the track apart from
    the page when forced colours drop every background.

    The knob's position comes from the track's style: it sits at the track's
    [layout.main_align]. {b Structural fill-in.} When a style leaves
    [layout.main_align] unset, the switch fills in [Start] for [off] and [End_]
    for [on], so a caller restyling the track cannot freeze the knob in one
    place and on and off stay apart without colour. A style that names its own
    [main_align] keeps it. In the same way an unset [layout.direction] is filled
    in as [Row_dir], so the knob travels across the track rather than down it.
    Every other field replaces as usual. *)

val with_knob_style :
  off:Nopal_style.Style.t -> on:Nopal_style.Style.t -> 'msg t -> 'msg t
(** [with_knob_style ~off ~on switch] styles the knob: [off] while the switch is
    off and [on] while it is on. The default is a white 16 pixel disc with a 1
    pixel solid border in both states. *)

val with_disabled_track_style :
  off:Nopal_style.Style.t -> on:Nopal_style.Style.t -> 'msg t -> 'msg t
(** [with_disabled_track_style ~off ~on switch] styles the track while the
    switch is [Disabled], in place of {!with_track_style}'s styles, with the
    same structural fill-in. Until it is called a disabled track looks exactly
    like the enabled one in the same state: disabling a switch changes no
    styling on its own. *)

val with_disabled_knob_style :
  off:Nopal_style.Style.t -> on:Nopal_style.Style.t -> 'msg t -> 'msg t
(** [with_disabled_knob_style ~off ~on switch] styles the knob while the switch
    is [Disabled], in place of {!with_knob_style}'s styles. Until it is called a
    disabled knob looks exactly like the enabled one in the same state. *)

val with_button_style : Nopal_style.Style.t -> 'msg t -> 'msg t
(** [with_button_style style switch] styles the button around the track: the
    element that takes focus and the press. Padding here enlarges the area a
    press lands on without changing the track.

    {b Structural fill-in.} The button is a transparent hit area, and the track
    is the switch's whole look, so the platform's own button chrome is cleared
    for every property [style] leaves unset: an unset [paint.background] is
    filled in as transparent, an unset [paint.border] as no border, and each
    unset side of padding as [0.]. Setting one of them keeps the caller's value,
    so a caller can add padding without the platform chrome coming back. Every
    other field replaces as usual. With no call the button carries the fill-ins
    alone. *)

val with_row_style : Nopal_style.Style.t -> 'msg t -> 'msg t
(** [with_row_style style switch] styles the box holding the label and the
    button side by side: their spacing and alignment. The default lays them out
    as a row, centred across it, with an 8 pixel gap.

    {b Structural fill-in.} An unset [layout.direction] is filled in as
    [Row_dir]; a style naming its own direction keeps it. *)

val with_label_style : Nopal_style.Style.t -> 'msg t -> 'msg t
(** [with_label_style style switch] styles the label element, and its text
    through [style]'s [text] component. The default sets nothing. *)

val with_hint_style : Nopal_style.Style.t -> 'msg t -> 'msg t
(** [with_hint_style style switch] styles the box holding the hint. The hint
    itself is the caller's own element. The default sets nothing. *)

val with_reason_style : Nopal_style.Style.t -> 'msg t -> 'msg t
(** [with_reason_style style switch] styles the box holding the disabled reason,
    and the reason's text through [style]'s [text] component. The default sets
    nothing. *)

val with_style : Nopal_style.Style.t -> 'msg t -> 'msg t
(** [with_style style switch] styles the outer box: the overall layout of the
    row, the reason and the hint. The default stacks them as a column with a 4
    pixel gap. It reaches the outer box only. *)

val with_focus_ring : Nopal_style.Interaction.t -> 'msg t -> 'msg t
(** [with_focus_ring interaction switch] replaces the button's interaction
    styles whole. The default draws a ring while the button has keyboard focus:
    a 2 pixel blue spread shadow on [focused], with zero offset and zero blur,
    and a corner radius of its own so the ring follows the default track's
    rounded ends. *)

val with_attrs : (string * string) list -> 'msg t -> 'msg t
(** [with_attrs attrs switch] puts [attrs] on the outer box, for metadata such
    as [data-testid]. The switch writes no pair of its own there.

    [attrs] never reaches the button. The button's id, role, [aria-checked] and
    [aria-describedby] therefore cannot be replaced from outside: an
    [("aria-describedby", _)] pair in [attrs] lands on the outer box and leaves
    the button's description, the reason then the hint, as it was. *)

val view : 'msg t -> 'msg Nopal_element.Element.t
(** [view switch] renders the tree described at the top of this module. *)

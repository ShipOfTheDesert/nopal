(** A single-choice control drawn as a row of adjacent segments, one per value.

    Each segment is a visually hidden native radio and a native label for it, so
    the keyboard (one tab stop, arrow keys between segments), pointer presses,
    the role, the accessible name and the checked state all come from the
    platform. The group's semantics — its name, every id, its role and naming,
    each radio and each label — are the same ones {!Radio_group} renders, from
    one shared implementation; this module owns only the layout.

    {b Tree.} {!view} renders, with the setter that styles each node:
    {v
    box   role=radiogroup, aria-labelledby, id     with_group_style
    ├─ box   id = control_id ^ "-label"            with_label_style
    └─ box                                         with_segments_style
       ├─ segment
       ├─ divider                                  with_divider_style
       ├─ segment
       └─ …
    v}
    Each segment is a box ({!with_segment_style}, {!with_segment_interaction})
    holding the hidden radio and then the native label
    ({!with_segment_label_style}), and the label holds the segment's text. Each
    divider is an empty box. Every container is a box.

    {b Dividers.} There is a divider between every pair of adjacent segments and
    nowhere else — never before the first segment or after the last — so a
    control of [n] segments has [n - 1] dividers, and none for [n = 0] or
    [n = 1]. They are there whether or not a divider style is set, so the shape
    of the tree never depends on styling, and the caller never counts.

    {b The selected segment.} Which segment is drawn as selected is decided by
    the [selected] value given to {!make}, never by what the platform last
    showed as checked. On that segment, {!with_selected_segment_style} replaces
    the segment style and {!with_selected_segment_label_style} replaces the
    label style. Replace means the whole style: nothing of the plain style is
    merged in. When a selected style is not set, the selected segment carries
    the plain one, like every other segment. *)

type segment
(** One value of the control and the text its segment shows. A segment cannot be
    disabled. *)

val segment : value:string -> string -> segment
(** [segment ~value text] is the segment for [value], showing [text]. [value] is
    what the control's selection message carries and what its ids derive from,
    so the segments of one control must have distinct values. *)

type 'msg config
(** A segmented control's configuration. It is abstract: build it with {!make}
    and change it with the setters below. *)

val make :
  label:string ->
  segments:segment list ->
  selected:string ->
  on_select:(string -> 'msg) ->
  'msg config
(** [make ~label ~segments ~selected ~on_select] is the control labelled [label]
    — shown above the segments, and the group's accessible name — whose segments
    are [segments] in order, of which the one whose value equals [selected] is
    checked and drawn as selected. A [selected] that matches no segment leaves
    every radio unchecked and every segment plain.

    Selecting a segment, by pointer or keyboard, dispatches [on_select value].
    The message is required because a radio with no selection message lets the
    platform check it without anything re-rendering, after which the checked
    radio and the selected value the control was given disagree. With a message
    always present, every selection re-renders the control, and the checked
    radio is written back from [selected], even when the update keeps the old
    value.

    No style, interaction, id or name is set: the group's id and the radios'
    name derive from [label]. *)

val with_id : string -> 'msg config -> 'msg config
(** [with_id id config] sets the outer box's id to [id] verbatim, and with it
    every id the control derives: the label box becomes [id ^ "-label"], each
    radio [id ^ "-" ^ slug value], and each segment label that radio's id
    followed by ["-label"]. It does not change the radios' name. *)

val with_name : string -> 'msg config -> 'msg config
(** [with_name name config] sets the name every radio of the control shares,
    which keeps one checked at a time and the arrow keys within the control.
    Each radio also carries it as its [data-field] attribute. Without it, the
    name is the slugified label. It changes no id. *)

val with_attrs : (string * string) list -> 'msg config -> 'msg config
(** [with_attrs attrs config] adds [attrs] to the outer box, for metadata such
    as [aria-describedby], [aria-required] or [data-testid]. The role, the
    naming pair and the id come first and [attrs] last, as in {!Radio_group}, so
    a [role], [aria-labelledby] or [id] pair in [attrs] replaces the derived
    one. Use {!with_id} to set the id. *)

val with_group_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** [with_group_style style config] styles the outer box, which holds the label
    box above the segments box. *)

val with_label_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** [with_label_style style config] styles the label box and the label text
    inside it. *)

val with_segments_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** [with_segments_style style config] styles the box holding the segments and
    the dividers between them: the control's outer border, radius and
    background.

    {b Structural values.} The box lays its children out in a row unless [style]
    sets a direction, and a direction it does set reaches the box. The border of
    [style] also decides the end segments' corners: each outer corner of the
    first and last segment is rounded by this border's radius at that corner
    minus its width, never below [0.], so the selected fill stays inside the
    outline. The first segment's outer corners are its left ones in a row and
    its top ones in a column, and the last segment's are the opposite ones. With
    no border, those corners are [0.]. See {!with_segment_style} for how they
    are written.

    A style with [overflow = Hidden] clips the focus ring of every segment drawn
    by {!with_segment_interaction}, because the ring is drawn outside the
    segment. The control does not override it. *)

val with_segment_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** [with_segment_style style config] styles every segment's box — its fill and
    height — except the selected segment's when {!with_selected_segment_style}
    is set.

    {b Structural values.} Every segment's box lays out in a row unless its
    style sets a direction, so the hidden radio sits beside its label under
    forced colours. Every segment's box is relatively positioned unless its
    style sets a position, so a segment can be layered above the dividers beside
    it. The first and last segments' corners are forced, whichever style the
    segment carries: the corners derived from {!with_segments_style}'s border
    replace the style's own [corners] on those segments, and with them its
    uniform [radius], and a lone segment is rounded on all four corners. The
    rest of the style's border — width, line style and colour — is kept. An end
    segment whose style has no border is given one with no line, zero width and
    those corners. Every other segment keeps its style's border unchanged.
    Padding belongs on {!with_segment_label_style}, not here: the label fills
    the segment. *)

val with_segment_label_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** [with_segment_label_style style config] styles every segment's label and the
    text inside it — its padding and typography — except the selected segment's
    when {!with_selected_segment_label_style} is set.

    {b Structural value.} A label grows to fill its segment unless its style
    sets [flex_grow], so a press anywhere on the segment is a press on the label
    and selects the segment. That is why a segment's padding belongs on its
    label. *)

val with_selected_segment_style :
  Nopal_style.Style.t -> 'msg config -> 'msg config
(** [with_selected_segment_style style config] styles the selected segment's box
    in place of {!with_segment_style}, replacing that style whole. No other
    segment carries it. The structural values described at {!with_segment_style}
    — the position and the end corners — apply to it the same way. *)

val with_selected_segment_label_style :
  Nopal_style.Style.t -> 'msg config -> 'msg config
(** [with_selected_segment_label_style style config] styles the selected
    segment's label and its text in place of {!with_segment_label_style},
    replacing that style whole. No other label carries it. The label grows to
    fill its segment, as described at {!with_segment_label_style}. *)

val with_divider_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** [with_divider_style style config] styles every divider box: its colour and
    width. *)

val with_segment_interaction :
  Nopal_style.Interaction.t -> 'msg config -> 'msg config
(** [with_segment_interaction interaction config] sets the interaction states of
    every segment's box, the selected one included. A [focused_within] state
    applies while the segment's radio holds focus, which is how a focus ring on
    the segment is drawn.

    {b Structural value.} A [focused_within] style that sets no [z_index] is
    given [z_index = Some 1], so the ring of the focused segment paints above
    its neighbours instead of under them. A [z_index] the style does set is
    kept, and the other states are passed on unchanged.

    {b Limitation.} The control does not keep the end-segment corners inside a
    state. A state whose style carries a border with a non-zero [radius] is
    emitted whole, so while that state is active it rounds the segment's corners
    by that radius, including the inner corners of the end segments and every
    corner of the middle ones. A state that carries a border must set [corners]
    itself. *)

val control_id : 'msg config -> string
(** [control_id config] is the outer box's id: the {!with_id} value when set,
    otherwise the slugified label. *)

val option_id : 'msg config -> value:string -> string
(** [option_id config ~value] is the id of the radio for [value]: {!control_id}
    followed by a hyphen and the slugified [value]. *)

val view : 'msg config -> 'msg Nopal_element.Element.t
(** [view config] renders the tree described at the top of this module. *)

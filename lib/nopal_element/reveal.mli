(** Declaring that a child of a scroll container must be brought into view.

    Everything here is pure and compiles on native OCaml; it references nothing
    else in this package. The arithmetic is backend-independent — taking the
    measurements it consumes is each backend's own concern. *)

(** Where in the container the revealed child should come to rest.

    Each alignment speaks of a start edge and an end edge, and means them along
    whichever axis is being revealed: top and bottom vertically, left and right
    horizontally. One alignment governs every axis a request acts on. *)
type align =
  | Nearest
      (** Move by the smallest amount that shows the whole child, and not at all
          when it is already fully visible. A child larger than the container
          that already fills it from edge to edge is not moved either, since it
          is as visible as it can be; one larger than the container that does
          not fill it moves to its start edge. *)
  | Start  (** Put the child's start edge at the container's start edge. *)
  | Center  (** Put the child's centre at the container's centre. *)
  | End_
      (** Put the child's end edge at the container's end edge. Spelled with a
          trailing underscore because [end] is a keyword. *)

type t = { key : string; align : align }
(** A request that the child carrying [key] be brought into view under [align].
    [key] is the identity a keyed child already carries: an opaque application
    string, not a protocol token, so it is compared and resolved as written. *)

val nearest : string -> t
(** [nearest key] requests the smallest move that shows the child fully, and
    none for a child larger than the container that already fills it, as
    {!Nearest} describes. *)

val start : string -> t
(** [start key] requests the child's start edge at the container's start edge.
*)

val center : string -> t
(** [center key] requests the child's centre at the container's centre. *)

val end_ : string -> t
(** [end_ key] requests the child's end edge at the container's end edge. *)

val align_token : align -> string
(** [align_token a] is the string form of [a]: ["nearest"], ["start"],
    ["center"] or ["end"]. The sole producer of that form — no call site spells
    it as a bare string — and the four are distinct, so a renderer that projects
    it for inspection can be read back to the alignment that produced it. *)

val equal : t -> t -> bool
(** [equal a b] is whether the two requests name the same child under the same
    alignment. Structural throughout: the key is compared as written and the
    alignment constructor by constructor, so a request a fresh view call rebuilt
    equals the one it replaces. It holds no float and no closure, so it is total
    and never raises. *)

val should_reveal : previous:t option -> next:t option -> bool
(** [should_reveal ~previous ~next] is whether [next] must be acted on now, and
    it is the whole rule: act when a container that carried no request gains
    one, and when a request changes in either its key or its alignment; do
    nothing when the request is unchanged, when it is withdrawn, and when there
    was never one.

    The effect is therefore edge-triggered, and the consequence is worth stating
    rather than discovering. A container moves when the request changes and for
    no other reason, so resizing the visible area while the request stays the
    same re-asserts nothing, and the requested child can sit outside the visible
    area until the request next changes. A reader who scrolls away from the
    requested child keeps their position for the same reason.

    This decision is portable, and so is the arithmetic in {!offset_for}; taking
    the measurements and moving the container are each backend's own concern. On
    a backend that does not render elements the request is inert, which is not
    an error. *)

val offset_for :
  scroll_offset:float ->
  viewport:float ->
  content:float ->
  child_start:float ->
  child_extent:float ->
  align:align ->
  float option
(** [offset_for ~scroll_offset ~viewport ~content ~child_start ~child_extent
     ~align] is the scroll offset the container must take along one axis for the
    child to sit where [align] asks, or [None] when the container must be left
    alone on that axis.

    The arithmetic names no axis: a backend calls it once per axis with that
    axis's measurements, and the same inputs give the same answer whether they
    are heights or widths. All five measurements are in one unit, lie along that
    one axis, and share one origin, the start edge of the container's scrollable
    content. [child_start] is the distance from that origin to the child's start
    edge, so it does not change as the container scrolls; [scroll_offset] is how
    far the container is currently scrolled from the same origin. [viewport] is
    the container's visible extent along the axis, [content] the full extent of
    its content, and [child_extent] the child's own extent.

    Offsets count up from [0.] at the start edge. An axis whose scroll range
    runs the other way, from a negative offset up to [0.] — as a horizontal axis
    does under right-to-left — is outside this arithmetic and must not be handed
    to it.

    The result is clamped to [0.] through [Float.max 0. (content -. viewport)],
    so it is always an offset the container can take. Content no longer than the
    viewport therefore answers [None] from the only offset such a container can
    hold, so an axis that does not overflow is never moved.

    [None] has exactly two causes, and neither raises: the offset the alignment
    asks for is the one the container already holds, so writing it would change
    nothing; or one of the measurements is not finite, in which case no offset
    is guessed.

    A child larger than [viewport] cannot satisfy any alignment exactly. Under
    {!Start}, {!Center} and {!End_} it falls back to showing its start edge, and
    none of them scrolls past it. Under {!Nearest} it is the covering rule: when
    the current offset is already in range, a child that already spans the whole
    visible extent, from [scroll_offset] to [scroll_offset +. viewport] with
    both ends inclusive, is left where it is and the answer is [None], so a
    reader partway through a long child keeps their place; a child that does not
    span it falls back to its start edge like the named alignments.

    The covering test tolerates 1.0 of the same unit at each end, strictly less
    than 1.0, because a backend measures the child's edges as fractions against
    a visible extent and content it has rounded to whole numbers; without the
    tolerance a full-width row 999.6 long in a band ending at 1000 would miss
    covering and lose the reader's position on this axis. Only the covering test
    is tolerant: whether a child that fits is fully visible stays exact. *)

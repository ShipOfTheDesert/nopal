(** Moving a scroll container by an amount relative to its own visible height.

    Everything here is pure and compiles on native OCaml; it references nothing
    else in this package. The arithmetic is backend-independent — taking the
    measurements it consumes is each backend's own concern. *)

type t
(** A relative movement of a scroll container, in units of the container's own
    visible height. Abstract so a later pixel or line unit arrives without
    changing the command that carries it. Comparison operators are deliberately
    withheld: this is a geometry quantity, and exact float comparison on one is
    a latent bug. *)

val viewports : float -> t
(** [viewports n] is a movement of [n] times the container's visible height,
    positive toward the end and negative back toward the start. Accepts any
    float, including a non-finite one — the rejection lives at {!offset_for},
    which answers [None], so nothing here validates and no caller needs to. *)

val equal : t -> t -> bool
(** [equal a b] is whether the two are the same request, compared over
    [Float.equal] so a request a fresh update rebuilt equals the one it
    replaces. Exact by design, and not in tension with the comparators the type
    withholds: it answers "is this the same request", never "did the container
    move far enough". It exists for the structural suites, which have no other
    way to read a value out of an abstract type; nothing that applies a request
    uses it. *)

val offset_for :
  scroll_offset:float ->
  viewport_height:float ->
  content_height:float ->
  t ->
  float option
(** [offset_for ~scroll_offset ~viewport_height ~content_height delta] is the
    scroll offset the container must take, or [None] when it must be left alone.

    All three measurements are in one unit and share one origin, the top of the
    container's scrollable content. [scroll_offset] is how far the container is
    currently scrolled from that origin, [viewport_height] is its visible height
    and [content_height] the full height of its content. The result is clamped
    to [0.] through [Float.max 0. (content_height -. viewport_height)], so it is
    always an offset the container can take.

    [None] has exactly two causes, and neither raises: the clamped offset is the
    one the container already holds, so writing it would change nothing; or one
    of the measurements — or the delta — is not finite, in which case no offset
    is guessed. A container that cannot scroll therefore answers [None] to every
    delta, and so does a container already at the end asked to move further. *)

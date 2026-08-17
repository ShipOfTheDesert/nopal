(** Declaring that a child of a scroll container must be brought into view.

    Everything here is pure and compiles on native OCaml; it references nothing
    else in this package. The arithmetic is backend-independent — taking the
    measurements it consumes is each backend's own concern. *)

(** Where in the container the revealed child should come to rest. *)
type align =
  | Nearest
      (** Move by the smallest amount that shows the whole child, and not at all
          when it is already fully visible. *)
  | Start  (** Put the child's top edge at the container's top edge. *)
  | Center  (** Put the child's centre at the container's centre. *)
  | End_
      (** Put the child's bottom edge at the container's bottom edge. Spelled
          with a trailing underscore because [end] is a keyword. *)

type t = { key : string; align : align }
(** A request that the child carrying [key] be brought into view under [align].
    [key] is the identity a keyed child already carries: an opaque application
    string, not a protocol token, so it is compared and resolved as written. *)

val nearest : string -> t
(** [nearest key] requests the smallest move that shows the child fully. *)

val start : string -> t
(** [start key] requests the child's top edge at the container's top edge. *)

val center : string -> t
(** [center key] requests the child's centre at the container's centre. *)

val end_ : string -> t
(** [end_ key] requests the child's bottom edge at the container's bottom edge.
*)

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
  viewport_height:float ->
  content_height:float ->
  child_top:float ->
  child_height:float ->
  align:align ->
  float option
(** [offset_for ~scroll_offset ~viewport_height ~content_height ~child_top
     ~child_height ~align] is the scroll offset the container must take for the
    child to sit where [align] asks, or [None] when the container must be left
    alone.

    All six measurements are in one unit and share one origin, the top of the
    container's scrollable content. [child_top] is the distance from that origin
    to the child's top edge, so it does not change as the container scrolls;
    [scroll_offset] is how far the container is currently scrolled from the same
    origin. [viewport_height] is the container's visible height and
    [content_height] the full height of its content.

    The result is clamped to [0.] through
    [Float.max 0. (content_height -. viewport_height)], so it is always an
    offset the container can take.

    [None] has exactly two causes, and neither raises: the offset the alignment
    asks for is the one the container already holds, so writing it would change
    nothing; or one of the measurements is not finite, in which case no offset
    is guessed. A child taller than [viewport_height] cannot satisfy any
    alignment, so every alignment falls back to showing its top edge and none of
    them scrolls past it. *)

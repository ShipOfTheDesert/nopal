(** Viewport — describes the current display surface.

    Combines pixel dimensions, derived size class, orientation, and safe area
    insets into a single immutable value. Platform backends produce viewports;
    application code reads them in [view]. *)

type t
type orientation = Portrait | Landscape
type safe_area

val make_safe_area :
  top:int -> right:int -> bottom:int -> left:int -> unit -> safe_area

val zero_insets : safe_area
val safe_area_top : safe_area -> int
val safe_area_right : safe_area -> int
val safe_area_bottom : safe_area -> int
val safe_area_left : safe_area -> int

val make : width:int -> height:int -> ?safe_area:safe_area -> unit -> t
(** Construct a viewport. [size_class] and [orientation] are derived
    automatically from the given dimensions. *)

val width : t -> int
val height : t -> int
val size_class : t -> Size_class.t
val orientation : t -> orientation
val safe_area : t -> safe_area
val is_compact : t -> bool
val is_medium : t -> bool
val is_expanded : t -> bool
val equal_orientation : orientation -> orientation -> bool
val equal : t -> t -> bool

(** {2 Presets for testing} *)

val phone : t
(** 375×812, Compact, Portrait, zero insets *)

val phone_landscape : t
(** 812×375, Medium, Landscape, zero insets *)

val tablet : t
(** 768×1024, Medium, Portrait, zero insets *)

val desktop : t
(** 1440×900, Expanded, Landscape, zero insets *)

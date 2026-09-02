(** Shared helpers for chart unit tests. *)

val extract_draw :
  'msg Nopal_element.Element.t ->
  (Nopal_scene.Scene.t list
  * (Nopal_element.Element.pointer_event -> 'msg) option
  * 'msg option
  * float
  * float)
  option
(** Extract the Draw element's fields from a chart view result. Handles both
    bare [Draw] and [Box \{ children = [... Draw ...]; _ \}] wrappers that chart
    views may produce. *)

val count_nodes :
  (Nopal_scene.Scene.t -> bool) -> Nopal_scene.Scene.t list -> int
(** Recursively count scene nodes matching a predicate, traversing [Clip] and
    [Group] children. *)

val is_polyline : Nopal_scene.Scene.t -> bool
(** [true] when the node is a [Polyline]. *)

val is_path : Nopal_scene.Scene.t -> bool
(** [true] when the node is a [Path]. *)

val is_circle : Nopal_scene.Scene.t -> bool
(** [true] when the node is a [Circle]. *)

val is_rect : Nopal_scene.Scene.t -> bool
(** [true] when the node is a [Rect]. *)

val color_testable : Nopal_scene.Color.t Alcotest.testable
(** Alcotest testable for colours: prints [rgba(r, g, b, a)] and compares with
    [Nopal_scene.Color.equal]. *)

val lines_of :
  Nopal_scene.Scene.t list ->
  (float * float * float * float * Nopal_scene.Paint.stroke) list
(** Every [Line] node in the list, as [(x1, y1, x2, y2, stroke)]. [Scene.Line]'s
    payload is an inline record and cannot escape the match, so the fields are
    lifted into a tuple. Does not descend into [Group] or [Clip]. *)

val texts_of :
  Nopal_scene.Scene.t list -> (string * float * Nopal_scene.Paint.t) list
(** Every [Text] node in the list, as [(content, font_size, fill)].
    [Scene.Text]'s payload is an inline record and cannot escape the match, so
    the three fields the label assertions need are lifted into a tuple. Does not
    descend into [Group] or [Clip]. *)

val paint_color : Nopal_scene.Paint.t -> Nopal_scene.Color.t
(** The colour of a [Solid] paint. Fails the running Alcotest case for any
    gradient or [No_paint], which chart chrome is never expected to use. *)

(** Viewport clipping — filters data to visible window + buffer.

    Used by chart types to render only the data points that fall within the
    current {!Domain_window.t}, plus a configurable number of buffer points
    beyond each edge for path continuity. *)

val clip :
  x:('a -> float) ->
  data:'a list ->
  window:Domain_window.t ->
  buffer:int ->
  'a list
(** Return elements whose X value falls within [window], plus [buffer] elements
    beyond each edge for path continuity. Preserves order. [buffer] is typically
    1 for line/area charts (path needs adjacent point) and 0 for bar/scatter. *)

val clip_sorted :
  x:('a -> float) ->
  data:'a array ->
  window:Domain_window.t ->
  buffer:int ->
  'a array
(** Optimized clipping for pre-sorted data using binary search. Returns a
    sub-array. O(log n) instead of O(n). *)

(** Downsample — LTTB (Largest Triangle Three Buckets) algorithm.

    Reduces large datasets to a target number of points while preserving visual
    shape. First and last points are always preserved. *)

val lttb :
  x:('a -> float) -> y:('a -> float) -> data:'a array -> target:int -> 'a array
(** Downsample [data] to [target] points using LTTB. First and last points are
    always preserved. Returns original data if length <= target. *)

val should_downsample : data_length:int -> pixel_width:float -> bool
(** Returns true when [data_length] > 3 * [pixel_width] (threshold: 3x pixels).
    Charts call this to decide whether to apply downsampling. *)

val target_for_width : pixel_width:float -> int
(** Returns [2 * pixel_width] as the target point count. Ensures at least 2
    points per pixel for visual fidelity. *)

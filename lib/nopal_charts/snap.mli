(** Snap — find the nearest data point to a target X value.

    Used for crosshair snapping and tooltip positioning. *)

val nearest_index :
  x:('a -> float) -> data:'a list -> target:float -> int option
(** Return the index of the element in [data] whose X value is closest to
    [target]. Returns [None] for an empty list. O(n) linear scan. *)

val nearest_index_sorted :
  x:('a -> float) -> data:'a array -> target:float -> int option
(** Optimized nearest-index for pre-sorted data using binary search. Returns
    [None] for an empty array. O(log n). *)

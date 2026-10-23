(** The arc edge-case table shared by every renderer's arc suite.

    Each row is one arc and the sweep {!Nopal_draw.Arc.resolve} must give it.
    The resolver's own suite checks the expectation directly; each renderer's
    suite is generated from the same rows, so a renderer that disagrees with the
    table fails a test. *)

type expected =
  | Invalid
  | Sweep of float
      (** The signed sweep only; the reduced start is not pinned. *)

type row = {
  name : string;  (** The Alcotest case name. *)
  direction : Nopal_scene.Path.direction;
  cx : float;
  cy : float;
  r : float;
  start_angle : float;
  end_angle : float;
  expected : expected;
}

val rows : row list
(** Every row of the table, in a fixed order. *)

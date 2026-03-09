(** Affine transform types for 2D scene composition. *)

type t =
  | Translate of { dx : float; dy : float }
  | Scale of { sx : float; sy : float }
  | Rotate of float  (** Angle in radians. *)
  | Rotate_around of { angle : float; cx : float; cy : float }
  | Skew of { sx : float; sy : float }  (** Skew angles in radians. *)
  | Matrix of {
      a : float;
      b : float;
      c : float;
      d : float;
      e : float;
      f : float;
    }

val translate : dx:float -> dy:float -> t
(** [translate ~dx ~dy] shifts by [(dx, dy)]. *)

val scale : sx:float -> sy:float -> t
(** [scale ~sx ~sy] scales by [(sx, sy)]. *)

val rotate : float -> t
(** [rotate angle] rotates by [angle] radians around the origin. *)

val rotate_around : angle:float -> cx:float -> cy:float -> t
(** [rotate_around ~angle ~cx ~cy] rotates around the point [(cx, cy)]. *)

val skew : sx:float -> sy:float -> t
(** [skew ~sx ~sy] applies a skew transform. *)

val matrix : a:float -> b:float -> c:float -> d:float -> e:float -> f:float -> t
(** [matrix ~a ~b ~c ~d ~e ~f] applies an arbitrary 2D affine transform. *)

val equal : t -> t -> bool
(** Structural equality for transforms. *)

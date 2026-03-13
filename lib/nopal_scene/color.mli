(** Float RGBA color type for graphics rendering.

    Colors use float components in the 0.0-1.0 range, matching GPU API
    conventions. This is separate from {!type:Nopal_style.Style.color} which
    uses integer RGBA for CSS authoring. *)

type t = { r : float; g : float; b : float; a : float }

val rgba : r:float -> g:float -> b:float -> a:float -> t
(** [rgba ~r ~g ~b ~a] creates a color from float RGBA components (0.0-1.0). *)

val rgb : r:float -> g:float -> b:float -> t
(** [rgb ~r ~g ~b] creates an opaque color (alpha = 1.0). *)

val hsla : h:float -> s:float -> l:float -> a:float -> t
(** [hsla ~h ~s ~l ~a] creates a color from HSL components. [h] is in degrees
    (0.0-360.0), [s] and [l] in 0.0-1.0. *)

val hsl : h:float -> s:float -> l:float -> t
(** [hsl ~h ~s ~l] creates an opaque color from HSL. *)

val of_hex : string -> (t, string) result
(** [of_hex s] parses a hex color string ("#RGB", "#RRGGBB", or "#RRGGBBAA").
    Returns [Error msg] on invalid format. No hex strings persist in the scene
    tree — the result is the canonical float RGBA representation. *)

val lerp : t -> t -> float -> t
(** [lerp a b t] linearly interpolates between [a] and [b] at position [t] (0.0
    = [a], 1.0 = [b]). *)

val equal : t -> t -> bool
(** Structural equality for colors. *)

val red : t
(** Pure red (1.0, 0.0, 0.0, 1.0). *)

val green : t
(** Pure green (0.0, 1.0, 0.0, 1.0). *)

val blue : t
(** Pure blue (0.0, 0.0, 1.0, 1.0). *)

val black : t
(** Black (0.0, 0.0, 0.0, 1.0). *)

val white : t
(** White (1.0, 1.0, 1.0, 1.0). *)

val transparent : t
(** Fully transparent (0.0, 0.0, 0.0, 0.0). *)

val categorical : t array
(** Default categorical palette of 10 visually distinct colors for data series.
*)

val sequential : t -> t -> int -> t list
(** [sequential start stop n] generates [n] colors interpolated evenly between
    [start] and [stop]. *)

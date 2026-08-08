type t
(** A validated set of capture parameters. *)

(** The encoded form the platform backend writes. *)
type format =
  | Jpeg  (** Lossy. The smallest bytes for a photograph. *)
  | Png  (** Lossless. Larger bytes, no compression artefacts. *)
  | Webp  (** Lossy or lossless, decided by the platform encoder. *)

val make :
  max_edge:int ->
  metric_edge:int ->
  quality:float ->
  format:format ->
  (t, Image_error.t) result
(** [make ~max_edge ~metric_edge ~quality ~format] validates that both edges are
    positive, that [metric_edge] does not exceed [max_edge], and that [quality]
    is a number between 0 and 1 inclusive. Every parameter is required and there
    is no field-wise update path, so a custom set states all four values. *)

val recommended : t
(** The recommended parameters: a 1600 pixel long edge for the stored image, an
    800 pixel long edge for the sharpness pass, quality 0.8, encoded as JPEG. *)

val max_edge : t -> int
(** Longest edge in pixels the stored image is scaled down to. *)

val metric_edge : t -> int
(** Longest edge in pixels the sharpness pass is scaled down to. Never larger
    than the stored long edge. *)

val quality : t -> float
(** Encoder quality, between 0 and 1 inclusive, as the caller supplied it. *)

val format : t -> format
(** The encoded form to write. *)

val format_to_mime : format -> string
(** [format_to_mime format] is the media type naming [format], for a platform
    encoder that takes its target as a string. *)

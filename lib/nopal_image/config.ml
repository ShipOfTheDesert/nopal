type format = Jpeg | Png | Webp
type t = { max_edge : int; metric_edge : int; quality : float; format : format }

(* NaN is checked before the bounds rather than left to them. [Float.compare]
   puts NaN below every other float — [Float.compare nan 0.0] and
   [Float.compare nan neg_infinity] are both [-1] — so the lower bound would
   reject a NaN anyway, but as an accident of the total order, and reporting a
   NaN as an out-of-range value tells the caller the wrong thing. The distinct
   message this branch produces is pinned by a test, so deleting the branch is a
   failure rather than a silent no-op. *)
let validate_quality quality =
  if Float.is_nan quality then
    Error (Image_error.Invalid_config "quality must be a number, got nan")
  else if Float.compare quality 0.0 < 0 || Float.compare quality 1.0 > 0 then
    Error
      (Image_error.Invalid_config
         (Printf.sprintf "quality must be between 0 and 1, got %g" quality))
  else Ok quality

let make ~max_edge ~metric_edge ~quality ~format =
  if max_edge <= 0 then
    Error
      (Image_error.Invalid_config
         (Printf.sprintf "max edge must be positive, got %d" max_edge))
  else if metric_edge <= 0 then
    Error
      (Image_error.Invalid_config
         (Printf.sprintf "metric edge must be positive, got %d" metric_edge))
  else if metric_edge > max_edge then
    Error
      (Image_error.Invalid_config
         (Printf.sprintf "metric edge %d must not exceed max edge %d"
            metric_edge max_edge))
  else
    Result.map
      (fun quality -> { max_edge; metric_edge; quality; format })
      (validate_quality quality)

(* Built as a literal rather than by unwrapping [make]: [recommended] is a [t],
   not a result, and unwrapping would need a partial call. The values satisfy
   every rule [make] enforces. *)
let recommended =
  { max_edge = 1600; metric_edge = 800; quality = 0.8; format = Jpeg }

let max_edge t = t.max_edge
let metric_edge t = t.metric_edge
let quality t = t.quality
let format t = t.format

let format_to_mime = function
  | Jpeg -> "image/jpeg"
  | Png -> "image/png"
  | Webp -> "image/webp"

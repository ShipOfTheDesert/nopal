(* One pixel is the smallest edge a canvas can be allocated at, so it is the
   floor every returned edge is clamped to. *)
let min_edge = 1

let scale_short ~short_edge ~long_edge ~max_edge =
  let scaled =
    float_of_int short_edge *. float_of_int max_edge /. float_of_int long_edge
  in
  Stdlib.max min_edge (int_of_float scaled)

(* [if], not [match]: every branch here turns on a comparison between ints, so
   a [match] would need a catch-all and would read as if a variant were being
   dispatched. Same reasoning as [Nopal_image.Sharpness.score]. *)
let fit ~src_width ~src_height ~max_edge =
  (* Clamping the divisor rather than the raw source keeps the division defined
     for every input, including a degenerate source with a zero edge. *)
  let long_edge = Stdlib.max min_edge (Stdlib.max src_width src_height) in
  if long_edge <= max_edge then
    (Stdlib.max min_edge src_width, Stdlib.max min_edge src_height)
  else
    (* The capped edge is assigned [max_edge] outright rather than derived from
       the scale factor: multiplying the long edge back by
       [max_edge /. long_edge] can land a whole pixel short of the cap once the
       float round trip is truncated. *)
    let capped = Stdlib.max min_edge max_edge in
    if src_width >= src_height then
      (capped, scale_short ~short_edge:src_height ~long_edge ~max_edge)
    else (scale_short ~short_edge:src_width ~long_edge ~max_edge, capped)

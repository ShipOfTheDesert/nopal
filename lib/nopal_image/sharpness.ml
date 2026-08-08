(* Both traversals index [luma] directly. Every index they produce is derived
   from the buffer's own dimensions, and [Luma.of_buffer] returns exactly one
   entry per pixel, so no index can fall outside the array. *)
let sum_horizontal ~width ~height luma =
  let rec walk y x total =
    if y >= height then total
    else if x >= width - 1 then walk (y + 1) 0 total
    else
      let left = (y * width) + x in
      walk y (x + 1) (total +. Float.abs (luma.(left) -. luma.(left + 1)))
  in
  walk 0 0 0.0

let sum_vertical ~width ~height luma =
  let pairs = width * (height - 1) in
  let rec walk above total =
    if above >= pairs then total
    else
      walk (above + 1)
        (total +. Float.abs (luma.(above) -. luma.(above + width)))
  in
  walk 0 0.0

let score buffer =
  let width = Buffer.width buffer in
  let height = Buffer.height buffer in
  let pairs = ((width - 1) * height) + (width * (height - 1)) in
  (* An [if], not a [match]: [pairs] is an int, so a [match] would need a
     catch-all and would read as if a variant were being dispatched. *)
  if pairs = 0 then 0.0
  else
    let luma = Luma.of_buffer buffer in
    (sum_horizontal ~width ~height luma +. sum_vertical ~width ~height luma)
    /. float_of_int pairs

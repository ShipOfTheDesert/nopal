type t = { x_min : float; x_max : float }

let create ~x_min ~x_max = { x_min; x_max }
let equal a b = Float.equal a.x_min b.x_min && Float.equal a.x_max b.x_max
let width t = t.x_max -. t.x_min
let pan t ~delta = { x_min = t.x_min +. delta; x_max = t.x_max +. delta }

let zoom t ~center ~factor =
  let old_width = width t in
  if Float.equal old_width 0.0 then t
  else
    let new_width = old_width *. factor in
    let ratio = (center -. t.x_min) /. old_width in
    let new_min = center -. (ratio *. new_width) in
    let new_max = new_min +. new_width in
    { x_min = new_min; x_max = new_max }

let clamp ~data_min ~data_max t =
  let w = width t in
  if w >= data_max -. data_min then { x_min = data_min; x_max = data_max }
  else if t.x_min < data_min then { x_min = data_min; x_max = data_min +. w }
  else if t.x_max > data_max then { x_min = data_max -. w; x_max = data_max }
  else t

type t = Viewports of float

let viewports n = Viewports n

(* Enumerated rather than compared with [=], so a second unit — pixels, lines —
   is a compile error here instead of a constructor that silently reports itself
   unequal to itself. *)
let equal a b =
  match (a, b) with
  | Viewports x, Viewports y -> Float.equal x y

let multiple (Viewports n) = n
let all_finite measurements = List.for_all Float.is_finite measurements

(* Finiteness is checked on each value in turn rather than inferred from the
   result: a product of two finite numbers can overflow to an infinity, and a
   guard that only looked at the outcome would accept an infinite measurement
   whose product happened to land back in range. *)
let offset_for ~scroll_offset ~viewport_height ~content_height delta =
  let n = multiple delta in
  if not (all_finite [ scroll_offset; viewport_height; content_height; n ]) then
    None
  else
    let target = scroll_offset +. (n *. viewport_height) in
    let max_scroll = Float.max 0.0 (content_height -. viewport_height) in
    let clamped = Float.min max_scroll (Float.max 0.0 target) in
    if Float.equal clamped scroll_offset then None else Some clamped

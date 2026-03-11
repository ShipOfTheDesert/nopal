type hit = { index : int; series : int }

type region =
  | Rect_region of { x : float; y : float; w : float; h : float; hit : hit }
  | Circle_region of { cx : float; cy : float; r : float; hit : hit }
  | Wedge_region of {
      cx : float;
      cy : float;
      inner_r : float;
      outer_r : float;
      start_angle : float;
      end_angle : float;
      hit : hit;
    }
  | Band_region of { x : float; w : float; hit : hit }

(* Regions stored in reverse draw order (most recent first) via cons.
   hit_test scans front-to-back, so the last-added region is tested first
   (topmost priority, REQ-F15). *)
type t = region list

let empty = []
let add region t = region :: t

let point_in_rect ~x ~y ~rx ~ry ~rw ~rh =
  x >= rx && x <= rx +. rw && y >= ry && y <= ry +. rh

let point_in_circle ~x ~y ~cx ~cy ~r =
  let dx = x -. cx in
  let dy = y -. cy in
  (dx *. dx) +. (dy *. dy) <= r *. r

let normalize_angle a =
  let two_pi = 2.0 *. Float.pi in
  let a = Float.rem a two_pi in
  if a < 0.0 then a +. two_pi else a

let point_in_wedge ~x ~y ~cx ~cy ~inner_r ~outer_r ~start_angle ~end_angle =
  let dx = x -. cx in
  let dy = y -. cy in
  let dist_sq = (dx *. dx) +. (dy *. dy) in
  if dist_sq < inner_r *. inner_r || dist_sq > outer_r *. outer_r then false
  else
    let angle = normalize_angle (Float.atan2 dy dx) in
    let start_n = normalize_angle start_angle in
    let end_n = normalize_angle end_angle in
    if start_n <= end_n then angle >= start_n && angle <= end_n
    else (* wraps around 0 *)
      angle >= start_n || angle <= end_n

let test_region ~x ~y region =
  match region with
  | Rect_region { x = rx; y = ry; w = rw; h = rh; hit } ->
      if point_in_rect ~x ~y ~rx ~ry ~rw ~rh then Some hit else None
  | Circle_region { cx; cy; r; hit } ->
      if point_in_circle ~x ~y ~cx ~cy ~r then Some hit else None
  | Wedge_region { cx; cy; inner_r; outer_r; start_angle; end_angle; hit } ->
      if point_in_wedge ~x ~y ~cx ~cy ~inner_r ~outer_r ~start_angle ~end_angle
      then Some hit
      else None
  | Band_region { x = bx; w = bw; hit } ->
      if x >= bx && x <= bx +. bw then Some hit else None

let hit_test t ~x ~y = List.find_map (test_region ~x ~y) t
let equal_hit a b = a.index = b.index && a.series = b.series

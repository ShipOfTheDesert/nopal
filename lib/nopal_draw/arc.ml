type resolved = Invalid | Sweep of { start : float; sweep : float }

let full_turn = 2. *. Float.pi

let turn_fraction angle =
  let rem = Float.rem angle full_turn in
  let reduced = if rem < 0. then rem +. full_turn else rem in
  (* A tiny negative angle rounds [rem +. full_turn] up to [full_turn]. *)
  if reduced >= full_turn then 0. else reduced

let is_valid ~cx ~cy ~r ~start_angle ~end_angle =
  Float.is_finite cx
  && Float.is_finite cy
  && Float.is_finite r
  && Float.is_finite start_angle
  && Float.is_finite end_angle
  && r >= 0.

(* The partial sweep reduces each angle before subtracting: the raw difference
   of two finite angles can overflow to infinity, and reducing infinity gives
   NaN. *)
let partial_sweep ~from ~towards =
  turn_fraction (turn_fraction towards -. turn_fraction from)

let resolve direction ~cx ~cy ~r ~start_angle ~end_angle =
  match is_valid ~cx ~cy ~r ~start_angle ~end_angle with
  | false -> Invalid
  | true -> (
      let start = turn_fraction start_angle in
      match (direction : Nopal_scene.Path.direction) with
      | Clockwise when end_angle -. start_angle >= full_turn ->
          Sweep { start; sweep = full_turn }
      | Clockwise ->
          Sweep
            {
              start;
              sweep = partial_sweep ~from:start_angle ~towards:end_angle;
            }
      | Anticlockwise when start_angle -. end_angle >= full_turn ->
          Sweep { start; sweep = -.full_turn }
      | Anticlockwise ->
          Sweep
            {
              start;
              sweep = 0. -. partial_sweep ~from:end_angle ~towards:start_angle;
            })

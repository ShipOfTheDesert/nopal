type segment =
  | Move_to of { x : float; y : float }
  | Line_to of { x : float; y : float }
  | Bezier_to of {
      cp1x : float;
      cp1y : float;
      cp2x : float;
      cp2y : float;
      x : float;
      y : float;
    }
  | Quad_to of { cpx : float; cpy : float; x : float; y : float }
  | Arc_to of {
      cx : float;
      cy : float;
      r : float;
      start_angle : float;
      end_angle : float;
    }
  | Close

let move_to ~x ~y = Move_to { x; y }
let line_to ~x ~y = Line_to { x; y }

let bezier_to ~cp1x ~cp1y ~cp2x ~cp2y ~x ~y =
  Bezier_to { cp1x; cp1y; cp2x; cp2y; x; y }

let quad_to ~cpx ~cpy ~x ~y = Quad_to { cpx; cpy; x; y }

let arc_to ~cx ~cy ~r ~start_angle ~end_angle =
  Arc_to { cx; cy; r; start_angle; end_angle }

let close = Close

let equal_segment a b =
  let float_eq a b = Float.abs (a -. b) < 1e-10 in
  match (a, b) with
  | Move_to a, Move_to b -> float_eq a.x b.x && float_eq a.y b.y
  | Line_to a, Line_to b -> float_eq a.x b.x && float_eq a.y b.y
  | Bezier_to a, Bezier_to b ->
      float_eq a.cp1x b.cp1x
      && float_eq a.cp1y b.cp1y
      && float_eq a.cp2x b.cp2x
      && float_eq a.cp2y b.cp2y
      && float_eq a.x b.x
      && float_eq a.y b.y
  | Quad_to a, Quad_to b ->
      float_eq a.cpx b.cpx
      && float_eq a.cpy b.cpy
      && float_eq a.x b.x
      && float_eq a.y b.y
  | Arc_to a, Arc_to b ->
      float_eq a.cx b.cx
      && float_eq a.cy b.cy
      && float_eq a.r b.r
      && float_eq a.start_angle b.start_angle
      && float_eq a.end_angle b.end_angle
  | Close, Close -> true
  | (Move_to _ | Line_to _ | Bezier_to _ | Quad_to _ | Arc_to _ | Close), _ ->
      false

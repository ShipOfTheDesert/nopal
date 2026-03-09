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

let smooth_curve points =
  match points with
  | [] -> []
  | [ (x, y) ] -> [ Move_to { x; y } ]
  | [ (x0, y0); (x1, y1) ] ->
      [ Move_to { x = x0; y = y0 }; Line_to { x = x1; y = y1 } ]
  | _ ->
      let arr = Array.of_list points in
      let n = Array.length arr in
      let fst_x, fst_y = arr.(0) in
      (* Imperative: 4-point sliding window needs indexed access into array *)
      let segs = ref [ Move_to { x = fst_x; y = fst_y } ] in
      for i = 0 to n - 2 do
        let x0, y0 = if i > 0 then arr.(i - 1) else arr.(i) in
        let x1, y1 = arr.(i) in
        let x2, y2 = arr.(i + 1) in
        let x3, y3 = if i + 2 < n then arr.(i + 2) else arr.(i + 1) in
        (* Catmull-Rom to cubic bezier conversion with alpha=0.5 (centripetal) *)
        let tension = 1.0 /. 6.0 in
        let cp1x = x1 +. (tension *. (x2 -. x0)) in
        let cp1y = y1 +. (tension *. (y2 -. y0)) in
        let cp2x = x2 -. (tension *. (x3 -. x1)) in
        let cp2y = y2 -. (tension *. (y3 -. y1)) in
        segs := Bezier_to { cp1x; cp1y; cp2x; cp2y; x = x2; y = y2 } :: !segs
      done;
      List.rev !segs

let straight_line points =
  match points with
  | [] -> []
  | (x, y) :: rest ->
      Move_to { x; y } :: List.map (fun (x, y) -> Line_to { x; y }) rest

let closed_area points =
  match points with
  | [] -> []
  | (x, y) :: rest ->
      (Move_to { x; y } :: List.map (fun (x, y) -> Line_to { x; y }) rest)
      @ [ Close ]

let arc_segment ~cx ~cy ~r ~start_angle ~end_angle =
  let sx = cx +. (r *. cos start_angle) in
  let sy = cy +. (r *. sin start_angle) in
  [ Move_to { x = sx; y = sy }; Arc_to { cx; cy; r; start_angle; end_angle } ]

let donut_arc ~cx ~cy ~inner_r ~outer_r ~start_angle ~end_angle =
  let outer_sx = cx +. (outer_r *. cos start_angle) in
  let outer_sy = cy +. (outer_r *. sin start_angle) in
  let inner_ex = cx +. (inner_r *. cos end_angle) in
  let inner_ey = cy +. (inner_r *. sin end_angle) in
  [
    Move_to { x = outer_sx; y = outer_sy };
    Arc_to { cx; cy; r = outer_r; start_angle; end_angle };
    Line_to { x = inner_ex; y = inner_ey };
    Arc_to
      { cx; cy; r = inner_r; start_angle = end_angle; end_angle = start_angle };
    Close;
  ]

let float_eq a b = Float.abs (a -. b) < 1e-10

let equal_segment a b =
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

type gradient_stop = { offset : float; color : Color.t }

type t =
  | Solid of Color.t
  | Linear_gradient of {
      x0 : float;
      y0 : float;
      x1 : float;
      y1 : float;
      stops : gradient_stop list;
    }
  | Radial_gradient of {
      cx : float;
      cy : float;
      r : float;
      stops : gradient_stop list;
    }
  | No_paint

type line_cap = Butt | Round_cap | Square
type line_join = Miter | Round_join | Bevel

type stroke = {
  paint : t;
  width : float;
  dash : float list;
  dash_offset : float;
  line_cap : line_cap;
  line_join : line_join;
}

let solid color = Solid color
let no_paint = No_paint
let clamp_offset o = Float.max 0.0 (Float.min 1.0 o)

let validate_and_normalize_stops stops =
  match stops with
  | [] -> Error "gradient requires at least one stop"
  | stops ->
      let normalized =
        List.map (fun s -> { s with offset = clamp_offset s.offset }) stops
      in
      let sorted =
        List.sort (fun a b -> Float.compare a.offset b.offset) normalized
      in
      Ok sorted

let linear_gradient ~x0 ~y0 ~x1 ~y1 ~stops =
  match validate_and_normalize_stops stops with
  | Error e -> Error e
  | Ok stops -> Ok (Linear_gradient { x0; y0; x1; y1; stops })

let radial_gradient ~cx ~cy ~r ~stops =
  match validate_and_normalize_stops stops with
  | Error e -> Error e
  | Ok stops -> Ok (Radial_gradient { cx; cy; r; stops })

let stroke ?(width = 1.0) ?(dash = []) ?(dash_offset = 0.0) ?(line_cap = Butt)
    ?(line_join = Miter) paint =
  { paint; width; dash; dash_offset; line_cap; line_join }

let equal_gradient_stop a b =
  Float.equal a.offset b.offset && Color.equal a.color b.color

let equal_stop_lists a b = List.equal equal_gradient_stop a b

let equal a b =
  match (a, b) with
  | Solid ca, Solid cb -> Color.equal ca cb
  | No_paint, No_paint -> true
  | Linear_gradient a, Linear_gradient b ->
      Float.equal a.x0 b.x0
      && Float.equal a.y0 b.y0
      && Float.equal a.x1 b.x1
      && Float.equal a.y1 b.y1
      && equal_stop_lists a.stops b.stops
  | Radial_gradient a, Radial_gradient b ->
      Float.equal a.cx b.cx
      && Float.equal a.cy b.cy
      && Float.equal a.r b.r
      && equal_stop_lists a.stops b.stops
  | Solid _, _
  | No_paint, _
  | Linear_gradient _, _
  | Radial_gradient _, _ ->
      false

let equal_line_cap a b =
  match (a, b) with
  | Butt, Butt
  | Round_cap, Round_cap
  | Square, Square ->
      true
  | Butt, _
  | Round_cap, _
  | Square, _ ->
      false

let equal_line_join a b =
  match (a, b) with
  | Miter, Miter
  | Round_join, Round_join
  | Bevel, Bevel ->
      true
  | Miter, _
  | Round_join, _
  | Bevel, _ ->
      false

let rec equal_float_list a b =
  match (a, b) with
  | [], [] -> true
  | x :: xs, y :: ys -> Float.equal x y && equal_float_list xs ys
  | _, _ -> false

let equal_stroke a b =
  equal a.paint b.paint
  && Float.equal a.width b.width
  && equal_float_list a.dash b.dash
  && Float.equal a.dash_offset b.dash_offset
  && equal_line_cap a.line_cap b.line_cap
  && equal_line_join a.line_join b.line_join

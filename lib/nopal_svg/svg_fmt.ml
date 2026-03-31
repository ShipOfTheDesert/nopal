open Nopal_scene

type ctx = {
  (* mutable: required for unique ID generation across recursive render traversal *)
  mutable next_id : int;
  defs : Buffer.t;
}

let create_ctx () = { next_id = 0; defs = Buffer.create 256 }

(** Format a float as a compact number: integer if whole, otherwise minimal
    decimal. Avoids OCaml's trailing-dot problem with [string_of_float]. *)
let fmt_float f =
  let i = Float.to_int f in
  if Float.equal f (Float.of_int i) then string_of_int i
  else Printf.sprintf "%g" f

let color_to_css (c : Color.t) =
  let r = Float.to_int (Float.round (c.r *. 255.0)) in
  let g = Float.to_int (Float.round (c.g *. 255.0)) in
  let b = Float.to_int (Float.round (c.b *. 255.0)) in
  if Float.equal c.a 1.0 then Printf.sprintf "rgba(%d,%d,%d,1)" r g b
  else Printf.sprintf "rgba(%d,%d,%d,%s)" r g b (fmt_float c.a)

let fresh_id ctx =
  let id = ctx.next_id in
  ctx.next_id <- id + 1;
  id

let gradient_stop_to_svg (stop : Paint.gradient_stop) =
  Printf.sprintf "<stop offset=\"%s\" stop-color=\"%s\"/>"
    (fmt_float stop.offset) (color_to_css stop.color)

let stops_to_svg stops = String.concat "" (List.map gradient_stop_to_svg stops)

let paint_to_fill_attr ctx (paint : Paint.t) =
  match paint with
  | Solid c -> color_to_css c
  | No_paint -> "none"
  | Linear_gradient { x0; y0; x1; y1; stops } ->
      let id = fresh_id ctx in
      let grad_id = Printf.sprintf "grad-%d" id in
      Buffer.add_string ctx.defs
        (Printf.sprintf
           "<linearGradient id=\"%s\" x1=\"%s\" y1=\"%s\" x2=\"%s\" \
            y2=\"%s\">%s</linearGradient>"
           grad_id (fmt_float x0) (fmt_float y0) (fmt_float x1) (fmt_float y1)
           (stops_to_svg stops));
      Printf.sprintf "url(#%s)" grad_id
  | Radial_gradient { cx; cy; r; stops } ->
      let id = fresh_id ctx in
      let grad_id = Printf.sprintf "grad-%d" id in
      Buffer.add_string ctx.defs
        (Printf.sprintf
           "<radialGradient id=\"%s\" cx=\"%s\" cy=\"%s\" \
            r=\"%s\">%s</radialGradient>"
           grad_id (fmt_float cx) (fmt_float cy) (fmt_float r)
           (stops_to_svg stops));
      Printf.sprintf "url(#%s)" grad_id

let line_cap_to_string (cap : Paint.line_cap) =
  match cap with
  | Butt -> "butt"
  | Round_cap -> "round"
  | Square -> "square"

let line_join_to_string (join : Paint.line_join) =
  match join with
  | Miter -> "miter"
  | Round_join -> "round"
  | Bevel -> "bevel"

let stroke_to_attrs ctx (s : Paint.stroke) =
  let paint_val = paint_to_fill_attr ctx s.paint in
  let parts = [ Printf.sprintf "stroke=\"%s\"" paint_val ] in
  let parts =
    parts @ [ Printf.sprintf "stroke-width=\"%s\"" (fmt_float s.width) ]
  in
  let parts =
    match s.dash with
    | [] -> parts
    | dash ->
        let dash_str = String.concat " " (List.map fmt_float dash) in
        parts
        @ [
            Printf.sprintf "stroke-dasharray=\"%s\"" dash_str;
            Printf.sprintf "stroke-dashoffset=\"%s\"" (fmt_float s.dash_offset);
          ]
  in
  let parts =
    parts
    @ [
        Printf.sprintf "stroke-linecap=\"%s\"" (line_cap_to_string s.line_cap);
        Printf.sprintf "stroke-linejoin=\"%s\""
          (line_join_to_string s.line_join);
      ]
  in
  String.concat " " parts

let rad_to_deg r = r *. 180.0 /. Float.pi

let transform_to_attr (t : Transform.t) =
  match t with
  | Translate { dx; dy } ->
      Printf.sprintf "translate(%s %s)" (fmt_float dx) (fmt_float dy)
  | Scale { sx; sy } ->
      Printf.sprintf "scale(%s %s)" (fmt_float sx) (fmt_float sy)
  | Rotate angle -> Printf.sprintf "rotate(%s)" (fmt_float (rad_to_deg angle))
  | Rotate_around { angle; cx; cy } ->
      Printf.sprintf "rotate(%s %s %s)"
        (fmt_float (rad_to_deg angle))
        (fmt_float cx) (fmt_float cy)
  | Skew { sx; sy } ->
      Printf.sprintf "skewX(%s) skewY(%s)"
        (fmt_float (rad_to_deg sx))
        (fmt_float (rad_to_deg sy))
  | Matrix { a; b; c; d; e; f } ->
      Printf.sprintf "matrix(%s %s %s %s %s %s)" (fmt_float a) (fmt_float b)
        (fmt_float c) (fmt_float d) (fmt_float e) (fmt_float f)

let transforms_to_attr ts = String.concat " " (List.map transform_to_attr ts)

(** Approximate a circular arc as cubic Bezier curves. Uses the standard
    approach of splitting arcs > π/2 into segments. *)
let arc_to_beziers ~cx ~cy ~r ~start_angle ~end_angle =
  let sweep = end_angle -. start_angle in
  let abs_sweep = Float.abs sweep in
  (* Split into segments of at most π/2 *)
  let n = max 1 (Float.to_int (Float.round (abs_sweep /. (Float.pi /. 2.0)))) in
  let n =
    if Float.compare (abs_sweep /. Float.of_int n) (Float.pi /. 2.0) > 0 then
      n + 1
    else n
  in
  let step = sweep /. Float.of_int n in
  (* mutable: accumulator for imperative loop; reversed and flipped at end *)
  let acc = ref [] in
  for i = n - 1 downto 0 do
    let a1 = start_angle +. (Float.of_int i *. step) in
    let a2 = a1 +. step in
    let alpha = (a2 -. a1) /. 2.0 in
    let cos_a = Float.cos alpha in
    let k = 4.0 /. 3.0 *. (1.0 -. cos_a) /. Float.sin alpha in
    let sin_a1 = Float.sin a1 in
    let cos_a1 = Float.cos a1 in
    let sin_a2 = Float.sin a2 in
    let cos_a2 = Float.cos a2 in
    let x1 = cx +. (r *. cos_a1) in
    let y1 = cy +. (r *. sin_a1) in
    let x2 = cx +. (r *. cos_a2) in
    let y2 = cy +. (r *. sin_a2) in
    let cp1x = x1 -. (k *. r *. sin_a1) in
    let cp1y = y1 +. (k *. r *. cos_a1) in
    let cp2x = x2 +. (k *. r *. sin_a2) in
    let cp2y = y2 -. (k *. r *. cos_a2) in
    acc := Path.bezier_to ~cp1x ~cp1y ~cp2x ~cp2y ~x:x2 ~y:y2 :: !acc;
    if i = 0 then acc := Path.move_to ~x:x1 ~y:y1 :: !acc
  done;
  !acc

let rec segment_to_d (seg : Path.segment) =
  match seg with
  | Move_to { x; y } -> Printf.sprintf "M %s %s" (fmt_float x) (fmt_float y)
  | Line_to { x; y } -> Printf.sprintf "L %s %s" (fmt_float x) (fmt_float y)
  | Bezier_to { cp1x; cp1y; cp2x; cp2y; x; y } ->
      Printf.sprintf "C %s %s %s %s %s %s" (fmt_float cp1x) (fmt_float cp1y)
        (fmt_float cp2x) (fmt_float cp2y) (fmt_float x) (fmt_float y)
  | Quad_to { cpx; cpy; x; y } ->
      Printf.sprintf "Q %s %s %s %s" (fmt_float cpx) (fmt_float cpy)
        (fmt_float x) (fmt_float y)
  | Arc_to { cx; cy; r; start_angle; end_angle } ->
      let beziers = arc_to_beziers ~cx ~cy ~r ~start_angle ~end_angle in
      String.concat " " (List.map segment_to_d beziers)
  | Close -> "Z"

let path_to_d segs = String.concat " " (List.map segment_to_d segs)

let blend_to_css (b : Scene.blend) =
  match b with
  | Normal -> "normal"
  | Multiply -> "multiply"
  | Screen -> "screen"
  | Overlay -> "overlay"
  | Darken -> "darken"
  | Lighten -> "lighten"
  | Color_dodge -> "color-dodge"
  | Color_burn -> "color-burn"
  | Hard_light -> "hard-light"
  | Soft_light -> "soft-light"
  | Difference -> "difference"
  | Exclusion -> "exclusion"

let xml_escape s =
  let buf = Buffer.create (String.length s) in
  String.iter
    (fun c ->
      match c with
      | '&' -> Buffer.add_string buf "&amp;"
      | '<' -> Buffer.add_string buf "&lt;"
      | '>' -> Buffer.add_string buf "&gt;"
      | '"' -> Buffer.add_string buf "&quot;"
      | '\'' -> Buffer.add_string buf "&#39;"
      | c -> Buffer.add_char buf c)
    s;
  Buffer.contents buf

let text_anchor_to_string (a : Scene.text_anchor) =
  match a with
  | Start -> "start"
  | Middle -> "middle"
  | End_anchor -> "end"

let text_baseline_to_string (b : Scene.text_baseline) =
  match b with
  | Top -> "text-before-edge"
  | Middle_baseline -> "central"
  | Bottom -> "text-after-edge"
  | Alphabetic -> "alphabetic"

let font_family_to_attr (f : Nopal_style.Font.family) =
  Nopal_style.Font.family_to_css_string f

let font_weight_to_attr (w : Nopal_style.Font.weight) =
  string_of_int (Nopal_style.Font.weight_to_int w)

let opt_stroke_attrs ctx stroke_opt =
  match stroke_opt with
  | None -> ""
  | Some s -> " " ^ stroke_to_attrs ctx s

let rec render_node ctx buf (node : Scene.t) =
  match node with
  | Rect { x; y; w; h; rx; ry; fill; stroke } ->
      let fill_val = paint_to_fill_attr ctx fill in
      Buffer.add_string buf
        (Printf.sprintf "<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\""
           (fmt_float x) (fmt_float y) (fmt_float w) (fmt_float h));
      if not (Float.equal rx 0.0) then
        Buffer.add_string buf (Printf.sprintf " rx=\"%s\"" (fmt_float rx));
      if not (Float.equal ry 0.0) then
        Buffer.add_string buf (Printf.sprintf " ry=\"%s\"" (fmt_float ry));
      Buffer.add_string buf (Printf.sprintf " fill=\"%s\"" fill_val);
      Buffer.add_string buf (opt_stroke_attrs ctx stroke);
      Buffer.add_string buf "/>"
  | Circle { cx; cy; r; fill; stroke } ->
      let fill_val = paint_to_fill_attr ctx fill in
      Buffer.add_string buf
        (Printf.sprintf "<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\""
           (fmt_float cx) (fmt_float cy) (fmt_float r) fill_val);
      Buffer.add_string buf (opt_stroke_attrs ctx stroke);
      Buffer.add_string buf "/>"
  | Ellipse { cx; cy; rx; ry; fill; stroke } ->
      let fill_val = paint_to_fill_attr ctx fill in
      Buffer.add_string buf
        (Printf.sprintf
           "<ellipse cx=\"%s\" cy=\"%s\" rx=\"%s\" ry=\"%s\" fill=\"%s\""
           (fmt_float cx) (fmt_float cy) (fmt_float rx) (fmt_float ry) fill_val);
      Buffer.add_string buf (opt_stroke_attrs ctx stroke);
      Buffer.add_string buf "/>"
  | Line { x1; y1; x2; y2; stroke = s } ->
      Buffer.add_string buf
        (Printf.sprintf "<line x1=\"%s\" y1=\"%s\" x2=\"%s\" y2=\"%s\" %s/>"
           (fmt_float x1) (fmt_float y1) (fmt_float x2) (fmt_float y2)
           (stroke_to_attrs ctx s))
  | Path { segments; fill; stroke } ->
      let fill_val = paint_to_fill_attr ctx fill in
      let d = path_to_d segments in
      Buffer.add_string buf
        (Printf.sprintf "<path d=\"%s\" fill=\"%s\"" d fill_val);
      Buffer.add_string buf (opt_stroke_attrs ctx stroke);
      Buffer.add_string buf "/>"
  | Polygon { points; fill; stroke } ->
      let fill_val = paint_to_fill_attr ctx fill in
      let pts =
        String.concat " "
          (List.map
             (fun (x, y) -> Printf.sprintf "%s,%s" (fmt_float x) (fmt_float y))
             points)
      in
      Buffer.add_string buf
        (Printf.sprintf "<polygon points=\"%s\" fill=\"%s\"" pts fill_val);
      Buffer.add_string buf (opt_stroke_attrs ctx stroke);
      Buffer.add_string buf "/>"
  | Polyline { points; stroke = s } ->
      let pts =
        String.concat " "
          (List.map
             (fun (x, y) -> Printf.sprintf "%s,%s" (fmt_float x) (fmt_float y))
             points)
      in
      Buffer.add_string buf
        (Printf.sprintf "<polyline points=\"%s\" fill=\"none\" %s/>" pts
           (stroke_to_attrs ctx s))
  | Text
      {
        x;
        y;
        content;
        font_size;
        font_family;
        font_weight;
        fill;
        anchor;
        baseline;
      } ->
      let fill_val = paint_to_fill_attr ctx fill in
      Buffer.add_string buf
        (Printf.sprintf
           "<text x=\"%s\" y=\"%s\" font-size=\"%s\" font-family=\"%s\" \
            font-weight=\"%s\" fill=\"%s\" text-anchor=\"%s\" \
            dominant-baseline=\"%s\">%s</text>"
           (fmt_float x) (fmt_float y) (fmt_float font_size)
           (font_family_to_attr font_family)
           (font_weight_to_attr font_weight)
           fill_val
           (text_anchor_to_string anchor)
           (text_baseline_to_string baseline)
           (xml_escape content))
  | Group { opacity; blend; transforms; children } ->
      Buffer.add_string buf "<g";
      if not (Float.equal opacity 1.0) then
        Buffer.add_string buf
          (Printf.sprintf " opacity=\"%s\"" (fmt_float opacity));
      (match blend with
      | Normal -> ()
      | b ->
          Buffer.add_string buf
            (Printf.sprintf " style=\"mix-blend-mode:%s\"" (blend_to_css b)));
      (match transforms with
      | [] -> ()
      | ts ->
          Buffer.add_string buf
            (Printf.sprintf " transform=\"%s\"" (transforms_to_attr ts)));
      Buffer.add_string buf ">";
      List.iter (render_node ctx buf) children;
      Buffer.add_string buf "</g>"
  | Clip { shape; children } ->
      let id = fresh_id ctx in
      let clip_id = Printf.sprintf "clip-%d" id in
      let shape_buf = Buffer.create 64 in
      render_node ctx shape_buf shape;
      Buffer.add_string ctx.defs
        (Printf.sprintf "<clipPath id=\"%s\">%s</clipPath>" clip_id
           (Buffer.contents shape_buf));
      Buffer.add_string buf
        (Printf.sprintf "<g clip-path=\"url(#%s)\">" clip_id);
      List.iter (render_node ctx buf) children;
      Buffer.add_string buf "</g>"

let defs_to_string ctx =
  let s = Buffer.contents ctx.defs in
  if String.length s = 0 then "" else Printf.sprintf "<defs>%s</defs>" s

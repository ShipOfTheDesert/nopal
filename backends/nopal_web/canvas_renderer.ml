open Brr_canvas

let device_pixel_ratio () =
  let v = Jv.get Jv.global "devicePixelRatio" in
  if Jv.is_undefined v then 1.0 else Jv.to_float v

let setup_hidpi el ctx ~width ~height =
  let dpr = device_pixel_ratio () in
  let phys_w = int_of_float (width *. dpr) in
  let phys_h = int_of_float (height *. dpr) in
  Canvas.set_w (Canvas.of_el el) phys_w;
  Canvas.set_h (Canvas.of_el el) phys_h;
  Brr.El.set_inline_style (Jstr.v "width")
    (Jstr.v (Printf.sprintf "%gpx" width))
    el;
  Brr.El.set_inline_style (Jstr.v "height")
    (Jstr.v (Printf.sprintf "%gpx" height))
    el;
  C2d.reset_transform ctx;
  C2d.scale ctx ~sx:dpr ~sy:dpr

let color_to_css (c : Nopal_draw.Color.t) =
  let r = Float.to_int (Float.round (c.r *. 255.0)) in
  let g = Float.to_int (Float.round (c.g *. 255.0)) in
  let b = Float.to_int (Float.round (c.b *. 255.0)) in
  Jstr.v (Printf.sprintf "rgba(%d,%d,%d,%.3f)" r g b c.a)

let paint_to_style ctx (paint : Nopal_draw.Paint.t) =
  match paint with
  | Solid c -> C2d.color (color_to_css c)
  | No_paint -> C2d.color (Jstr.v "rgba(0,0,0,0.000)")
  | Linear_gradient { x0; y0; x1; y1; stops } ->
      let css_stops =
        List.map
          (fun (s : Nopal_draw.Paint.gradient_stop) ->
            (s.offset, color_to_css s.color))
          stops
      in
      C2d.gradient_style
        (C2d.linear_gradient ctx ~x0 ~y0 ~x1 ~y1 ~stops:css_stops)
  | Radial_gradient { cx; cy; r; stops } ->
      let css_stops =
        List.map
          (fun (s : Nopal_draw.Paint.gradient_stop) ->
            (s.offset, color_to_css s.color))
          stops
      in
      C2d.gradient_style
        (C2d.radial_gradient ctx ~x0:cx ~y0:cy ~r0:0.0 ~x1:cx ~y1:cy ~r1:r
           ~stops:css_stops)

let set_fill_paint ctx paint = C2d.set_fill_style ctx (paint_to_style ctx paint)

let set_stroke_paint ctx paint =
  C2d.set_stroke_style ctx (paint_to_style ctx paint)

let line_cap_to_brr (cap : Nopal_draw.Paint.line_cap) =
  match cap with
  | Butt -> C2d.Line_cap.butt
  | Round_cap -> C2d.Line_cap.round
  | Square -> C2d.Line_cap.square

let line_join_to_brr (join : Nopal_draw.Paint.line_join) =
  match join with
  | Miter -> C2d.Line_join.miter
  | Round_join -> C2d.Line_join.round
  | Bevel -> C2d.Line_join.bevel

let apply_stroke_style ctx (s : Nopal_draw.Paint.stroke) =
  set_stroke_paint ctx s.paint;
  C2d.set_line_width ctx s.width;
  C2d.set_line_cap ctx (line_cap_to_brr s.line_cap);
  C2d.set_line_join ctx (line_join_to_brr s.line_join);
  C2d.set_line_dash ctx s.dash;
  C2d.set_line_dash_offset ctx s.dash_offset

let build_rounded_rect_path ~x ~y ~w ~h ~rx ~ry =
  let p = C2d.Path.create () in
  let rx = Float.min rx (w /. 2.0) in
  let ry = Float.min ry (h /. 2.0) in
  C2d.Path.move_to p ~x:(x +. rx) ~y;
  C2d.Path.line_to p ~x:(x +. w -. rx) ~y;
  C2d.Path.ellipse p
    ~cx:(x +. w -. rx)
    ~cy:(y +. ry) ~rx ~ry ~rot:0.0 ~start:(-.Float.pi /. 2.0) ~stop:0.0;
  C2d.Path.line_to p ~x:(x +. w) ~y:(y +. h -. ry);
  C2d.Path.ellipse p
    ~cx:(x +. w -. rx)
    ~cy:(y +. h -. ry)
    ~rx ~ry ~rot:0.0 ~start:0.0 ~stop:(Float.pi /. 2.0);
  C2d.Path.line_to p ~x:(x +. rx) ~y:(y +. h);
  C2d.Path.ellipse p ~cx:(x +. rx)
    ~cy:(y +. h -. ry)
    ~rx ~ry ~rot:0.0 ~start:(Float.pi /. 2.0) ~stop:Float.pi;
  C2d.Path.line_to p ~x ~y:(y +. ry);
  C2d.Path.ellipse p ~cx:(x +. rx) ~cy:(y +. ry) ~rx ~ry ~rot:0.0
    ~start:Float.pi
    ~stop:(3.0 *. Float.pi /. 2.0);
  C2d.Path.close p;
  p

let blend_to_composite (b : Nopal_draw.Scene.blend) =
  match b with
  | Normal -> C2d.Composite_op.source_over
  | Multiply -> C2d.Composite_op.multiply
  | Screen -> C2d.Composite_op.screen
  | Overlay -> C2d.Composite_op.overlay
  | Darken -> C2d.Composite_op.darken
  | Lighten -> C2d.Composite_op.lighten
  | Color_dodge -> C2d.Composite_op.color_dodge
  | Color_burn -> C2d.Composite_op.color_burn
  | Hard_light -> C2d.Composite_op.hard_light
  | Soft_light -> C2d.Composite_op.soft_light
  | Difference -> C2d.Composite_op.difference
  | Exclusion -> C2d.Composite_op.exclusion

let text_anchor_to_brr (a : Nopal_draw.Scene.text_anchor) =
  match a with
  | Start -> C2d.Text_align.start
  | Middle -> C2d.Text_align.center
  | End_anchor -> C2d.Text_align.end'

let text_baseline_to_brr (b : Nopal_draw.Scene.text_baseline) =
  match b with
  | Top -> C2d.Text_baseline.top
  | Middle_baseline -> C2d.Text_baseline.middle
  | Bottom -> C2d.Text_baseline.bottom
  | Alphabetic -> C2d.Text_baseline.alphabetic

let build_path segments =
  let p = C2d.Path.create () in
  List.iter
    (fun (seg : Nopal_draw.Path.segment) ->
      match seg with
      | Move_to { x; y } -> C2d.Path.move_to p ~x ~y
      | Line_to { x; y } -> C2d.Path.line_to p ~x ~y
      | Bezier_to { cp1x; cp1y; cp2x; cp2y; x; y } ->
          C2d.Path.ccurve_to p ~cx:cp1x ~cy:cp1y ~cx':cp2x ~cy':cp2y ~x ~y
      | Quad_to { cpx; cpy; x; y } -> C2d.Path.qcurve_to p ~cx:cpx ~cy:cpy ~x ~y
      | Arc_to { cx; cy; r; start_angle; end_angle } ->
          C2d.Path.arc p ~cx ~cy ~r ~start:start_angle ~stop:end_angle
      | Close -> C2d.Path.close p)
    segments;
  p

let apply_transform ctx (t : Nopal_draw.Transform.t) =
  match t with
  | Translate { dx; dy } -> C2d.translate ctx ~x:dx ~y:dy
  | Scale { sx; sy } -> C2d.scale ctx ~sx ~sy
  | Rotate angle -> C2d.rotate ctx angle
  | Rotate_around { angle; cx; cy } ->
      C2d.translate ctx ~x:cx ~y:cy;
      C2d.rotate ctx angle;
      C2d.translate ctx ~x:(-.cx) ~y:(-.cy)
  | Skew { sx; sy } ->
      C2d.transform' ctx ~a:1.0 ~b:(tan sy) ~c:(tan sx) ~d:1.0 ~e:0.0 ~f:0.0
  | Matrix { a; b; c; d; e; f } -> C2d.transform' ctx ~a ~b ~c ~d ~e ~f

let fill_and_stroke ctx p fill stroke_opt =
  (match fill with
  | Nopal_draw.Paint.No_paint -> ()
  | Nopal_draw.Paint.Solid _
  | Nopal_draw.Paint.Linear_gradient _
  | Nopal_draw.Paint.Radial_gradient _ ->
      set_fill_paint ctx fill;
      C2d.fill ctx p);
  match stroke_opt with
  | None -> ()
  | Some s ->
      apply_stroke_style ctx s;
      C2d.stroke ctx p

let rec render_node ctx (node : Nopal_draw.Scene.t) =
  match node with
  | Rect { x; y; w; h; rx; ry; fill; stroke } ->
      let p =
        if Float.equal rx 0.0 && Float.equal ry 0.0 then begin
          let p = C2d.Path.create () in
          C2d.Path.rect p ~x ~y ~w ~h;
          p
        end
        else build_rounded_rect_path ~x ~y ~w ~h ~rx ~ry
      in
      fill_and_stroke ctx p fill stroke
  | Circle { cx; cy; r; fill; stroke } ->
      let p = C2d.Path.create () in
      C2d.Path.arc p ~cx ~cy ~r ~start:0.0 ~stop:(2.0 *. Float.pi);
      fill_and_stroke ctx p fill stroke
  | Ellipse { cx; cy; rx; ry; fill; stroke } ->
      let p = C2d.Path.create () in
      C2d.Path.ellipse p ~cx ~cy ~rx ~ry ~rot:0.0 ~start:0.0
        ~stop:(2.0 *. Float.pi);
      fill_and_stroke ctx p fill stroke
  | Line { x1; y1; x2; y2; stroke } ->
      let p = C2d.Path.create () in
      C2d.Path.move_to p ~x:x1 ~y:y1;
      C2d.Path.line_to p ~x:x2 ~y:y2;
      apply_stroke_style ctx stroke;
      C2d.stroke ctx p
  | Path { segments; fill; stroke } ->
      let p = build_path segments in
      fill_and_stroke ctx p fill stroke
  | Polygon { points; fill; stroke } ->
      let p = C2d.Path.create () in
      (match points with
      | [] -> ()
      | (x, y) :: rest ->
          C2d.Path.move_to p ~x ~y;
          List.iter (fun (x, y) -> C2d.Path.line_to p ~x ~y) rest;
          C2d.Path.close p);
      fill_and_stroke ctx p fill stroke
  | Polyline { points; stroke } ->
      let p = C2d.Path.create () in
      (match points with
      | [] -> ()
      | (x, y) :: rest ->
          C2d.Path.move_to p ~x ~y;
          List.iter (fun (x, y) -> C2d.Path.line_to p ~x ~y) rest);
      apply_stroke_style ctx stroke;
      C2d.stroke ctx p
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
      C2d.save ctx;
      let weight_s = Nopal_style.Font.weight_to_css_string font_weight in
      let family_s = Nopal_style.Font.family_to_css_string font_family in
      let font_str = Printf.sprintf "%s %gpx %s" weight_s font_size family_s in
      C2d.set_font ctx (Jstr.v font_str);
      C2d.set_text_align ctx (text_anchor_to_brr anchor);
      C2d.set_text_baseline ctx (text_baseline_to_brr baseline);
      set_fill_paint ctx fill;
      C2d.fill_text ctx (Jstr.v content) ~x ~y;
      C2d.restore ctx
  | Group { opacity; blend; transforms; children } ->
      C2d.save ctx;
      C2d.set_global_alpha ctx (C2d.global_alpha ctx *. opacity);
      C2d.set_global_composite_op ctx (blend_to_composite blend);
      List.iter (apply_transform ctx) transforms;
      List.iter (render_node ctx) children;
      C2d.restore ctx
  | Clip { shape; children } ->
      C2d.save ctx;
      let clip_path = shape_to_path shape in
      C2d.clip ctx clip_path;
      List.iter (render_node ctx) children;
      C2d.restore ctx

and shape_to_path (shape : Nopal_draw.Scene.t) =
  match shape with
  | Rect { x; y; w; h; rx; ry; _ } ->
      if Float.equal rx 0.0 && Float.equal ry 0.0 then begin
        let p = C2d.Path.create () in
        C2d.Path.rect p ~x ~y ~w ~h;
        p
      end
      else build_rounded_rect_path ~x ~y ~w ~h ~rx ~ry
  | Circle { cx; cy; r; _ } ->
      let p = C2d.Path.create () in
      C2d.Path.arc p ~cx ~cy ~r ~start:0.0 ~stop:(2.0 *. Float.pi);
      p
  | Ellipse { cx; cy; rx; ry; _ } ->
      let p = C2d.Path.create () in
      C2d.Path.ellipse p ~cx ~cy ~rx ~ry ~rot:0.0 ~start:0.0
        ~stop:(2.0 *. Float.pi);
      p
  | Path { segments; _ } -> build_path segments
  | Polygon { points; _ } ->
      let p = C2d.Path.create () in
      (match points with
      | [] -> ()
      | (x, y) :: rest ->
          C2d.Path.move_to p ~x ~y;
          List.iter (fun (x, y) -> C2d.Path.line_to p ~x ~y) rest;
          C2d.Path.close p);
      p
  | Line _
  | Polyline _
  | Text _
  | Group _
  | Clip _ ->
      (* These nodes have no meaningful closed shape for clipping. Return an
         empty path so clip regions degrade gracefully rather than failing. *)
      C2d.Path.create ()

let render ctx scene =
  let canvas_opt = C2d.canvas ctx in
  (match canvas_opt with
  | Some c ->
      let w = Float.of_int (Canvas.w c) in
      let h = Float.of_int (Canvas.h c) in
      C2d.clear_rect ctx ~x:0.0 ~y:0.0 ~w ~h
  | None -> ());
  C2d.save ctx;
  List.iter (render_node ctx) scene;
  C2d.restore ctx

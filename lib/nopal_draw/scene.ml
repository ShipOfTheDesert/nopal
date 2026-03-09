type blend =
  | Normal
  | Multiply
  | Screen
  | Overlay
  | Darken
  | Lighten
  | Color_dodge
  | Color_burn
  | Hard_light
  | Soft_light
  | Difference
  | Exclusion

type text_anchor = Start | Middle | End_anchor
type text_baseline = Top | Middle_baseline | Bottom | Alphabetic

type t =
  | Rect of {
      x : float;
      y : float;
      w : float;
      h : float;
      rx : float;
      ry : float;
      fill : Paint.t;
      stroke : Paint.stroke option;
    }
  | Circle of {
      cx : float;
      cy : float;
      r : float;
      fill : Paint.t;
      stroke : Paint.stroke option;
    }
  | Ellipse of {
      cx : float;
      cy : float;
      rx : float;
      ry : float;
      fill : Paint.t;
      stroke : Paint.stroke option;
    }
  | Line of {
      x1 : float;
      y1 : float;
      x2 : float;
      y2 : float;
      stroke : Paint.stroke;
    }
  | Path of {
      segments : Path.segment list;
      fill : Paint.t;
      stroke : Paint.stroke option;
    }
  | Polygon of {
      points : (float * float) list;
      fill : Paint.t;
      stroke : Paint.stroke option;
    }
  | Polyline of { points : (float * float) list; stroke : Paint.stroke }
  | Text of {
      x : float;
      y : float;
      content : string;
      font_size : float;
      font_family : Nopal_style.Font.family;
      font_weight : Nopal_style.Font.weight;
      fill : Paint.t;
      anchor : text_anchor;
      baseline : text_baseline;
    }
  | Group of {
      opacity : float;
      blend : blend;
      transforms : Transform.t list;
      children : t list;
    }
  | Clip of { shape : t; children : t list }

let rect ?(rx = 0.0) ?(ry = 0.0) ?(fill = Paint.no_paint) ?stroke ~x ~y ~w ~h ()
    =
  Rect { x; y; w; h; rx; ry; fill; stroke }

let circle ?(fill = Paint.no_paint) ?stroke ~cx ~cy ~r () =
  Circle { cx; cy; r; fill; stroke }

let ellipse ?(fill = Paint.no_paint) ?stroke ~cx ~cy ~rx ~ry () =
  Ellipse { cx; cy; rx; ry; fill; stroke }

let line ?stroke ~x1 ~y1 ~x2 ~y2 () =
  let stroke =
    match stroke with
    | Some s -> s
    | None -> Paint.stroke (Paint.solid Color.black)
  in
  Line { x1; y1; x2; y2; stroke }

let path ?(fill = Paint.no_paint) ?stroke segments =
  Path { segments; fill; stroke }

let polygon ?(fill = Paint.no_paint) ?stroke points =
  Polygon { points; fill; stroke }

let polyline ?stroke points =
  let stroke =
    match stroke with
    | Some s -> s
    | None -> Paint.stroke (Paint.solid Color.black)
  in
  Polyline { points; stroke }

let text ?(font_size = 16.0) ?(font_family = Nopal_style.Font.Sans_serif)
    ?(font_weight = Nopal_style.Font.Normal) ?(fill = Paint.solid Color.black)
    ?(anchor = Start) ?(baseline = Alphabetic) ~x ~y content =
  Text
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
    }

let group ?(opacity = 1.0) ?(blend = Normal) ?(transforms = []) children =
  Group { opacity; blend; transforms; children }

let clip ~shape children = Clip { shape; children }

let equal_blend a b =
  match (a, b) with
  | Normal, Normal -> true
  | Multiply, Multiply -> true
  | Screen, Screen -> true
  | Overlay, Overlay -> true
  | Darken, Darken -> true
  | Lighten, Lighten -> true
  | Color_dodge, Color_dodge -> true
  | Color_burn, Color_burn -> true
  | Hard_light, Hard_light -> true
  | Soft_light, Soft_light -> true
  | Difference, Difference -> true
  | Exclusion, Exclusion -> true
  | Normal, _
  | Multiply, _
  | Screen, _
  | Overlay, _
  | Darken, _
  | Lighten, _
  | Color_dodge, _
  | Color_burn, _
  | Hard_light, _
  | Soft_light, _
  | Difference, _
  | Exclusion, _ ->
      false

let equal_text_anchor a b =
  match (a, b) with
  | Start, Start -> true
  | Middle, Middle -> true
  | End_anchor, End_anchor -> true
  | Start, _
  | Middle, _
  | End_anchor, _ ->
      false

let equal_text_baseline a b =
  match (a, b) with
  | Top, Top -> true
  | Middle_baseline, Middle_baseline -> true
  | Bottom, Bottom -> true
  | Alphabetic, Alphabetic -> true
  | Top, _
  | Middle_baseline, _
  | Bottom, _
  | Alphabetic, _ ->
      false

let equal_opt f a b =
  match (a, b) with
  | None, None -> true
  | Some a, Some b -> f a b
  | None, Some _
  | Some _, None ->
      false

let equal_points a b =
  List.length a = List.length b
  && List.for_all2
       (fun (ax, ay) (bx, by) -> Float.equal ax bx && Float.equal ay by)
       a b

let rec equal a b =
  match (a, b) with
  | Rect a, Rect b ->
      Float.equal a.x b.x
      && Float.equal a.y b.y
      && Float.equal a.w b.w
      && Float.equal a.h b.h
      && Float.equal a.rx b.rx
      && Float.equal a.ry b.ry
      && Paint.equal a.fill b.fill
      && equal_opt Paint.equal_stroke a.stroke b.stroke
  | Circle a, Circle b ->
      Float.equal a.cx b.cx
      && Float.equal a.cy b.cy
      && Float.equal a.r b.r
      && Paint.equal a.fill b.fill
      && equal_opt Paint.equal_stroke a.stroke b.stroke
  | Ellipse a, Ellipse b ->
      Float.equal a.cx b.cx
      && Float.equal a.cy b.cy
      && Float.equal a.rx b.rx
      && Float.equal a.ry b.ry
      && Paint.equal a.fill b.fill
      && equal_opt Paint.equal_stroke a.stroke b.stroke
  | Line a, Line b ->
      Float.equal a.x1 b.x1
      && Float.equal a.y1 b.y1
      && Float.equal a.x2 b.x2
      && Float.equal a.y2 b.y2
      && Paint.equal_stroke a.stroke b.stroke
  | Path a, Path b ->
      List.length a.segments = List.length b.segments
      && List.for_all2 Path.equal_segment a.segments b.segments
      && Paint.equal a.fill b.fill
      && equal_opt Paint.equal_stroke a.stroke b.stroke
  | Polygon a, Polygon b ->
      equal_points a.points b.points
      && Paint.equal a.fill b.fill
      && equal_opt Paint.equal_stroke a.stroke b.stroke
  | Polyline a, Polyline b ->
      equal_points a.points b.points && Paint.equal_stroke a.stroke b.stroke
  | Text a, Text b ->
      Float.equal a.x b.x
      && Float.equal a.y b.y
      && String.equal a.content b.content
      && Float.equal a.font_size b.font_size
      && Nopal_style.Font.equal_family a.font_family b.font_family
      && Nopal_style.Font.equal_weight a.font_weight b.font_weight
      && Paint.equal a.fill b.fill
      && equal_text_anchor a.anchor b.anchor
      && equal_text_baseline a.baseline b.baseline
  | Group a, Group b ->
      Float.equal a.opacity b.opacity
      && equal_blend a.blend b.blend
      && List.length a.transforms = List.length b.transforms
      && List.for_all2 Transform.equal a.transforms b.transforms
      && List.length a.children = List.length b.children
      && List.for_all2 equal a.children b.children
  | Clip a, Clip b ->
      equal a.shape b.shape
      && List.length a.children = List.length b.children
      && List.for_all2 equal a.children b.children
  | Rect _, _
  | Circle _, _
  | Ellipse _, _
  | Line _, _
  | Path _, _
  | Polygon _, _
  | Polyline _, _
  | Text _, _
  | Group _, _
  | Clip _, _ ->
      false

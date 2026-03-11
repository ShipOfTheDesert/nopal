let tooltip_offset = 8.0
let tip_font_size = 12.0
let tip_pad = 6.0
let bg_color = Nopal_draw.Color.rgba ~r:0.13 ~g:0.13 ~b:0.13 ~a:0.92
let text_color = Nopal_draw.Color.rgba ~r:1.0 ~g:1.0 ~b:1.0 ~a:1.0

(* Estimate width from text length — approximate since canvas text is
   variable-width. Uses 0.6 × font_size per character as a rough measure. *)
let estimate_width s =
  let char_w = tip_font_size *. 0.6 in
  (Float.of_int (String.length s) *. char_w) +. (tip_pad *. 2.0)

let text s = s

let scene ~x ~y ~chart_width ~chart_height content =
  let tip_w = estimate_width content in
  let tip_h = tip_font_size +. (tip_pad *. 2.0) in
  (* Determine if we need to flip *)
  let flip_x = x +. tooltip_offset +. tip_w > chart_width in
  let flip_y = y +. tooltip_offset +. tip_h > chart_height in
  let tx =
    if flip_x then Float.max 0.0 (x -. tooltip_offset -. tip_w)
    else x +. tooltip_offset
  in
  let ty =
    if flip_y then Float.max 0.0 (y -. tooltip_offset -. tip_h)
    else y +. tooltip_offset
  in
  [
    Nopal_draw.Scene.rect
      ~fill:(Nopal_draw.Paint.solid bg_color)
      ~rx:4.0 ~ry:4.0 ~x:tx ~y:ty ~w:tip_w ~h:tip_h ();
    Nopal_draw.Scene.text ~x:(tx +. tip_pad)
      ~y:(ty +. tip_pad +. tip_font_size)
      ~font_size:tip_font_size
      ~fill:(Nopal_draw.Paint.solid text_color)
      content;
  ]

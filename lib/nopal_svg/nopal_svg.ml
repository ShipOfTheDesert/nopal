module Svg_fmt = Svg_fmt

let fmt_float f =
  let i = Float.to_int f in
  if Float.equal f (Float.of_int i) then string_of_int i
  else Printf.sprintf "%g" f

let render ~width ~height scenes =
  let ctx = Svg_fmt.create_ctx () in
  let buf = Buffer.create 1024 in
  List.iter (Svg_fmt.render_node ctx buf) scenes;
  let defs = Svg_fmt.defs_to_string ctx in
  let body = Buffer.contents buf in
  Printf.sprintf
    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 %s %s\">%s%s</svg>"
    (fmt_float width) (fmt_float height) defs body

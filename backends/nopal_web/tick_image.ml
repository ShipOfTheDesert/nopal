let xml_escape s =
  let buf = Buffer.create (String.length s) in
  String.iter
    (fun c ->
      match c with
      | '&' -> Buffer.add_string buf "&amp;"
      | '<' -> Buffer.add_string buf "&lt;"
      | '>' -> Buffer.add_string buf "&gt;"
      | '\'' -> Buffer.add_string buf "&apos;"
      | '"' -> Buffer.add_string buf "&quot;"
      | c -> Buffer.add_char buf c)
    s;
  Buffer.contents buf

let svg_document mark =
  Printf.sprintf
    "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'><polyline \
     points='3.5,8.5 6.5,11.5 12.5,4.5' fill='none' stroke='%s' \
     stroke-width='2' stroke-linecap='round' stroke-linejoin='round'/></svg>"
    (xml_escape (Style_css.color_to_css mark))

let add_percent_encoded buf c =
  match c with
  | 'A' .. 'Z'
  | 'a' .. 'z'
  | '0' .. '9'
  | '-'
  | '.'
  | '_'
  | '~' ->
      Buffer.add_char buf c
  | _ -> Buffer.add_string buf (Printf.sprintf "%%%02X" (Char.code c))

let percent_encode s =
  let buf = Buffer.create (String.length s * 3) in
  String.iter (add_percent_encoded buf) s;
  Buffer.contents buf

let css_url mark =
  "url(\"data:image/svg+xml," ^ percent_encode (svg_document mark) ^ "\")"

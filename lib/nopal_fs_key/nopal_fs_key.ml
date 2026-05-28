let is_unreserved c =
  match c with
  | 'a' .. 'z'
  | '0' .. '9'
  | '-'
  | '_' ->
      true
  | _ -> false

let encode_key key =
  let buf = Buffer.create (String.length key) in
  String.iter
    (fun c ->
      if is_unreserved c then Buffer.add_char buf c
      else Buffer.add_string buf (Printf.sprintf "%%%02X" (Char.code c)))
    key;
  Buffer.contents buf

let hex_value c =
  match c with
  | '0' .. '9' -> Some (Char.code c - Char.code '0')
  | 'A' .. 'F' -> Some (Char.code c - Char.code 'A' + 10)
  | 'a' .. 'f' -> Some (Char.code c - Char.code 'a' + 10)
  | _ -> None

let decode_filename name =
  let len = String.length name in
  let buf = Buffer.create len in
  let rec loop i =
    if i >= len then Some (Buffer.contents buf)
    else
      match name.[i] with
      | '%' -> (
          if i + 2 >= len then None
          else
            match (hex_value name.[i + 1], hex_value name.[i + 2]) with
            | Some hi, Some lo ->
                Buffer.add_char buf (Char.chr ((hi * 16) + lo));
                loop (i + 3)
            | Some _, None
            | None, _ ->
                None)
      | c ->
          Buffer.add_char buf c;
          loop (i + 1)
  in
  loop 0

let slugify s =
  let buf = Buffer.create (String.length s) in
  (* mutable: String.iter provides no accumulator; ref tracks inter-character state *)
  let prev_hyphen = ref true in
  String.iter
    (fun c ->
      match c with
      | 'a' .. 'z'
      | '0' .. '9' ->
          prev_hyphen := false;
          Buffer.add_char buf c
      | 'A' .. 'Z' ->
          prev_hyphen := false;
          Buffer.add_char buf (Char.lowercase_ascii c)
      | _ ->
          if not !prev_hyphen then (
            Buffer.add_char buf '-';
            prev_hyphen := true))
    s;
  let result = Buffer.contents buf in
  let len = String.length result in
  if len > 0 && result.[len - 1] = '-' then String.sub result 0 (len - 1)
  else result

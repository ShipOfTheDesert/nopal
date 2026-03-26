let slugify s =
  s
  |> String.lowercase_ascii
  |> String.to_seq
  |> Seq.map (fun c ->
      match c with
      | 'a' .. 'z'
      | '0' .. '9' ->
          c
      | _ -> '-')
  |> String.of_seq

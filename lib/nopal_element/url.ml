type t = string

type error =
  | Missing_scheme of { input : string }
  | Unsupported_scheme of { input : string; scheme : string }
  | Control_character of { input : string }

let is_scheme_start = function
  | 'a' .. 'z'
  | 'A' .. 'Z' ->
      true
  | _ -> false

let is_scheme_char = function
  | 'a' .. 'z'
  | 'A' .. 'Z'
  | '0' .. '9'
  | '+'
  | '-'
  | '.' ->
      true
  | _ -> false

let is_scheme candidate =
  match String.to_seq candidate () with
  | Seq.Nil -> false
  | Seq.Cons (first, rest) ->
      is_scheme_start first && Seq.for_all is_scheme_char rest

let of_scheme input scheme =
  match String.lowercase_ascii scheme with
  | "http"
  | "https"
  | "mailto"
  | "tel" ->
      Ok input
  | _ -> Error (Unsupported_scheme { input; scheme })

let of_string input =
  match Url_text.has_control_or_surrounding_space input with
  | true -> Error (Control_character { input })
  | false -> (
      match String.index_opt input ':' with
      | None -> Error (Missing_scheme { input })
      | Some colon -> (
          let scheme = String.sub input 0 colon in
          match is_scheme scheme with
          | false -> Error (Missing_scheme { input })
          | true -> of_scheme input scheme))

let to_string t = t

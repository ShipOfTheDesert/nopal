type t = string

type error =
  | Not_absolute of { input : string }
  | Protocol_relative of { input : string }
  | Control_character of { input : string }

let of_rooted input =
  match String.to_seq input () with
  | Seq.Cons ('/', after_root) -> (
      match after_root () with
      | Seq.Cons (('/' | '\\'), _) -> Error (Protocol_relative { input })
      | Seq.Nil
      | Seq.Cons _ ->
          Ok input)
  | Seq.Nil
  | Seq.Cons _ ->
      Error (Not_absolute { input })

let of_string input =
  match Url_text.has_control_or_surrounding_space input with
  | true -> Error (Control_character { input })
  | false -> of_rooted input

let to_string t = t

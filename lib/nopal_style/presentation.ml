type t = Visible | Visually_hidden

let equal a b =
  match (a, b) with
  | Visible, Visible
  | Visually_hidden, Visually_hidden ->
      true
  | Visible, Visually_hidden
  | Visually_hidden, Visible ->
      false

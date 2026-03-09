type family = Sans_serif | Serif | Monospace | Custom of string
type weight = Normal | Bold

let equal_family a b =
  match (a, b) with
  | Sans_serif, Sans_serif -> true
  | Serif, Serif -> true
  | Monospace, Monospace -> true
  | Custom s1, Custom s2 -> String.equal s1 s2
  | (Sans_serif | Serif | Monospace | Custom _), _ -> false

let equal_weight a b =
  match (a, b) with
  | Normal, Normal -> true
  | Bold, Bold -> true
  | (Normal | Bold), _ -> false

let family_to_css_string = function
  | Sans_serif -> "sans-serif"
  | Serif -> "serif"
  | Monospace -> "monospace"
  | Custom name -> "\"" ^ name ^ "\""

let weight_to_css_string = function
  | Normal -> "normal"
  | Bold -> "bold"

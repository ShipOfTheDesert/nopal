type family = System_ui | Sans_serif | Serif | Monospace | Custom of string

type weight =
  | Thin
  | Extra_light
  | Light
  | Normal
  | Medium
  | Semi_bold
  | Bold
  | Extra_bold
  | Black

let equal_family a b =
  match (a, b) with
  | System_ui, System_ui -> true
  | Sans_serif, Sans_serif -> true
  | Serif, Serif -> true
  | Monospace, Monospace -> true
  | Custom s1, Custom s2 -> String.equal s1 s2
  | (System_ui | Sans_serif | Serif | Monospace | Custom _), _ -> false

let equal_weight a b =
  match (a, b) with
  | Thin, Thin -> true
  | Extra_light, Extra_light -> true
  | Light, Light -> true
  | Normal, Normal -> true
  | Medium, Medium -> true
  | Semi_bold, Semi_bold -> true
  | Bold, Bold -> true
  | Extra_bold, Extra_bold -> true
  | Black, Black -> true
  | ( ( Thin | Extra_light | Light | Normal | Medium | Semi_bold | Bold
      | Extra_bold | Black ),
      _ ) ->
      false

let family_to_css_string = function
  | System_ui -> "system-ui"
  | Sans_serif -> "sans-serif"
  | Serif -> "serif"
  | Monospace -> "monospace"
  | Custom name -> "\"" ^ name ^ "\""

let weight_to_int = function
  | Thin -> 100
  | Extra_light -> 200
  | Light -> 300
  | Normal -> 400
  | Medium -> 500
  | Semi_bold -> 600
  | Bold -> 700
  | Extra_bold -> 800
  | Black -> 900

let weight_to_css_string w = string_of_int (weight_to_int w)

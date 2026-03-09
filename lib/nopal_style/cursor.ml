type t = Default | Pointer | Crosshair | Text | Grab | Grabbing | None_cursor

let equal a b =
  match (a, b) with
  | Default, Default -> true
  | Pointer, Pointer -> true
  | Crosshair, Crosshair -> true
  | Text, Text -> true
  | Grab, Grab -> true
  | Grabbing, Grabbing -> true
  | None_cursor, None_cursor -> true
  | (Default | Pointer | Crosshair | Text | Grab | Grabbing | None_cursor), _ ->
      false

let to_css_string = function
  | Default -> "default"
  | Pointer -> "pointer"
  | Crosshair -> "crosshair"
  | Text -> "text"
  | Grab -> "grab"
  | Grabbing -> "grabbing"
  | None_cursor -> "none"

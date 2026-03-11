type t = Compact | Medium | Expanded

let compact_max = 600
let medium_max = 840

let of_width width =
  if width < compact_max then Compact
  else if width < medium_max then Medium
  else Expanded

let equal a b =
  match (a, b) with
  | Compact, Compact -> true
  | Medium, Medium -> true
  | Expanded, Expanded -> true
  | Compact, (Medium | Expanded) -> false
  | Medium, (Compact | Expanded) -> false
  | Expanded, (Compact | Medium) -> false

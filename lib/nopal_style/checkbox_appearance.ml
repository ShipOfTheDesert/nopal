type t = Native | Drawn of { checked : Style.t; mark : Color.t }

let equal a b =
  match (a, b) with
  | Native, Native -> true
  | Drawn { checked = c1; mark = m1 }, Drawn { checked = c2; mark = m2 } ->
      Style.equal c1 c2 && Color.equal m1 m2
  | Native, Drawn _
  | Drawn _, Native ->
      false

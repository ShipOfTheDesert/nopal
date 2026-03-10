type t = { index : int; series : int; cursor_x : float; cursor_y : float }

let equal a b =
  Int.equal a.index b.index
  && Int.equal a.series b.series
  && Float.equal a.cursor_x b.cursor_x
  && Float.equal a.cursor_y b.cursor_y

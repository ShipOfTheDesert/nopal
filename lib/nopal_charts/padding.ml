type t = { top : float; right : float; bottom : float; left : float }

let default = { top = 40.0; right = 20.0; bottom = 40.0; left = 50.0 }

let equal a b =
  Float.equal a.top b.top
  && Float.equal a.right b.right
  && Float.equal a.bottom b.bottom
  && Float.equal a.left b.left

type t =
  | Translate of { dx : float; dy : float }
  | Scale of { sx : float; sy : float }
  | Rotate of float
  | Rotate_around of { angle : float; cx : float; cy : float }
  | Skew of { sx : float; sy : float }
  | Matrix of {
      a : float;
      b : float;
      c : float;
      d : float;
      e : float;
      f : float;
    }

let translate ~dx ~dy = Translate { dx; dy }
let scale ~sx ~sy = Scale { sx; sy }
let rotate angle = Rotate angle
let rotate_around ~angle ~cx ~cy = Rotate_around { angle; cx; cy }
let skew ~sx ~sy = Skew { sx; sy }
let matrix ~a ~b ~c ~d ~e ~f = Matrix { a; b; c; d; e; f }

let equal a b =
  match (a, b) with
  | Translate a, Translate b -> Float.equal a.dx b.dx && Float.equal a.dy b.dy
  | Scale a, Scale b -> Float.equal a.sx b.sx && Float.equal a.sy b.sy
  | Rotate a, Rotate b -> Float.equal a b
  | Rotate_around a, Rotate_around b ->
      Float.equal a.angle b.angle
      && Float.equal a.cx b.cx
      && Float.equal a.cy b.cy
  | Skew a, Skew b -> Float.equal a.sx b.sx && Float.equal a.sy b.sy
  | Matrix a, Matrix b ->
      Float.equal a.a b.a
      && Float.equal a.b b.b
      && Float.equal a.c b.c
      && Float.equal a.d b.d
      && Float.equal a.e b.e
      && Float.equal a.f b.f
  | Translate _, _
  | Scale _, _
  | Rotate _, _
  | Rotate_around _, _
  | Skew _, _
  | Matrix _, _ ->
      false

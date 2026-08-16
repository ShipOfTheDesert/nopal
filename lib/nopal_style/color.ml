type t =
  | Rgba of { r : int; g : int; b : int; a : float }
  | Hex of string
  | Named of string
  | Transparent

let rgba r g b a = Rgba { r; g; b; a }
let hex s = Hex s
let named s = Named s
let transparent = Transparent

let equal a b =
  match (a, b) with
  | Rgba r1, Rgba r2 ->
      Int.equal r1.r r2.r
      && Int.equal r1.g r2.g
      && Int.equal r1.b r2.b
      && Float.equal r1.a r2.a
  | Hex s1, Hex s2 -> String.equal s1 s2
  | Named s1, Named s2 -> String.equal s1 s2
  | Transparent, Transparent -> true
  | (Rgba _ | Hex _ | Named _ | Transparent), _ -> false

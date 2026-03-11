type t =
  | Sequential of { low : Nopal_draw.Color.t; high : Nopal_draw.Color.t }
  | Diverging of {
      low : Nopal_draw.Color.t;
      mid : Nopal_draw.Color.t;
      high : Nopal_draw.Color.t;
      midpoint : float;
    }

let sequential ~low ~high = Sequential { low; high }

let diverging ~low ~mid ~high ?(midpoint = 0.0) () =
  Diverging { low; mid; high; midpoint }

let clamp v = Float.max 0.0 (Float.min 1.0 v)

let apply scale ~min ~max value =
  match scale with
  | Sequential { low; high } ->
      let range = max -. min in
      let t = if Float.equal range 0.0 then 0.0 else (value -. min) /. range in
      Nopal_draw.Color.lerp low high (clamp t)
  | Diverging { low; mid; high; midpoint } ->
      if value <= midpoint then
        let range = midpoint -. min in
        let t =
          if Float.equal range 0.0 then 1.0 else (value -. min) /. range
        in
        Nopal_draw.Color.lerp low mid (clamp t)
      else
        let range = max -. midpoint in
        let t =
          if Float.equal range 0.0 then 0.0 else (value -. midpoint) /. range
        in
        Nopal_draw.Color.lerp mid high (clamp t)

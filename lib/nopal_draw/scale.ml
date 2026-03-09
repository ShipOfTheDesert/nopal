type t = {
  domain_min : float;
  domain_max : float;
  range_min : float;
  range_max : float;
}

let create ~domain:(domain_min, domain_max) ~range:(range_min, range_max) =
  { domain_min; domain_max; range_min; range_max }

let apply t v =
  let span = t.domain_max -. t.domain_min in
  if Float.equal span 0.0 then t.range_min
  else
    let ratio = (v -. t.domain_min) /. span in
    t.range_min +. (ratio *. (t.range_max -. t.range_min))

let invert t v =
  let span = t.range_max -. t.range_min in
  if Float.equal span 0.0 then t.domain_min
  else
    let ratio = (v -. t.range_min) /. span in
    t.domain_min +. (ratio *. (t.domain_max -. t.domain_min))

let equal a b =
  Float.equal a.domain_min b.domain_min
  && Float.equal a.domain_max b.domain_max
  && Float.equal a.range_min b.range_min
  && Float.equal a.range_max b.range_max

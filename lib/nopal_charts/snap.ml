let nearest_index ~x ~data ~target =
  match data with
  | [] -> None
  | first :: rest ->
      let best_idx, _best_dist =
        List.fold_left
          (fun (bi, bd) (i, d) ->
            let dist = Float.abs (x d -. target) in
            if dist < bd then (i, dist) else (bi, bd))
          (0, Float.abs (x first -. target))
          (List.mapi (fun i d -> (i + 1, d)) rest)
      in
      Some best_idx

let nearest_index_sorted ~x ~data ~target =
  let n = Array.length data in
  match n with
  | 0 -> None
  | _ ->
      (* mutable: binary search requires imperative index narrowing *)
      let lo = ref 0 in
      let hi = ref (n - 1) in
      while !lo < !hi do
        let mid = !lo + ((!hi - !lo) / 2) in
        if x data.(mid) < target then lo := mid + 1 else hi := mid
      done;
      let idx = !lo in
      if idx = 0 then Some 0
      else if idx >= n then Some (n - 1)
      else
        let dist_left = Float.abs (x data.(idx - 1) -. target) in
        let dist_right = Float.abs (x data.(idx) -. target) in
        if dist_left <= dist_right then Some (idx - 1) else Some idx

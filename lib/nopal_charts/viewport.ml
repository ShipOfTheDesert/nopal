let clip ~x ~data ~window ~buffer =
  (* Single-pass fold: find first and last indices within window *)
  let len, first_in, last_in =
    List.fold_left
      (fun (i, first, last) d ->
        let xv = x d in
        if xv >= window.Domain_window.x_min && xv <= window.x_max then
          ( i + 1,
            (match first with
            | None -> Some i
            | s -> s),
            Some i )
        else (i + 1, first, last))
      (0, None, None) data
  in
  match (first_in, last_in) with
  | None, _
  | _, None ->
      []
  | Some first_idx, Some last_idx ->
      let lo = max 0 (first_idx - buffer) in
      let hi = min (len - 1) (last_idx + buffer) in
      List.filteri (fun i _d -> i >= lo && i <= hi) data

let binary_search_lower ~x ~data ~n ~target =
  (* mutable: binary search requires imperative index narrowing *)
  let lo = ref 0 in
  let hi = ref (n - 1) in
  while !lo < !hi do
    let mid = !lo + ((!hi - !lo) / 2) in
    if x data.(mid) < target then lo := mid + 1 else hi := mid
  done;
  !lo

let binary_search_upper ~x ~data ~n ~start ~target =
  (* mutable: binary search requires imperative index narrowing *)
  let lo = ref start in
  let hi = ref (n - 1) in
  while !lo < !hi do
    let mid = !lo + ((!hi - !lo + 1) / 2) in
    if x data.(mid) <= target then lo := mid else hi := mid - 1
  done;
  !lo

let clip_sorted ~x ~data ~window ~buffer =
  let n = Array.length data in
  match n with
  | 0 -> [||]
  | _ ->
      let start_idx =
        binary_search_lower ~x ~data ~n ~target:window.Domain_window.x_min
      in
      let end_idx =
        binary_search_upper ~x ~data ~n ~start:start_idx ~target:window.x_max
      in
      if start_idx >= n || x data.(start_idx) > window.x_max then [||]
      else
        let buf_start = max 0 (start_idx - buffer) in
        let buf_end = min (n - 1) (end_idx + buffer) in
        Array.sub data buf_start (buf_end - buf_start + 1)

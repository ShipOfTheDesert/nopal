let triangle_area x1 y1 x2 y2 x3 y3 =
  Float.abs ((x1 *. (y2 -. y3)) +. (x2 *. (y3 -. y1)) +. (x3 *. (y1 -. y2)))
  /. 2.0

(* mutable: LTTB builds a result array imperatively — the algorithm selects
   one representative point per bucket and writes it into a pre-allocated
   output array. prev_selected must thread across buckets because each
   bucket's triangle area computation depends on the previous bucket's
   chosen point. This is inherent to the LTTB algorithm. *)
let lttb ~x ~y ~data ~target =
  let n = Array.length data in
  if n <= target then Array.copy data
  else begin
    let result = Array.make target data.(0) in
    result.(0) <- data.(0);
    result.(target - 1) <- data.(n - 1);
    let bucket_size = Float.of_int (n - 2) /. Float.of_int (target - 2) in
    let prev_selected = ref 0 in
    for bucket = 0 to target - 3 do
      let bucket_start =
        1 + Float.to_int (Float.of_int bucket *. bucket_size)
      in
      let bucket_end =
        min (n - 2)
          (1 + Float.to_int (Float.of_int (bucket + 1) *. bucket_size) - 1)
      in
      (* Compute average of next bucket for the third triangle vertex *)
      let next_bucket_start =
        1 + Float.to_int (Float.of_int (bucket + 1) *. bucket_size)
      in
      let next_bucket_end =
        min (n - 2)
          (1 + Float.to_int (Float.of_int (bucket + 2) *. bucket_size) - 1)
      in
      let next_bucket_end =
        if bucket = target - 3 then n - 1 else next_bucket_end
      in
      let count = next_bucket_end - next_bucket_start + 1 in
      let sum_x, sum_y =
        let acc = ref (0.0, 0.0) in
        for i = next_bucket_start to next_bucket_end do
          let sx, sy = !acc in
          acc := (sx +. x data.(i), sy +. y data.(i))
        done;
        !acc
      in
      let avg_x = sum_x /. Float.of_int count in
      let avg_y = sum_y /. Float.of_int count in
      (* Find point in current bucket that maximizes triangle area *)
      let prev = data.(!prev_selected) in
      let best_idx = ref bucket_start in
      let best_area = ref Float.neg_infinity in
      for i = bucket_start to bucket_end do
        let area =
          triangle_area (x prev) (y prev) (x data.(i)) (y data.(i)) avg_x avg_y
        in
        if area > !best_area then begin
          best_area := area;
          best_idx := i
        end
      done;
      result.(bucket + 1) <- data.(!best_idx);
      prev_selected := !best_idx
    done;
    result
  end

let should_downsample ~data_length ~pixel_width =
  Float.of_int data_length > 3.0 *. pixel_width

let target_for_width ~pixel_width = Float.to_int (2.0 *. pixel_width)

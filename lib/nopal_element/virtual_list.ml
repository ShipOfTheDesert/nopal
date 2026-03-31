type fixed

module Positive_float = struct
  type t = float

  let of_float f = if Float.compare f 0.0 > 0 then Some f else None
  let to_float t = t
end

module Natural = struct
  type t = int

  let of_int n = if n >= 0 then Some n else None
  let to_int t = t
end

type 'height scroll_state = { offset : float }

let scroll_state ~offset = { offset = Float.max 0.0 offset }
let offset ss = ss.offset

type range = { first : int; last : int }

let visible_range ~scroll_state ~row_height ~container_height ~item_count
    ~overscan =
  let item_count = Natural.to_int item_count in
  if item_count = 0 then { first = 0; last = -1 }
  else
    let row_h = Positive_float.to_float row_height in
    let container_h = Positive_float.to_float container_height in
    let overscan_n = Natural.to_int overscan in
    let first_visible = Float.to_int (Float.div scroll_state.offset row_h) in
    let visible_count = Float.to_int (ceil (container_h /. row_h)) in
    let last_visible = first_visible + visible_count - 1 in
    let first_raw = Int.max 0 (first_visible - overscan_n) in
    let last = Int.min (item_count - 1) (last_visible + overscan_n) in
    let first = Int.min first_raw last in
    { first; last }

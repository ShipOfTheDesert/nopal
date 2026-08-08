let of_channels ~r ~g ~b =
  (0.299 *. float_of_int r)
  +. (0.587 *. float_of_int g)
  +. (0.114 *. float_of_int b)

let of_buffer buffer =
  let width = Buffer.width buffer in
  Array.init
    (width * Buffer.height buffer)
    (fun index ->
      match Buffer.pixel buffer ~x:(index mod width) ~y:(index / width) with
      | Some (r, g, b, _alpha) -> of_channels ~r ~g ~b
      (* Unreachable: [index] stays below [width * height], so both coordinates
         are in range. Answered rather than raised so the function is total. *)
      | None -> 0.0)

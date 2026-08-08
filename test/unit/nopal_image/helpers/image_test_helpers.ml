let close ~epsilon expected actual =
  (not (Float.is_nan expected))
  && (not (Float.is_nan actual))
  && Float.abs (expected -. actual) <= epsilon

let approx ~epsilon =
  let pp fmt value = Format.fprintf fmt "%.6f" value in
  Alcotest.testable pp (close ~epsilon)

let exact =
  let pp fmt value = Format.fprintf fmt "%.17g" value in
  Alcotest.testable pp Float.equal

let same_bits a b = Int64.equal (Int64.bits_of_float a) (Int64.bits_of_float b)

let rgba_pixel =
  let pp fmt (r, g, b, a) = Format.fprintf fmt "(%d, %d, %d, %d)" r g b a in
  let equal (r1, g1, b1, a1) (r2, g2, b2, a2) =
    Int.equal r1 r2 && Int.equal g1 g2 && Int.equal b1 b2 && Int.equal a1 a2
  in
  Alcotest.testable pp equal

let buffer_or_fail ~context result =
  match result with
  | Ok buffer -> buffer
  | Error error ->
      Alcotest.failf "%s: expected Ok, got Error %s" context
        (Nopal_image.message error)

let rgba_of_pixels pixels =
  let bytes = Bytes.create (List.length pixels * 4) in
  List.iteri
    (fun index (r, g, b, a) ->
      let base = index * 4 in
      Bytes.set bytes base (Char.chr r);
      Bytes.set bytes (base + 1) (Char.chr g);
      Bytes.set bytes (base + 2) (Char.chr b);
      Bytes.set bytes (base + 3) (Char.chr a))
    pixels;
  bytes

let rgba_of_gray_levels levels =
  let bytes = Bytes.create (Array.length levels * 4) in
  Array.iteri
    (fun index level ->
      let base = index * 4 in
      Bytes.set bytes base (Char.chr level);
      Bytes.set bytes (base + 1) (Char.chr level);
      Bytes.set bytes (base + 2) (Char.chr level);
      Bytes.set bytes (base + 3) (Char.chr 255))
    levels;
  bytes

let gray_buffer ~width ~height levels =
  Nopal_image.Buffer.create ~width ~height ~rgba:(rgba_of_gray_levels levels)

let gray_buffer_or_fail ~context ~width ~height levels =
  buffer_or_fail ~context (gray_buffer ~width ~height levels)

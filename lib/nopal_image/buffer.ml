type t = { width : int; height : int; rgba : bytes }

(* The length check divides down rather than comparing against
   [4 * width * height]: js_of_ocaml's int is 32-bit, and that product wraps for
   large edges. Worked witness, at width = height = 100_000: the true product is
   40_000_000_000, and 32-bit two's complement wraps it to 1_345_294_336 — still
   positive, so a byte length of that size would compare equal and an
   inconsistent triple would be accepted. Dividing never forms the product.
   Callers must have established [width > 0]; the division would otherwise
   raise. *)
let has_packed_rgba_length ~width ~height rgba =
  let length = Bytes.length rgba in
  length mod 4 = 0 && length / 4 mod width = 0 && length / 4 / width = height

let create ~width ~height ~rgba =
  if width <= 0 then
    Error
      (Image_error.Invalid_dimensions
         (Printf.sprintf "width must be positive, got %d" width))
  else if height <= 0 then
    Error
      (Image_error.Invalid_dimensions
         (Printf.sprintf "height must be positive, got %d" height))
  else if not (has_packed_rgba_length ~width ~height rgba) then
    Error
      (Image_error.Invalid_dimensions
         (Printf.sprintf
            "rgba byte length %d does not match %d by %d at 4 bytes per pixel"
            (Bytes.length rgba) width height))
  else Ok { width; height; rgba = Bytes.copy rgba }

let width t = t.width
let height t = t.height
let byte_size t = Bytes.length t.rgba

let pixel t ~x ~y =
  if x < 0 || y < 0 || x >= t.width || y >= t.height then None
  else
    let base = ((y * t.width) + x) * 4 in
    Some
      ( Char.code (Bytes.get t.rgba base),
        Char.code (Bytes.get t.rgba (base + 1)),
        Char.code (Bytes.get t.rgba (base + 2)),
        Char.code (Bytes.get t.rgba (base + 3)) )

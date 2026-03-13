type t = { r : float; g : float; b : float; a : float }

let rgba ~r ~g ~b ~a = { r; g; b; a }
let rgb ~r ~g ~b = { r; g; b; a = 1.0 }

let hsla ~h ~s ~l ~a =
  let h' = Float.rem h 360.0 in
  let h' = if h' < 0.0 then h' +. 360.0 else h' in
  let c = (1.0 -. Float.abs ((2.0 *. l) -. 1.0)) *. s in
  let x = c *. (1.0 -. Float.abs (Float.rem (h' /. 60.0) 2.0 -. 1.0)) in
  let m = l -. (c /. 2.0) in
  let r, g, b =
    if h' < 60.0 then (c, x, 0.0)
    else if h' < 120.0 then (x, c, 0.0)
    else if h' < 180.0 then (0.0, c, x)
    else if h' < 240.0 then (0.0, x, c)
    else if h' < 300.0 then (x, 0.0, c)
    else (c, 0.0, x)
  in
  { r = r +. m; g = g +. m; b = b +. m; a }

let hsl ~h ~s ~l = hsla ~h ~s ~l ~a:1.0

let hex_digit c =
  match c with
  | '0' .. '9' -> Ok (Char.code c - Char.code '0')
  | 'a' .. 'f' -> Ok (Char.code c - Char.code 'a' + 10)
  | 'A' .. 'F' -> Ok (Char.code c - Char.code 'A' + 10)
  | _ -> Error (Printf.sprintf "invalid hex digit: %c" c)

let hex_byte s i =
  match (hex_digit s.[i], hex_digit s.[i + 1]) with
  | Ok hi, Ok lo -> Ok ((hi * 16) + lo |> Float.of_int |> fun v -> v /. 255.0)
  | Error e, _
  | _, Error e ->
      Error e

let of_hex s =
  let len = String.length s in
  if len < 1 || s.[0] <> '#' then
    Error (Printf.sprintf "hex color must start with '#': %s" s)
  else
    let body = String.sub s 1 (len - 1) in
    let blen = String.length body in
    match blen with
    | 3 -> (
        match (hex_digit body.[0], hex_digit body.[1], hex_digit body.[2]) with
        | Ok r, Ok g, Ok b ->
            Ok
              {
                r = Float.of_int (r * 17) /. 255.0;
                g = Float.of_int (g * 17) /. 255.0;
                b = Float.of_int (b * 17) /. 255.0;
                a = 1.0;
              }
        | Error e, _, _
        | _, Error e, _
        | _, _, Error e ->
            Error e)
    | 6 -> (
        match (hex_byte body 0, hex_byte body 2, hex_byte body 4) with
        | Ok r, Ok g, Ok b -> Ok { r; g; b; a = 1.0 }
        | Error e, _, _
        | _, Error e, _
        | _, _, Error e ->
            Error e)
    | 8 -> (
        match
          (hex_byte body 0, hex_byte body 2, hex_byte body 4, hex_byte body 6)
        with
        | Ok r, Ok g, Ok b, Ok a -> Ok { r; g; b; a }
        | Error e, _, _, _
        | _, Error e, _, _
        | _, _, Error e, _
        | _, _, _, Error e ->
            Error e)
    | _ ->
        Error
          (Printf.sprintf "invalid hex length: %d (expected 3, 6, or 8)" blen)

let lerp a b t =
  {
    r = a.r +. ((b.r -. a.r) *. t);
    g = a.g +. ((b.g -. a.g) *. t);
    b = a.b +. ((b.b -. a.b) *. t);
    a = a.a +. ((b.a -. a.a) *. t);
  }

let equal a b =
  Float.equal a.r b.r
  && Float.equal a.g b.g
  && Float.equal a.b b.b
  && Float.equal a.a b.a

let red = { r = 1.0; g = 0.0; b = 0.0; a = 1.0 }
let green = { r = 0.0; g = 1.0; b = 0.0; a = 1.0 }
let blue = { r = 0.0; g = 0.0; b = 1.0; a = 1.0 }
let black = { r = 0.0; g = 0.0; b = 0.0; a = 1.0 }
let white = { r = 1.0; g = 1.0; b = 1.0; a = 1.0 }
let transparent = { r = 0.0; g = 0.0; b = 0.0; a = 0.0 }

let categorical =
  [|
    { r = 0.122; g = 0.467; b = 0.706; a = 1.0 };
    { r = 1.000; g = 0.498; b = 0.055; a = 1.0 };
    { r = 0.173; g = 0.627; b = 0.173; a = 1.0 };
    { r = 0.839; g = 0.153; b = 0.157; a = 1.0 };
    { r = 0.580; g = 0.404; b = 0.741; a = 1.0 };
    { r = 0.549; g = 0.337; b = 0.294; a = 1.0 };
    { r = 0.890; g = 0.467; b = 0.761; a = 1.0 };
    { r = 0.498; g = 0.498; b = 0.498; a = 1.0 };
    { r = 0.737; g = 0.741; b = 0.133; a = 1.0 };
    { r = 0.090; g = 0.745; b = 0.812; a = 1.0 };
  |]

let sequential start finish n =
  if n <= 0 then []
  else if n = 1 then [ start ]
  else
    List.init n (fun i ->
        let t = Float.of_int i /. Float.of_int (n - 1) in
        lerp start finish t)

open Image_test_helpers

(* A 2x2 RGBA fixture whose 16 bytes ascend 10, 20, ... 160, so every pixel and
   every channel within a pixel is distinguishable — a transposed row or a
   swapped channel cannot pass. Rebuilt per call: the aliasing test mutates it. *)
let rgba_2x2 () = Bytes.init 16 (fun i -> Char.chr (10 * (i + 1)))

(* Returns the full displayable message so a rejection can be pinned exactly,
   and fails on the wrong constructor rather than folding it into the string. *)
let invalid_dimensions_message ~context result =
  match result with
  | Ok _ -> Alcotest.failf "%s: expected Error, got Ok" context
  | Error (Nopal_image.Invalid_dimensions _ as error) ->
      Nopal_image.message error
  | Error (Nopal_image.Invalid_config detail) ->
      Alcotest.failf "%s: expected Invalid_dimensions, got Invalid_config: %s"
        context detail

let test_create_ok () =
  let buffer =
    Nopal_image.Buffer.create ~width:2 ~height:2 ~rgba:(rgba_2x2 ())
    |> buffer_or_fail ~context:"well-formed 2x2"
  in
  Alcotest.(check int)
    "reports the given width" 2
    (Nopal_image.Buffer.width buffer);
  Alcotest.(check int)
    "reports the given height" 2
    (Nopal_image.Buffer.height buffer);
  Alcotest.(check int)
    "reports the packed RGBA byte count" 16
    (Nopal_image.Buffer.byte_size buffer)

(* One rejection per conjunct of the length check, each chosen so that only the
   conjunct it targets rejects it. Deleting any one of the three then turns the
   corresponding case red, which a shared fixture would not do. *)
let test_create_rejects_length_mismatch () =
  Alcotest.(check string)
    "names the observed byte length and the dimensions it contradicts"
    "Invalid image dimensions: rgba byte length 12 does not match 2 by 2 at 4 \
     bytes per pixel"
    (Nopal_image.Buffer.create ~width:2 ~height:2 ~rgba:(Bytes.make 12 '\000')
    |> invalid_dimensions_message ~context:"12 bytes for a 2x2 image");
  (* A trailing partial pixel: 5 bytes divide down to 1 whole pixel, which
     matches a 1x1 image, so only the four-bytes-per-pixel check rejects it. *)
  Alcotest.(check string)
    "rejects a length carrying a partial trailing pixel"
    "Invalid image dimensions: rgba byte length 5 does not match 1 by 1 at 4 \
     bytes per pixel"
    (Nopal_image.Buffer.create ~width:1 ~height:1 ~rgba:(Bytes.make 5 '\000')
    |> invalid_dimensions_message ~context:"5 bytes for a 1x1 image");
  (* Too few rows: 8 bytes are 2 whole pixels and 2 divides by the width, so
     only the row-count conjunct rejects a one-row buffer offered as 2x2. *)
  Alcotest.(check string)
    "rejects a buffer holding fewer rows than the height claims"
    "Invalid image dimensions: rgba byte length 8 does not match 2 by 2 at 4 \
     bytes per pixel"
    (Nopal_image.Buffer.create ~width:2 ~height:2 ~rgba:(Bytes.make 8 '\000')
    |> invalid_dimensions_message ~context:"8 bytes for a 2x2 image");
  (* Over-long by a partial row: 28 bytes are 7 whole pixels, and 7 / 3 is 2,
     which equals the height — only the pixels-divide-by-width conjunct
     rejects it. *)
  Alcotest.(check string)
    "rejects a buffer whose pixel count is not a whole number of rows"
    "Invalid image dimensions: rgba byte length 28 does not match 3 by 2 at 4 \
     bytes per pixel"
    (Nopal_image.Buffer.create ~width:3 ~height:2 ~rgba:(Bytes.make 28 '\000')
    |> invalid_dimensions_message ~context:"28 bytes for a 3x2 image")

(* Both dimensions, both forms of non-positive, so neither guard can be deleted
   and neither can be reading the other's argument. *)
let test_create_rejects_non_positive_dimensions () =
  Alcotest.(check string)
    "names the rejected zero width"
    "Invalid image dimensions: width must be positive, got 0"
    (Nopal_image.Buffer.create ~width:0 ~height:2 ~rgba:Bytes.empty
    |> invalid_dimensions_message ~context:"zero width");
  Alcotest.(check string)
    "names the rejected negative width"
    "Invalid image dimensions: width must be positive, got -5"
    (Nopal_image.Buffer.create ~width:(-5) ~height:2 ~rgba:(rgba_2x2 ())
    |> invalid_dimensions_message ~context:"negative width");
  Alcotest.(check string)
    "names the rejected zero height"
    "Invalid image dimensions: height must be positive, got 0"
    (Nopal_image.Buffer.create ~width:2 ~height:0 ~rgba:Bytes.empty
    |> invalid_dimensions_message ~context:"zero height");
  Alcotest.(check string)
    "names the rejected negative height"
    "Invalid image dimensions: height must be positive, got -3"
    (Nopal_image.Buffer.create ~width:2 ~height:(-3) ~rgba:(rgba_2x2 ())
    |> invalid_dimensions_message ~context:"negative height")

(* Pins the copy-on-construct contract stated at [Buffer.create]. The buffer
   exposes no accessor returning its bytes, so physical equality is unobservable
   and mutating the caller's source is the only way to see the sharing. *)
let test_no_aliasing_after_create () =
  let source = rgba_2x2 () in
  let buffer =
    Nopal_image.Buffer.create ~width:2 ~height:2 ~rgba:source
    |> buffer_or_fail ~context:"aliasing fixture"
  in
  Bytes.set source 0 '\255';
  Bytes.set source 15 '\255';
  Alcotest.(check (option rgba_pixel))
    "the first pixel is unaffected by a later write to the source bytes"
    (Some (10, 20, 30, 40))
    (Nopal_image.Buffer.pixel buffer ~x:0 ~y:0);
  Alcotest.(check (option rgba_pixel))
    "the last pixel is unaffected by a later write to the source bytes"
    (Some (130, 140, 150, 160))
    (Nopal_image.Buffer.pixel buffer ~x:1 ~y:1)

let test_pixel_in_bounds () =
  let buffer =
    Nopal_image.Buffer.create ~width:2 ~height:2 ~rgba:(rgba_2x2 ())
    |> buffer_or_fail ~context:"in-bounds fixture"
  in
  let check_pixel ~x ~y expected =
    Alcotest.(check (option rgba_pixel))
      (Printf.sprintf "pixel at x=%d y=%d" x y)
      (Some expected)
      (Nopal_image.Buffer.pixel buffer ~x ~y)
  in
  check_pixel ~x:0 ~y:0 (10, 20, 30, 40);
  check_pixel ~x:1 ~y:0 (50, 60, 70, 80);
  check_pixel ~x:0 ~y:1 (90, 100, 110, 120);
  check_pixel ~x:1 ~y:1 (130, 140, 150, 160)

(* A square fixture cannot see a transposed stride or a transposed bounds check,
   because swapping width for height leaves both unchanged. This 3-wide by
   2-tall fixture can: under a transposition the row stride is wrong for every
   pixel past the first row, and (2, 1) — in range here — would be rejected. *)
let test_pixel_on_a_non_square_buffer () =
  let buffer =
    Nopal_image.Buffer.create ~width:3 ~height:2
      ~rgba:
        (rgba_of_pixels
           [
             (1, 2, 3, 4);
             (5, 6, 7, 8);
             (9, 10, 11, 12);
             (13, 14, 15, 16);
             (17, 18, 19, 20);
             (21, 22, 23, 24);
           ])
    |> buffer_or_fail ~context:"3x2 fixture"
  in
  let check_pixel ~x ~y expected =
    Alcotest.(check (option rgba_pixel))
      (Printf.sprintf "pixel at x=%d y=%d" x y)
      (Some expected)
      (Nopal_image.Buffer.pixel buffer ~x ~y)
  in
  check_pixel ~x:0 ~y:0 (1, 2, 3, 4);
  check_pixel ~x:2 ~y:0 (9, 10, 11, 12);
  check_pixel ~x:0 ~y:1 (13, 14, 15, 16);
  check_pixel ~x:2 ~y:1 (21, 22, 23, 24);
  Alcotest.(check (option rgba_pixel))
    "a y beyond the shorter axis is out of range" None
    (Nopal_image.Buffer.pixel buffer ~x:0 ~y:2)

(* The affirmative arm for this absence assertion is [test_pixel_in_bounds],
   which shares the fixture and proves the same coordinates space can return
   [Some] — so a [pixel] that returned [None] everywhere cannot pass both. *)
let test_pixel_out_of_bounds_is_none () =
  let buffer =
    Nopal_image.Buffer.create ~width:2 ~height:2 ~rgba:(rgba_2x2 ())
    |> buffer_or_fail ~context:"out-of-bounds fixture"
  in
  let check_none ~x ~y =
    Alcotest.(check (option rgba_pixel))
      (Printf.sprintf "pixel at x=%d y=%d is out of range" x y)
      None
      (Nopal_image.Buffer.pixel buffer ~x ~y)
  in
  check_none ~x:2 ~y:0;
  check_none ~x:0 ~y:2;
  check_none ~x:(-1) ~y:0;
  check_none ~x:0 ~y:(-1)

let tests =
  [
    Alcotest.test_case "create accepts a well-formed triple" `Quick
      test_create_ok;
    Alcotest.test_case "create rejects a byte length mismatch" `Quick
      test_create_rejects_length_mismatch;
    Alcotest.test_case "create rejects non-positive dimensions" `Quick
      test_create_rejects_non_positive_dimensions;
    Alcotest.test_case "create copies the caller's bytes" `Quick
      test_no_aliasing_after_create;
    Alcotest.test_case "pixel reads back in-range coordinates" `Quick
      test_pixel_in_bounds;
    Alcotest.test_case "pixel reads back a non-square buffer" `Quick
      test_pixel_on_a_non_square_buffer;
    Alcotest.test_case "pixel returns None out of range" `Quick
      test_pixel_out_of_bounds_is_none;
  ]

let () = Alcotest.run "Nopal_image.Buffer" [ ("Buffer", tests) ]

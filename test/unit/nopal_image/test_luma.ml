open Image_test_helpers

let luma = approx ~epsilon:1e-9

(* Expected values are the coefficients written out by hand against full scale,
   never a second call into [of_channels]. *)
let test_pure_channels_match_coefficients () =
  Alcotest.check luma "full red carries the red coefficient at full scale"
    (0.299 *. 255.0)
    (Nopal_image.Luma.of_channels ~r:255 ~g:0 ~b:0);
  Alcotest.check luma "full green carries the green coefficient at full scale"
    (0.587 *. 255.0)
    (Nopal_image.Luma.of_channels ~r:0 ~g:255 ~b:0);
  Alcotest.check luma "full blue carries the blue coefficient at full scale"
    (0.114 *. 255.0)
    (Nopal_image.Luma.of_channels ~r:0 ~g:0 ~b:255);
  Alcotest.check luma "black is zero" 0.0
    (Nopal_image.Luma.of_channels ~r:0 ~g:0 ~b:0)

(* The affirmative counterweight to the coefficient test: it pins the output
   scale (a channel value in, the same value out) and, because the three
   coefficients must sum to one for it to hold, it also catches a single
   mis-typed coefficient that the pure-channel test happened to miss. *)
let test_gray_maps_to_itself () =
  let check_gray level =
    Alcotest.check luma
      (Printf.sprintf "gray %d maps to itself" level)
      (float_of_int level)
      (Nopal_image.Luma.of_channels ~r:level ~g:level ~b:level)
  in
  check_gray 0;
  check_gray 64;
  check_gray 128;
  check_gray 255

(* The two rows differ, so a column-major traversal produces a different array
   and cannot pass. The first pixel's alpha is neither 0 nor 255 so that an
   alpha accidentally fed into the weighting shows up as a wrong value. *)
let test_of_buffer_is_row_major () =
  let buffer =
    Nopal_image.Buffer.create ~width:2 ~height:2
      ~rgba:
        (rgba_of_pixels
           [
             (255, 0, 0, 17);
             (0, 255, 0, 255);
             (0, 0, 255, 255);
             (255, 255, 255, 255);
           ])
    |> buffer_or_fail ~context:"row-major fixture"
  in
  Alcotest.check (Alcotest.array luma)
    "reads left to right within a row, then top to bottom"
    [| 0.299 *. 255.0; 0.587 *. 255.0; 0.114 *. 255.0; 255.0 |]
    (Nopal_image.Luma.of_buffer buffer)

(* A non-square buffer, so a traversal that swapped the two dimensions would
   read the wrong pixel rather than the same one. Also pins the array length,
   which is what keeps [Sharpness]'s direct indexing in range. *)
let test_of_buffer_on_a_non_square_buffer () =
  let buffer =
    gray_buffer_or_fail ~context:"3x2 gray fixture" ~width:3 ~height:2
      [| 0; 10; 20; 30; 40; 50 |]
  in
  Alcotest.check (Alcotest.array luma)
    "one entry per pixel, row-major, on a wider-than-tall buffer"
    [| 0.0; 10.0; 20.0; 30.0; 40.0; 50.0 |]
    (Nopal_image.Luma.of_buffer buffer)

let tests =
  [
    Alcotest.test_case "pure channels carry the perceptual coefficients" `Quick
      test_pure_channels_match_coefficients;
    Alcotest.test_case "gray maps to itself" `Quick test_gray_maps_to_itself;
    Alcotest.test_case "of_buffer is row major" `Quick
      test_of_buffer_is_row_major;
    Alcotest.test_case "of_buffer reads a non-square buffer" `Quick
      test_of_buffer_on_a_non_square_buffer;
  ]

let () = Alcotest.run "Nopal_image.Luma" [ ("Luma", tests) ]

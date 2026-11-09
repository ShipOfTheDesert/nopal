module Scroll_axes = Nopal_web_internal.Scroll_axes
open Scroll_axes

let orientation_to_string = function
  | Forward -> "forward"
  | Reversed -> "reversed"

let axes_to_string { x; y } =
  Printf.sprintf "{ x = %s; y = %s }" (orientation_to_string x)
    (orientation_to_string y)

let axes_testable =
  Alcotest.testable
    (fun ppf a -> Format.pp_print_string ppf (axes_to_string a))
    ( = )

let neither = { x = Forward; y = Forward }
let x_only = { x = Reversed; y = Forward }
let y_only = { x = Forward; y = Reversed }
let both = { x = Reversed; y = Reversed }

(* The reference: which axes run reversed for each computed writing-mode and
   direction pair, as measured in Chromium by reading the scroll range each
   container actually offers. Written out here rather than derived from the
   module, so a wrong row in the module cannot also be the expected value. *)
let known_rows =
  [
    ("horizontal-tb", "ltr", neither);
    ("horizontal-tb", "rtl", x_only);
    ("vertical-rl", "ltr", x_only);
    ("vertical-rl", "rtl", both);
    ("vertical-lr", "ltr", neither);
    ("vertical-lr", "rtl", y_only);
    ("sideways-rl", "ltr", x_only);
    ("sideways-rl", "rtl", both);
    ("sideways-lr", "ltr", y_only);
    ("sideways-lr", "rtl", neither);
  ]

(* Every value outside the known set skips both axes, whichever of the two
   properties carries it. The empty string is what a computed style yields for
   an element outside the document. *)
let unknown_rows =
  [
    ("horizontal-tb", "", both);
    ("horizontal-tb", "auto", both);
    ("horizontal-tb", "RTL", both);
    ("", "ltr", both);
    ("lr-tb", "ltr", both);
    ("Horizontal-TB", "ltr", both);
    ("vertical-rl ", "rtl", both);
    ("bogus", "bogus", both);
  ]

let decode ~writing_mode ~direction =
  reversed_axes
    (writing_mode_of_string writing_mode)
    (direction_of_string direction)

let test_reversed_axes_table () =
  List.iter
    (fun (writing_mode, direction, expected) ->
      Alcotest.check axes_testable
        (Printf.sprintf "writing-mode %S, direction %S" writing_mode direction)
        expected
        (decode ~writing_mode ~direction))
    (known_rows @ unknown_rows)

let expected_for ~writing_mode ~direction =
  match
    List.find_opt
      (fun (row_mode, row_direction, _) ->
        String.equal row_mode writing_mode
        && String.equal row_direction direction)
      known_rows
  with
  | Some (_, _, axes) -> axes
  | None -> both

let known_writing_modes =
  [
    "horizontal-tb"; "vertical-rl"; "vertical-lr"; "sideways-rl"; "sideways-lr";
  ]

let known_directions = [ "ltr"; "rtl" ]

(* Half the draws are known tokens, so every known row and every pairing of a
   known token with an arbitrary string keeps being exercised, not only pairs
   of noise. *)
let token_gen known =
  QCheck.Gen.oneof [ QCheck.Gen.oneof_list known; QCheck.Gen.string ]

let arb_pair =
  QCheck.make
    ~print:(fun (writing_mode, direction) ->
      Printf.sprintf "(writing-mode %S, direction %S)" writing_mode direction)
    (QCheck.Gen.pair
       (token_gen known_writing_modes)
       (token_gen known_directions))

let test_decode_is_total_over_strings =
  QCheck.Test.make ~count:2000 ~name:"decode_is_total_over_strings" arb_pair
    (fun (writing_mode, direction) ->
      decode ~writing_mode ~direction = expected_for ~writing_mode ~direction)

let () =
  let rand = Random.State.make [| 0x0161_0002 |] in
  Alcotest.run "Scroll_axes"
    [
      ( "reversed_axes",
        [
          Alcotest.test_case "reversed_axes_table" `Quick
            test_reversed_axes_table;
        ]
        @ List.map
            (QCheck_alcotest.to_alcotest ~rand ~speed_level:`Quick)
            [ test_decode_is_total_over_strings ] );
    ]

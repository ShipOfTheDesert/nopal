(* Behavioural tests for the pure long-edge fit used by the canvas pipeline.

   [fit] has no state and no platform dependency, so every case is a direct
   input/output pin. The fixtures deliberately use a non-integer aspect ratio
   (3000 x 1997) rather than a convenient one such as 3000 x 2000: with a ratio
   that divides evenly, an implementation that scaled only one edge and reused
   [max_edge] for the other would still land on the expected pair, and aspect
   preservation would be trivially true rather than asserted. *)

module Dimensions = Nopal_image_web.Dimensions

let check_fit label ~src_width ~src_height ~max_edge expected =
  Alcotest.(check (pair int int))
    label expected
    (Dimensions.fit ~src_width ~src_height ~max_edge)

(* Integer output cannot hold the source ratio exactly, so aspect preservation
   is asserted within the quantisation the shorter edge imposes: rounding one
   edge to a whole pixel moves the ratio by at most one part in that edge. The
   tolerance below is comfortably inside that bound for these fixtures and far
   tighter than any ratio a distorted (non-uniformly scaled) result would show.

   This derives its expectation from the source rather than from a hard-coded
   pair, which is the whole of its value: the exact pair pins in the cap cases
   already determine the ratio, so this only ever fires when someone edits an
   expected pair to match a distorted implementation. It is therefore asserted
   before the pair, or the pair would fail first and this would be dead. *)
let check_aspect_preserved label ~src_width ~src_height (out_width, out_height)
    =
  let ratio w h = float_of_int w /. float_of_int h in
  Alcotest.(check (float 0.002))
    label
    (ratio src_width src_height)
    (ratio out_width out_height)

let test_fit_caps_long_edge_landscape () =
  let src_width = 3000 and src_height = 1997 in
  let max_edge = 1600 in
  check_aspect_preserved "the landscape aspect ratio survives the cap"
    ~src_width ~src_height
    (Dimensions.fit ~src_width ~src_height ~max_edge);
  check_fit "a landscape source is capped on its width" ~src_width ~src_height
    ~max_edge (1600, 1065)

let test_fit_caps_long_edge_portrait () =
  let src_width = 1997 and src_height = 3000 in
  let max_edge = 1600 in
  check_aspect_preserved "the portrait aspect ratio survives the cap" ~src_width
    ~src_height
    (Dimensions.fit ~src_width ~src_height ~max_edge);
  check_fit "a portrait source is capped on its height" ~src_width ~src_height
    ~max_edge (1065, 1600)

let test_fit_never_upscales () =
  check_fit "a source well under the cap is returned unchanged" ~src_width:800
    ~src_height:600 ~max_edge:1600 (800, 600);
  (* Exactly at the cap. This pins the documented "at or under the cap comes
     back unchanged" contract, not an off-by-one: swapping the implementation's
     [<=] for [<] was measured to keep all four cases green, because a source
     already at the cap scales to itself. *)
  check_fit "a source exactly at the cap is returned unchanged" ~src_width:1600
    ~src_height:1200 ~max_edge:1600 (1600, 1200);
  check_fit "a portrait source exactly at the cap is returned unchanged"
    ~src_width:1200 ~src_height:1600 ~max_edge:1600 (1200, 1600)

let test_fit_floors_at_one_pixel () =
  (* 4000 x 3 scales its short edge to 1.2, which truncates to 1 on its own. *)
  check_fit "an extreme ratio keeps a one pixel short edge" ~src_width:4000
    ~src_height:3 ~max_edge:1600 (1600, 1);
  (* 4000 x 1 scales its short edge to 0.4, which truncates to 0 — only the
     explicit floor keeps this off a zero-height canvas. *)
  check_fit "a short edge that scales below one pixel is floored"
    ~src_width:4000 ~src_height:1 ~max_edge:1600 (1600, 1);
  check_fit "the floor applies in portrait orientation too" ~src_width:1
    ~src_height:4000 ~max_edge:1600 (1, 1600);
  (* A degenerate source cannot come from a decoded bitmap, but [fit] is a
     public function and its documented invariant is unconditional: no input
     produces a zero edge. *)
  check_fit "a degenerate zero-edge source still yields a usable size"
    ~src_width:0 ~src_height:0 ~max_edge:1600 (1, 1)

let tests =
  [
    Alcotest.test_case "fit caps the long edge in landscape" `Quick
      test_fit_caps_long_edge_landscape;
    Alcotest.test_case "fit caps the long edge in portrait" `Quick
      test_fit_caps_long_edge_portrait;
    Alcotest.test_case "fit never upscales" `Quick test_fit_never_upscales;
    Alcotest.test_case "fit floors every edge at one pixel" `Quick
      test_fit_floors_at_one_pixel;
  ]

let () = Alcotest.run "Dimensions" [ ("Dimensions", tests) ]

open Image_test_helpers

let format_name = function
  | Nopal_image.Config.Jpeg -> "Jpeg"
  | Nopal_image.Config.Png -> "Png"
  | Nopal_image.Config.Webp -> "Webp"

(* Compared through the name rather than by polymorphic equality so that adding
   a fourth format is a compile error here too. *)
let format =
  let pp fmt value = Format.pp_print_string fmt (format_name value) in
  Alcotest.testable pp (fun left right ->
      String.equal (format_name left) (format_name right))

(* [Float.equal] for the ordinary read-back assertions. It is deliberately not
   used for the negative-zero case: no float comparator separates [-0.0] from
   [0.0], so pinning the "as the caller supplied it" contract needs the bit
   pattern. See [test_quality_is_echoed_bit_for_bit]. *)
let quality = exact

let config_or_fail ~context result =
  match result with
  | Ok config -> config
  | Error error ->
      Alcotest.failf "%s: expected Ok, got Error %s" context
        (Nopal_image.message error)

(* Returns the full displayable message so a rejection can be pinned exactly,
   and fails on the wrong constructor rather than folding it into the string. *)
let invalid_config_message ~context result =
  match result with
  | Ok _ -> Alcotest.failf "%s: expected Error, got Ok" context
  | Error (Nopal_image.Invalid_config _ as error) -> Nopal_image.message error
  | Error (Nopal_image.Invalid_dimensions detail) ->
      Alcotest.failf "%s: expected Invalid_config, got Invalid_dimensions: %s"
        context detail

(* Every field differs from [recommended], so a [make] that ignored its
   arguments and answered the preset could not pass. The quality is exactly
   representable and carries four decimal places, so an accessor that rounded
   or rescaled on the way out could not pass either. *)
let test_make_ok () =
  let config =
    Nopal_image.Config.make ~max_edge:2048 ~metric_edge:512 ~quality:0.4375
      ~format:Nopal_image.Config.Png
    |> config_or_fail ~context:"a valid four-value config"
  in
  Alcotest.(check int)
    "reports the given max edge" 2048
    (Nopal_image.Config.max_edge config);
  Alcotest.(check int)
    "reports the given metric edge" 512
    (Nopal_image.Config.metric_edge config);
  Alcotest.check quality "reports the given quality verbatim" 0.4375
    (Nopal_image.Config.quality config);
  Alcotest.check format "reports the given format" Nopal_image.Config.Png
    (Nopal_image.Config.format config)

let test_recommended_values () =
  Alcotest.(check int)
    "caps the stored image at 1600 on its long edge" 1600
    (Nopal_image.Config.max_edge Nopal_image.Config.recommended);
  Alcotest.(check int)
    "caps the metric pass at 800 on its long edge" 800
    (Nopal_image.Config.metric_edge Nopal_image.Config.recommended);
  Alcotest.check quality "encodes at 0.8" 0.8
    (Nopal_image.Config.quality Nopal_image.Config.recommended);
  Alcotest.check format "encodes as JPEG" Nopal_image.Config.Jpeg
    (Nopal_image.Config.format Nopal_image.Config.recommended)

(* [recommended] is built as a record literal rather than by unwrapping [make],
   so nothing but this test stops the two drifting apart: add a rule to [make]
   and the preset silently becomes a value [make] would reject. The values are
   read back off [recommended] rather than written out again, so the check
   follows the preset if it is ever retuned. *)
let test_recommended_satisfies_make () =
  let preset = Nopal_image.Config.recommended in
  let rebuilt =
    Nopal_image.Config.make
      ~max_edge:(Nopal_image.Config.max_edge preset)
      ~metric_edge:(Nopal_image.Config.metric_edge preset)
      ~quality:(Nopal_image.Config.quality preset)
      ~format:(Nopal_image.Config.format preset)
    |> config_or_fail ~context:"the recommended preset must satisfy make"
  in
  Alcotest.(check int)
    "make accepts the preset's max edge"
    (Nopal_image.Config.max_edge preset)
    (Nopal_image.Config.max_edge rebuilt);
  Alcotest.(check int)
    "make accepts the preset's metric edge"
    (Nopal_image.Config.metric_edge preset)
    (Nopal_image.Config.metric_edge rebuilt);
  Alcotest.check quality "make accepts the preset's quality"
    (Nopal_image.Config.quality preset)
    (Nopal_image.Config.quality rebuilt)

let test_rejects_non_positive_max_edge () =
  Alcotest.(check string)
    "names the rejected max edge"
    "Invalid image config: max edge must be positive, got 0"
    (Nopal_image.Config.make ~max_edge:0 ~metric_edge:512 ~quality:0.55
       ~format:Nopal_image.Config.Jpeg
    |> invalid_config_message ~context:"a zero max edge");
  Alcotest.(check string)
    "rejects a negative max edge too"
    "Invalid image config: max edge must be positive, got -16"
    (Nopal_image.Config.make ~max_edge:(-16) ~metric_edge:512 ~quality:0.55
       ~format:Nopal_image.Config.Jpeg
    |> invalid_config_message ~context:"a negative max edge");
  (* The affirmative arm at the boundary: one pixel is positive and accepted, so
     the rejections above come from the sign rule and not from the fixture
     failing to reach the check. *)
  let smallest =
    Nopal_image.Config.make ~max_edge:1 ~metric_edge:1 ~quality:0.55
      ~format:Nopal_image.Config.Jpeg
    |> config_or_fail ~context:"a one-pixel max edge"
  in
  Alcotest.(check int)
    "accepts the smallest positive max edge" 1
    (Nopal_image.Config.max_edge smallest)

let test_rejects_non_positive_metric_edge () =
  Alcotest.(check string)
    "names the rejected metric edge"
    "Invalid image config: metric edge must be positive, got 0"
    (Nopal_image.Config.make ~max_edge:2048 ~metric_edge:0 ~quality:0.55
       ~format:Nopal_image.Config.Jpeg
    |> invalid_config_message ~context:"a zero metric edge");
  Alcotest.(check string)
    "rejects a negative metric edge too"
    "Invalid image config: metric edge must be positive, got -8"
    (Nopal_image.Config.make ~max_edge:2048 ~metric_edge:(-8) ~quality:0.55
       ~format:Nopal_image.Config.Jpeg
    |> invalid_config_message ~context:"a negative metric edge");
  let smallest =
    Nopal_image.Config.make ~max_edge:2048 ~metric_edge:1 ~quality:0.55
      ~format:Nopal_image.Config.Jpeg
    |> config_or_fail ~context:"a one-pixel metric edge"
  in
  Alcotest.(check int)
    "accepts the smallest positive metric edge" 1
    (Nopal_image.Config.metric_edge smallest)

let test_rejects_metric_edge_above_max_edge () =
  Alcotest.(check string)
    "names both edges in the order rule"
    "Invalid image config: metric edge 801 must not exceed max edge 800"
    (Nopal_image.Config.make ~max_edge:800 ~metric_edge:801 ~quality:0.55
       ~format:Nopal_image.Config.Jpeg
    |> invalid_config_message ~context:"a metric edge one above the max edge");
  (* Pins the comparison as strict: an equal pair is a legitimate config where
     the metric pass reads the stored image at full size. *)
  let equal_edges =
    Nopal_image.Config.make ~max_edge:800 ~metric_edge:800 ~quality:0.55
      ~format:Nopal_image.Config.Jpeg
    |> config_or_fail ~context:"a metric edge equal to the max edge"
  in
  Alcotest.(check int)
    "accepts a metric edge equal to the max edge" 800
    (Nopal_image.Config.metric_edge equal_edges)

let test_rejects_quality_below_zero () =
  Alcotest.(check string)
    "names the rejected quality"
    "Invalid image config: quality must be between 0 and 1, got -0.1"
    (Nopal_image.Config.make ~max_edge:2048 ~metric_edge:512 ~quality:(-0.1)
       ~format:Nopal_image.Config.Jpeg
    |> invalid_config_message ~context:"a quality below zero");
  let lowest =
    Nopal_image.Config.make ~max_edge:2048 ~metric_edge:512 ~quality:0.0
      ~format:Nopal_image.Config.Jpeg
    |> config_or_fail ~context:"a quality of zero"
  in
  Alcotest.check quality "accepts the inclusive lower bound" 0.0
    (Nopal_image.Config.quality lowest)

let test_rejects_quality_above_one () =
  Alcotest.(check string)
    "names the rejected quality"
    "Invalid image config: quality must be between 0 and 1, got 1.1"
    (Nopal_image.Config.make ~max_edge:2048 ~metric_edge:512 ~quality:1.1
       ~format:Nopal_image.Config.Jpeg
    |> invalid_config_message ~context:"a quality above one");
  let highest =
    Nopal_image.Config.make ~max_edge:2048 ~metric_edge:512 ~quality:1.0
      ~format:Nopal_image.Config.Jpeg
    |> config_or_fail ~context:"a quality of one"
  in
  Alcotest.check quality "accepts the inclusive upper bound" 1.0
    (Nopal_image.Config.quality highest)

(* [quality] is documented as handing back the float the caller supplied. No
   float comparator can pin that: [=], [Float.equal], [compare] and
   [Float.compare] all report [0.0] and [-0.0] equal, so an implementation
   storing [quality +. 0.0] — which normalises the sign of a zero and leaves
   every other value alone — passes an assertion written with any of them.
   [-0.0] is the one quality whose representation is observable, so it is the
   case the contract stands or falls on, and the bit pattern is the only
   comparison that sees it. *)
let test_quality_is_echoed_bit_for_bit () =
  let echoed value ~context =
    Nopal_image.Config.make ~max_edge:2048 ~metric_edge:512 ~quality:value
      ~format:Nopal_image.Config.Jpeg
    |> config_or_fail ~context
    |> Nopal_image.Config.quality
  in
  (* Negative zero is not below zero, so it is accepted at the lower bound. *)
  Alcotest.(check bool)
    "negative zero is returned with its sign intact" true
    (same_bits (-0.0) (echoed (-0.0) ~context:"a quality of negative zero"));
  Alcotest.(check bool)
    "positive zero is returned as positive zero" true
    (same_bits 0.0 (echoed 0.0 ~context:"a quality of positive zero"));
  (* The affirmative counterweight: the two zeros are distinguishable by this
     comparison, so the assertions above are not vacuously true. *)
  Alcotest.(check bool)
    "the comparison separates the two zeros" false (same_bits 0.0 (-0.0));
  Alcotest.(check bool)
    "an ordinary quality is returned unchanged" true
    (same_bits 0.4375 (echoed 0.4375 ~context:"an ordinary quality"))

(* A NaN quality is already ordered below zero by [Float.compare], so a range
   check alone would reject it and an explicit NaN branch carrying the same
   wording would be unobservable. Pinning a distinct message makes deleting the
   branch a failure rather than a silent no-op. *)
let test_rejects_quality_nan () =
  Alcotest.(check string)
    "rejects NaN on its own terms rather than as an out-of-range value"
    "Invalid image config: quality must be a number, got nan"
    (Nopal_image.Config.make ~max_edge:2048 ~metric_edge:512 ~quality:Float.nan
       ~format:Nopal_image.Config.Jpeg
    |> invalid_config_message ~context:"a NaN quality")

let test_format_to_mime_distinct () =
  Alcotest.(check string)
    "JPEG carries the JPEG media type" "image/jpeg"
    (Nopal_image.Config.format_to_mime Nopal_image.Config.Jpeg);
  Alcotest.(check string)
    "PNG carries the PNG media type" "image/png"
    (Nopal_image.Config.format_to_mime Nopal_image.Config.Png);
  Alcotest.(check string)
    "WebP carries the WebP media type" "image/webp"
    (Nopal_image.Config.format_to_mime Nopal_image.Config.Webp);
  let mimes =
    List.map Nopal_image.Config.format_to_mime
      [
        Nopal_image.Config.Jpeg; Nopal_image.Config.Png; Nopal_image.Config.Webp;
      ]
  in
  Alcotest.(check int)
    "the three formats map to three different media types" 3
    (List.length (List.sort_uniq String.compare mimes))

let tests =
  [
    Alcotest.test_case "make accepts a valid four-value config" `Quick
      test_make_ok;
    Alcotest.test_case "recommended carries the preset values" `Quick
      test_recommended_values;
    Alcotest.test_case "recommended satisfies make" `Quick
      test_recommended_satisfies_make;
    Alcotest.test_case "rejects a non-positive max edge" `Quick
      test_rejects_non_positive_max_edge;
    Alcotest.test_case "rejects a non-positive metric edge" `Quick
      test_rejects_non_positive_metric_edge;
    Alcotest.test_case "rejects a metric edge above the max edge" `Quick
      test_rejects_metric_edge_above_max_edge;
    Alcotest.test_case "rejects a quality below zero" `Quick
      test_rejects_quality_below_zero;
    Alcotest.test_case "rejects a quality above one" `Quick
      test_rejects_quality_above_one;
    Alcotest.test_case "quality is echoed bit for bit" `Quick
      test_quality_is_echoed_bit_for_bit;
    Alcotest.test_case "rejects a NaN quality" `Quick test_rejects_quality_nan;
    Alcotest.test_case "each format maps to a distinct media type" `Quick
      test_format_to_mime_distinct;
  ]

let () = Alcotest.run "Nopal_image.Config" [ ("Config", tests) ]

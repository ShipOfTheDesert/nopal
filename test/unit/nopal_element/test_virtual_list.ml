let pf v =
  match Nopal_element.Virtual_list.Positive_float.of_float v with
  | Some pf -> pf
  | None ->
      Alcotest.fail
        (Printf.sprintf "Positive_float.of_float %f returned None" v)

let nat v =
  match Nopal_element.Virtual_list.Natural.of_int v with
  | Some n -> n
  | None -> Alcotest.fail (Printf.sprintf "Natural.of_int %d returned None" v)

let check_range msg ~first ~last range =
  let open Nopal_element.Virtual_list in
  Alcotest.(check int) (msg ^ " first") first range.first;
  Alcotest.(check int) (msg ^ " last") last range.last

let test_visible_range_basic () =
  let open Nopal_element.Virtual_list in
  let scroll_state = scroll_state ~offset:0.0 in
  let range =
    visible_range ~scroll_state ~row_height:(pf 50.0)
      ~container_height:(pf 300.0) ~item_count:(nat 100) ~overscan:(nat 0)
  in
  check_range "basic" ~first:0 ~last:5 range

let test_visible_range_scrolled () =
  let open Nopal_element.Virtual_list in
  let scroll_state = scroll_state ~offset:250.0 in
  let range =
    visible_range ~scroll_state ~row_height:(pf 50.0)
      ~container_height:(pf 300.0) ~item_count:(nat 100) ~overscan:(nat 0)
  in
  check_range "scrolled" ~first:5 ~last:10 range

let test_visible_range_with_overscan () =
  let open Nopal_element.Virtual_list in
  let scroll_state = scroll_state ~offset:250.0 in
  let range =
    visible_range ~scroll_state ~row_height:(pf 50.0)
      ~container_height:(pf 300.0) ~item_count:(nat 100) ~overscan:(nat 2)
  in
  check_range "overscan" ~first:3 ~last:12 range

let test_visible_range_empty_list () =
  let open Nopal_element.Virtual_list in
  let scroll_state = scroll_state ~offset:0.0 in
  let range =
    visible_range ~scroll_state ~row_height:(pf 50.0)
      ~container_height:(pf 300.0) ~item_count:(nat 0) ~overscan:(nat 0)
  in
  check_range "empty" ~first:0 ~last:(-1) range

let test_visible_range_single_item () =
  let open Nopal_element.Virtual_list in
  let scroll_state = scroll_state ~offset:0.0 in
  let range =
    visible_range ~scroll_state ~row_height:(pf 50.0)
      ~container_height:(pf 300.0) ~item_count:(nat 1) ~overscan:(nat 0)
  in
  check_range "single" ~first:0 ~last:0 range

let test_visible_range_scroll_past_end () =
  let open Nopal_element.Virtual_list in
  let scroll_state = scroll_state ~offset:100000.0 in
  let range =
    visible_range ~scroll_state ~row_height:(pf 50.0)
      ~container_height:(pf 300.0) ~item_count:(nat 100) ~overscan:(nat 0)
  in
  Alcotest.(check bool) "last clamped" true (range.last <= 99);
  Alcotest.(check bool) "first <= last" true (range.first <= range.last)

let test_visible_range_overscan_clamp () =
  let open Nopal_element.Virtual_list in
  let scroll_state = scroll_state ~offset:0.0 in
  let range =
    visible_range ~scroll_state ~row_height:(pf 50.0)
      ~container_height:(pf 300.0) ~item_count:(nat 5) ~overscan:(nat 100)
  in
  check_range "overscan clamp" ~first:0 ~last:4 range

let test_scroll_state_negative_offset_clamped () =
  let open Nopal_element.Virtual_list in
  let ss = scroll_state ~offset:(-50.0) in
  Alcotest.(check (float 0.001)) "clamped to 0" 0.0 (offset ss)

let test_positive_float_rejects_zero () =
  let open Nopal_element.Virtual_list in
  Alcotest.(check bool)
    "zero rejected" true
    (Option.is_none (Positive_float.of_float 0.0))

let test_positive_float_rejects_negative () =
  let open Nopal_element.Virtual_list in
  Alcotest.(check bool)
    "negative rejected" true
    (Option.is_none (Positive_float.of_float (-1.0)))

let test_natural_rejects_negative () =
  let open Nopal_element.Virtual_list in
  Alcotest.(check bool)
    "negative rejected" true
    (Option.is_none (Natural.of_int (-1)))

let () =
  Alcotest.run "Virtual_list"
    [
      ( "visible_range",
        [
          Alcotest.test_case "basic" `Quick test_visible_range_basic;
          Alcotest.test_case "scrolled" `Quick test_visible_range_scrolled;
          Alcotest.test_case "with overscan" `Quick
            test_visible_range_with_overscan;
          Alcotest.test_case "empty list" `Quick test_visible_range_empty_list;
          Alcotest.test_case "single item" `Quick test_visible_range_single_item;
          Alcotest.test_case "scroll past end" `Quick
            test_visible_range_scroll_past_end;
          Alcotest.test_case "overscan clamp" `Quick
            test_visible_range_overscan_clamp;
          Alcotest.test_case "negative offset clamped" `Quick
            test_scroll_state_negative_offset_clamped;
        ] );
      ( "refinement_types",
        [
          Alcotest.test_case "positive_float rejects zero" `Quick
            test_positive_float_rejects_zero;
          Alcotest.test_case "positive_float rejects negative" `Quick
            test_positive_float_rejects_negative;
          Alcotest.test_case "natural rejects negative" `Quick
            test_natural_rejects_negative;
        ] );
    ]

(* A relative-scroll request as it travels through a command tree.

   [Cmd.t] is abstract, so every assertion below reads the request back through
   the public extractor rather than pattern-matching a constructor. The delta is
   compared with [Scroll_delta.equal] for the same reason: that type withholds
   every projection, so nothing can print its multiple and the printer here is a
   placeholder. Identity is therefore carried by the ids, which do print, and
   each request in a multi-request fixture is given a delta of its own so a
   reordering shows on both axes rather than only on one. *)

module Scroll_delta = Nopal_element.Scroll_delta
module Cmd = Nopal_mvu.Cmd

(* [Scroll_delta.t] withholds every projection, so a mismatch would otherwise
   print two identical placeholders and say nothing about which delta arrived.
   This reads the multiple back out through the only public observation there
   is — the offset a delta produces on a container one unit tall, parked far
   enough from both ends that no clamp applies — and is diagnostics only: the
   comparison below stays [Scroll_delta.equal]. A delta of zero moves nothing
   and so has no reading, which is exactly what it prints. *)
let pp_delta fmt d =
  match
    Scroll_delta.offset_for ~scroll_offset:1e6 ~viewport_height:1.0
      ~content_height:1e12 d
  with
  | Some offset -> Format.fprintf fmt "%g viewports" (offset -. 1e6)
  | None -> Format.pp_print_string fmt "no movement, or not finite"

let delta = Alcotest.testable pp_delta Scroll_delta.equal
let requests = Alcotest.list (Alcotest.pair Alcotest.string delta)

(* ------------------------------------------------------------------ *)
(* Mapping the message type                                             *)
(* ------------------------------------------------------------------ *)

let test_map_preserves_target_and_delta () =
  let cmd : int Cmd.t = Cmd.scroll_by "pane" (Scroll_delta.viewports 0.5) in
  let mapped = Cmd.map (fun (_ : int) -> "renamed") cmd in
  Alcotest.check requests "the request survives the message-type change"
    [ ("pane", Scroll_delta.viewports 0.5) ]
    (Cmd.extract_scroll_bys mapped)

(* ------------------------------------------------------------------ *)
(* The scheduling-free interpreter                                      *)
(* ------------------------------------------------------------------ *)

let test_execute_ignores_scroll_by () =
  let dispatched = ref [] in
  let cmd =
    Cmd.batch
      [
        Cmd.scroll_by "pane" (Scroll_delta.viewports 0.5);
        Cmd.perform (fun dispatch -> dispatch "sibling ran");
      ]
  in
  Cmd.execute (fun msg -> dispatched := msg :: !dispatched) cmd;
  Alcotest.(check (list string))
    "execute drops the request and keeps traversing" [ "sibling ran" ]
    !dispatched

(* ------------------------------------------------------------------ *)
(* Reading every request out of a tree                                  *)
(* ------------------------------------------------------------------ *)

let test_extract_scroll_bys_recurses_into_batch () =
  let cmd =
    Cmd.batch
      [
        Cmd.scroll_by "first" (Scroll_delta.viewports 0.5);
        Cmd.batch
          [
            Cmd.none;
            Cmd.batch [ Cmd.scroll_by "second" (Scroll_delta.viewports (-0.5)) ];
            Cmd.focus "an unrelated field";
            Cmd.scroll_by "third" (Scroll_delta.viewports 1.0);
          ];
        Cmd.scroll_by "fourth" (Scroll_delta.viewports (-1.0));
      ]
  in
  Alcotest.check requests "every request, in issue order"
    [
      ("first", Scroll_delta.viewports 0.5);
      ("second", Scroll_delta.viewports (-0.5));
      ("third", Scroll_delta.viewports 1.0);
      ("fourth", Scroll_delta.viewports (-1.0));
    ]
    (Cmd.extract_scroll_bys cmd)

(* ------------------------------------------------------------------ *)
(* The platform callback                                                *)
(* ------------------------------------------------------------------ *)

let test_interpret_routes_to_the_callback () =
  let scrolled = ref [] in
  let focused = ref [] in
  let cmd =
    Cmd.batch
      [
        Cmd.scroll_by "pane" (Scroll_delta.viewports 0.5);
        Cmd.focus "a field";
        Cmd.scroll_by "pane" (Scroll_delta.viewports (-1.0));
      ]
  in
  Cmd.interpret
    ~focus:(fun id -> focused := id :: !focused)
    ~scroll_by:(fun id d -> scrolled := (id, d) :: !scrolled)
    ~dispatch:ignore
    ~schedule_after:(fun _ms _msg -> ())
    cmd;
  Alcotest.check requests "both requests reached the scroll callback, in order"
    [
      ("pane", Scroll_delta.viewports 0.5);
      ("pane", Scroll_delta.viewports (-1.0));
    ]
    (List.rev !scrolled);
  Alcotest.(check (list string))
    "the focus request stayed on its own callback" [ "a field" ] !focused

let () =
  Alcotest.run "cmd_scroll_by"
    [
      ( "Cmd.scroll_by",
        [
          Alcotest.test_case "map preserves target and delta" `Quick
            test_map_preserves_target_and_delta;
          Alcotest.test_case "execute ignores scroll_by" `Quick
            test_execute_ignores_scroll_by;
          Alcotest.test_case "extract recurses into batch" `Quick
            test_extract_scroll_bys_recurses_into_batch;
          Alcotest.test_case "interpret routes to the callback" `Quick
            test_interpret_routes_to_the_callback;
        ] );
    ]

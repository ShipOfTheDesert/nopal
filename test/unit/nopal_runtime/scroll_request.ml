(* Alcotest plumbing for a relative-scroll request as a platform callback sees
   it: a container id and a delta.

   [Nopal_element.Scroll_delta.t] withholds every projection, so a mismatch
   would otherwise print two identical placeholders and say nothing about which
   delta arrived. The printer below reads the multiple back out through the only
   public observation there is — the offset a delta produces on a container one
   unit tall, parked far enough from both ends that no clamp applies. It is
   diagnostics only: the comparison stays [Scroll_delta.equal]. A delta of zero
   moves nothing and so has no reading, which is exactly what it prints.

   This module is not one of the test executables named in this directory's
   [(tests)] stanza, so dune links it into each of them; both suites that assert
   on a captured request share it rather than keeping divergent copies. *)

module Scroll_delta = Nopal_element.Scroll_delta

let pp_delta fmt d =
  match
    Scroll_delta.offset_for ~scroll_offset:1e6 ~viewport_height:1.0
      ~content_height:1e12 d
  with
  | Some offset -> Format.fprintf fmt "%g viewports" (offset -. 1e6)
  | None -> Format.pp_print_string fmt "no movement, or not finite"

let delta = Alcotest.testable pp_delta Scroll_delta.equal
let requests = Alcotest.list (Alcotest.pair Alcotest.string delta)

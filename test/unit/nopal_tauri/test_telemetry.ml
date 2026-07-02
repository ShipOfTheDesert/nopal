(* Task 9 (feature 0120 FR-7): the host-side telemetry mirror queried by
   [Nopal_tauri.Telemetry.get_telemetry] agrees with the browser
   [__nopal_telemetry__.getEvents] bridge on drain semantics — BOTH are
   NON-draining, bounded reads. The browser bridge stopped clearing on read
   (see test_mount_telemetry.ml); the Rust mirror returns a clone and drops
   oldest past its cap. This locks the OCaml host-query side of that parity: a
   regression to a draining read (or an unbounded mirror) fails here.

   [tauri_shim.js] models the host mirror: [__nopal_seed_telemetry] pushes an
   event (drop-oldest past a small test cap [__nopal_telemetry_cap]), and the
   shimmed [get_telemetry] returns a non-draining clone — exactly the Rust
   contract. The real Rust bound is build-validated ([just build-tauri]); this
   test pins the contract the OCaml consumer relies on. Resolution is synchronous
   because [get_telemetry] settles through a single [Jv.Promise.then'] against
   the shim's synchronous thenable. *)

module Telemetry = Nopal_tauri.Telemetry
module Task = Nopal_mvu.Task

let reset () = ignore (Jv.call Jv.global "__nopal_reset_subs" [||])

let seed kind value =
  ignore
    (Jv.call Jv.global "__nopal_seed_telemetry"
       [| Jv.of_string kind; Jv.of_string value |])

let cap () = Jv.to_int (Jv.get Jv.global "__nopal_telemetry_cap")

(* Run a task to completion synchronously and return its delivered value, or
   [None] if it never resolved (a draining-via-[Fut.await] regression would
   surface as [None] — the resolve deferred past the synchronous read). *)
let run_sync task =
  let out = ref None in
  Task.run task (fun v -> out := Some v);
  !out

let read () =
  match run_sync (Telemetry.get_telemetry ()) with
  | Some (Ok events) -> events
  | Some (Error e) -> Alcotest.failf "get_telemetry resolved Error: %s" e
  | None -> Alcotest.fail "get_telemetry hung — never resolved"

let message_values events =
  List.filter_map
    (function
      | Nopal_runtime.Telemetry.Message v -> Some v
      | Model_transition _
      | Command _
      | Subscription _ ->
          None)
    events

let test_telemetry_drain_parity () =
  reset ();
  seed "message" "a";
  seed "message" "b";
  (* Non-draining: two consecutive reads return the SAME log — the host mirror is
     not drained by a read, in parity with the now-non-draining browser bridge. *)
  let first = message_values (read ()) in
  let second = message_values (read ()) in
  Alcotest.(check (list string))
    "first read sees seeded events" [ "a"; "b" ] first;
  Alcotest.(check (list string))
    "second read identical — non-draining" first second;
  (* Bounded: seeding past the cap drops the oldest, so the mirror cannot grow
     unbounded (models the Rust drop-oldest bound). *)
  reset ();
  let n = cap () + 2 in
  for i = 1 to n do
    seed "message" (string_of_int i)
  done;
  let bounded = message_values (read ()) in
  Alcotest.(check int)
    "mirror capped at capacity" (cap ()) (List.length bounded);
  Alcotest.(check bool) "oldest event (1) dropped" false (List.mem "1" bounded);
  Alcotest.(check bool)
    "newest event retained" true
    (List.mem (string_of_int n) bounded)

let () =
  Alcotest.run "nopal_tauri_telemetry"
    [
      ( "drain_parity",
        [
          Alcotest.test_case "host get_telemetry non-draining and bounded"
            `Quick test_telemetry_drain_parity;
        ] );
    ]

(* FR-4 negative-path gate (exemplars). The telemetry E2E strategy (ADR 0108) is
   structurally blind to "the effect never fired at all" — a binding that logged a
   rejection and never resolved (the pre-PR-1 Tauri regression) would leave the MVU
   update loop waiting forever with no observable trace. These exemplars are its
   telemetry-visible complement: they force the underlying [invoke] to REJECT and
   assert the failure reaches the update loop as a dispatched [msg], not swallowed.

   The distinction from [test_results.ml] / [test_nopal_tauri_store.ml] (which
   assert the raw [Task.t] resolves [Error]) is the layer: here the op is wired as
   an app wires it — [Cmd.task] over a [Task.map] into a [msg] — and driven through
   [Cmd.execute] with a recording [dispatch]. That proves the whole binding →
   [Task] → [Cmd] → [dispatch] chain surfaces the failure, which is exactly what a
   log-and-never-resolve binding would break (the dispatch list would stay empty).

   Driven synchronously through [tauri_shim.js]: [__nopal_set_invoke_failure true]
   makes the shim's [invoke] return a SYNCHRONOUS thenable that rejects, so the op's
   single [Jv.Promise.then'] error continuation — and the [dispatch] it feeds — fire
   inside the test (a real Tauri host rejects asynchronously; that window is
   irrelevant to the swallow-vs-dispatch contract under test). *)

module Task = Nopal_mvu.Task
module Cmd = Nopal_mvu.Cmd
module Store = Nopal_tauri.Store
module Event = Nopal_tauri.Event

(* The message an MVU app maps a fallible op's result into. One constructor so the
   result [Ok]/[Error] cases stay compiler-exhaustive at each match site. *)
type msg = Op_result of (unit, string) result

let set_invoke_failure b =
  ignore (Jv.call Jv.global "__nopal_set_invoke_failure" [| Jv.of_bool b |])

let reset () = ignore (Jv.call Jv.global "__nopal_reset_subs" [||])

(* Run a task to completion synchronously and return its delivered value, or
   [None] if it never resolved. Used only for the [load] precondition — the
   behaviour under test observes the msg via [dispatched_msgs], not this. *)
let run_sync task =
  let out = ref None in
  Task.run task (fun v -> out := Some v);
  !out

(* Drive [cmd] as the runtime would — [Cmd.execute] runs its [Task] node and
   dispatches the produced msg — recording every msg that reaches [dispatch], in
   order. A log-and-never-resolve binding dispatches nothing, so the empty list is
   the observable signature of the FR-4 regression. *)
let dispatched_msgs cmd =
  let seen = ref [] in
  Cmd.execute (fun m -> seen := m :: !seen) cmd;
  List.rev !seen

(* Assert exactly one msg was dispatched and it carries a non-empty [Error]. The
   [[]] arm is the log-and-never-dispatch regression; the [Ok] arm is a swallowed
   failure reported as success. *)
let check_dispatches_error label cmd =
  match dispatched_msgs cmd with
  | [ Op_result (Error m) ] ->
      Alcotest.(check bool)
        (label ^ ": dispatched Error message is non-empty")
        true
        (String.length m > 0)
  | [ Op_result (Ok ()) ] ->
      Alcotest.failf "%s: failure swallowed — dispatched Ok instead of Error"
        label
  | [] ->
      Alcotest.failf
        "%s: log-and-never-dispatched — no msg reached the update loop" label
  | _ :: _ :: _ ->
      Alcotest.failf "%s: dispatched more than one msg for a single op" label

(* FR-4: a [Store] op whose IPC rejects must dispatch an [Error] msg, not stall.
   [load] runs with failure OFF to obtain a handle, then the shim is told to reject
   so the [set] settles [Error] and that reaches [dispatch]. *)
let test_store_failure_still_dispatches () =
  reset ();
  match run_sync (Store.load "nopal_store.json") with
  | Some (Ok handle) ->
      set_invoke_failure true;
      let cmd =
        Cmd.task (Task.map (fun r -> Op_result r) (Store.set handle "k" "v"))
      in
      check_dispatches_error "store set" cmd
  | Some (Error e) -> Alcotest.failf "precondition: load resolved Error %s" e
  | None -> Alcotest.fail "precondition: load hung — never resolved"

(* FR-4: [Event.emit] — the effectful result-typed event binding — must dispatch
   an [Error] msg when its IPC rejects, not log-and-drop. *)
let test_event_failure_still_dispatches () =
  reset ();
  set_invoke_failure true;
  let cmd =
    Cmd.task
      (Task.map (fun r -> Op_result r) (Event.emit "nopal:test-evt" "payload"))
  in
  check_dispatches_error "event emit" cmd

let () =
  Alcotest.run "nopal_tauri_negative_path"
    [
      ( "dispatches_on_failure",
        [
          Alcotest.test_case "store op failure still dispatches" `Quick
            test_store_failure_still_dispatches;
          Alcotest.test_case "event emit failure still dispatches" `Quick
            test_event_failure_still_dispatches;
        ] );
    ]

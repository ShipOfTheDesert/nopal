(* White-box access to the wide (package-internal) Telemetry interface. The
   public [Nopal_runtime.Telemetry] re-export narrows away [off], [create], and
   the [record_*] operations so a handle is unforgeable outside the package;
   these tests need that wide surface, so they reach the unwrapped module
   directly (cf. test_toast_section.ml). *)
module T = Nopal_runtime__Telemetry

let event_testable =
  let pp fmt e = T.pp_events fmt [ e ] in
  let equal a b = a = b in
  Alcotest.testable pp equal

let test_off_records_nothing () =
  let serialiser_called = ref false in
  let serialize x =
    serialiser_called := true;
    string_of_int x
  in
  T.record_message T.off 1 ~serialize;
  T.record_transition T.off ~before:1 ~after:2 ~serialize;
  Alcotest.(check bool) "off forces no serialiser" false !serialiser_called;
  let _recorder, handle = T.create () in
  Alcotest.(check (list event_testable))
    "a separately-created handle stays empty" [] (T.events handle)

let test_clear_empties_log () =
  let recorder, handle = T.create () in
  T.record_message recorder "hello" ~serialize:Fun.id;
  T.record_command recorder "perform";
  Alcotest.(check int) "two events recorded" 2 (List.length (T.events handle));
  T.clear handle;
  Alcotest.(check (list event_testable))
    "log emptied after clear" [] (T.events handle)

let test_on_record_forwards_each_event () =
  let recorder, handle = T.create () in
  let seen = ref [] in
  let (_ : unit -> unit) = T.on_record handle (fun e -> seen := e :: !seen) in
  T.record_message recorder "a" ~serialize:Fun.id;
  T.record_command recorder "batch";
  T.record_subscription recorder "every";
  let expected = [ T.Message "a"; T.Command "batch"; T.Subscription "every" ] in
  Alcotest.(check (list event_testable))
    "sink received every event in order" expected (List.rev !seen)

let test_on_record_unsubscribe () =
  let recorder, handle = T.create () in
  let count = ref 0 in
  let unsubscribe = T.on_record handle (fun _ -> incr count) in
  T.record_command recorder "a";
  Alcotest.(check int) "sink fired once while subscribed" 1 !count;
  unsubscribe ();
  T.record_command recorder "b";
  Alcotest.(check int) "sink silent after unsubscribe" 1 !count

(* The log is bounded (feature 0120 FR-7): an [expose]d Tauri/web mirror forwards
   every recorded event for the whole session, so without a cap the log would
   grow unbounded. Recording past [log_capacity] must retain exactly the newest
   [log_capacity] events and drop the oldest. *)
let test_log_bounded_drops_oldest () =
  let recorder, handle = T.create () in
  let last = T.log_capacity + 1 in
  for i = 1 to last do
    T.record_command recorder (string_of_int i)
  done;
  let events = T.events handle in
  Alcotest.(check int)
    "log capped at capacity" T.log_capacity (List.length events);
  Alcotest.(check bool)
    "oldest event (command 1) dropped" false
    (List.mem (T.Command "1") events);
  Alcotest.(check bool)
    "new oldest (command 2) retained" true
    (List.mem (T.Command "2") events);
  Alcotest.(check bool)
    "newest event retained" true
    (List.mem (T.Command (string_of_int last)) events)

let () =
  Alcotest.run "Telemetry"
    [
      ( "Recorder",
        [
          Alcotest.test_case "off records nothing" `Quick
            test_off_records_nothing;
          Alcotest.test_case "clear empties log" `Quick test_clear_empties_log;
          Alcotest.test_case "on_record forwards each event" `Quick
            test_on_record_forwards_each_event;
          Alcotest.test_case "on_record disposer unsubscribes" `Quick
            test_on_record_unsubscribe;
          Alcotest.test_case "log bounded — drops oldest past capacity" `Quick
            test_log_bounded_drops_oldest;
        ] );
    ]

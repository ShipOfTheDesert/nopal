let test_current_path_reads_location () =
  let path = Nopal_web.Platform_web.current_path () in
  Alcotest.(check string) "current_path returns initial path" "/" path

let test_push_state_changes_path () =
  Nopal_web.Platform_web.push_state "/test-push";
  let path = Nopal_web.Platform_web.current_path () in
  Alcotest.(check string) "path is /test-push" "/test-push" path

let test_replace_state_changes_path () =
  Nopal_web.Platform_web.replace_state "/test-replace";
  let path = Nopal_web.Platform_web.current_path () in
  Alcotest.(check string) "path is /test-replace" "/test-replace" path

let test_back_navigates_previous () =
  Nopal_web.Platform_web.push_state "/page-a";
  Nopal_web.Platform_web.push_state "/page-b";
  Nopal_web.Platform_web.back ();
  let path = Nopal_web.Platform_web.current_path () in
  Alcotest.(check string) "path is /page-a" "/page-a" path

let get_listener_count event_type =
  let window = Jv.get Jv.global "window" in
  Jv.to_int (Jv.call window "_getListenerCount" [| Jv.of_string event_type |])

let test_on_popstate_registers_listener () =
  let before = get_listener_count "popstate" in
  let cleanup = Nopal_web.Platform_web.on_popstate (fun _path -> ()) in
  let after = get_listener_count "popstate" in
  Alcotest.(check int) "listener added" (before + 1) after;
  cleanup ();
  let after_cleanup = get_listener_count "popstate" in
  Alcotest.(check int) "listener removed" before after_cleanup

let () =
  Alcotest.run "platform_web"
    [
      ( "platform_web",
        [
          Alcotest.test_case "current_path reads location" `Quick
            test_current_path_reads_location;
          Alcotest.test_case "push_state changes path" `Quick
            test_push_state_changes_path;
          Alcotest.test_case "replace_state changes path" `Quick
            test_replace_state_changes_path;
          Alcotest.test_case "back navigates previous" `Quick
            test_back_navigates_previous;
          Alcotest.test_case "on_popstate registers and cleans up listener"
            `Quick test_on_popstate_registers_listener;
        ] );
    ]

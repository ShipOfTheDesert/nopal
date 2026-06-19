(* Sub_manager.diff is now driven by a backend-supplied [interpret] over
   [Sub.atom]s (REQ-F3, REQ-F4). These tests use fake interpreters to pin the
   three failure-handling contracts the platform-agnostic diff owns:
     - a setup that returns [Error] is reported and its key is NOT registered,
       so the next diff retries it;
     - a key appearing twice in one diff: first wins, the duplicate is reported;
     - a removed key's cleanup runs exactly once. *)

module Sub_manager = Nopal_runtime.Sub_manager
module Sub = Nopal_mvu.Sub

(* Build an atom interpreter from a Custom-only handler. These tests only
   construct [custom] subscriptions, so any non-Custom atom is a test bug,
   surfaced as [Error] — keeping the match exhaustive without a catch-all
   (repo rule). *)
let custom_only handle = function
  | Sub.Custom { key; setup } -> handle key setup
  | Sub.Every { key; _ } -> Error ("unexpected Every: " ^ key)
  | Sub.Keydown { key; _ } -> Error ("unexpected Keydown: " ^ key)
  | Sub.Keyup { key; _ } -> Error ("unexpected Keyup: " ^ key)
  | Sub.Resize { key; _ } -> Error ("unexpected Resize: " ^ key)
  | Sub.Visibility { key; _ } -> Error ("unexpected Visibility: " ^ key)
  | Sub.Viewport { key; _ } -> Error ("unexpected Viewport: " ^ key)

let test_setup_error_reported_and_key_retried_on_next_diff () =
  let mgr = Sub_manager.create () in
  let errors = ref [] in
  let on_error e = errors := e :: !errors in
  let setup_count = ref 0 in
  (* mutable: flips the interpreter from failing to succeeding between the two
     diffs so the retry path can be observed *)
  let fail = ref true in
  let interpret =
    custom_only (fun key setup ->
        if !fail then Error ("boom: " ^ key)
        else (
          incr setup_count;
          Ok (setup (fun _msg -> ()))))
  in
  let sub = Sub.custom "k" (fun _dispatch -> fun () -> ()) in
  Sub_manager.diff ~on_error ~interpret sub mgr;
  Alcotest.(check (list string))
    "key not registered after setup error" []
    (Sub_manager.active_keys mgr);
  Alcotest.(check int) "setup error reported once" 1 (List.length !errors);
  Alcotest.(check int) "setup body not run on error" 0 !setup_count;
  (* Same subscription, interpreter now succeeds: the key the prior diff failed
     to register is retried and registered. *)
  fail := false;
  Sub_manager.diff ~on_error ~interpret sub mgr;
  Alcotest.(check (list string))
    "key registered on the retrying diff" [ "k" ]
    (Sub_manager.active_keys mgr);
  Alcotest.(check int) "setup body run once on retry" 1 !setup_count;
  Alcotest.(check int) "no further error on retry" 1 (List.length !errors)

let test_duplicate_keys_first_wins_and_reported () =
  let mgr = Sub_manager.create () in
  let errors = ref [] in
  let on_error e = errors := e :: !errors in
  let interpreted = ref [] in
  let interpret =
    custom_only (fun key setup ->
        interpreted := key :: !interpreted;
        Ok (setup (fun _msg -> ())))
  in
  let sub =
    Sub.batch
      [
        Sub.custom "dup" (fun _dispatch -> fun () -> ());
        Sub.custom "dup" (fun _dispatch -> fun () -> ());
      ]
  in
  Sub_manager.diff ~on_error ~interpret sub mgr;
  Alcotest.(check (list string))
    "duplicate key registered exactly once" [ "dup" ]
    (Sub_manager.active_keys mgr);
  Alcotest.(check int)
    "interpret called once — the first occurrence wins" 1
    (List.length !interpreted);
  Alcotest.(check int) "the duplicate is reported" 1 (List.length !errors)

let test_cleanup_called_once_per_removed_key () =
  let mgr = Sub_manager.create () in
  let cleanup_count = ref 0 in
  let interpret = custom_only (fun _key setup -> Ok (setup (fun _msg -> ()))) in
  let present =
    Sub.custom "k" (fun _dispatch -> fun () -> incr cleanup_count)
  in
  Sub_manager.diff ~interpret present mgr;
  Alcotest.(check (list string))
    "key active before removal" [ "k" ]
    (Sub_manager.active_keys mgr);
  Sub_manager.diff ~interpret Sub.none mgr;
  Alcotest.(check int) "cleanup called exactly once on removal" 1 !cleanup_count;
  Alcotest.(check (list string))
    "no active keys after removal" []
    (Sub_manager.active_keys mgr);
  (* Diffing the empty set again must not re-run the cleanup. *)
  Sub_manager.diff ~interpret Sub.none mgr;
  Alcotest.(check int) "cleanup not run a second time" 1 !cleanup_count

let () =
  Alcotest.run "sub_manager"
    [
      ( "diff",
        [
          Alcotest.test_case "setup error reported and key retried on next diff"
            `Quick test_setup_error_reported_and_key_retried_on_next_diff;
          Alcotest.test_case "duplicate keys: first wins and reported" `Quick
            test_duplicate_keys_first_wins_and_reported;
          Alcotest.test_case "cleanup called once per removed key" `Quick
            test_cleanup_called_once_per_removed_key;
        ] );
    ]

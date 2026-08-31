(* Behavioural tests for the Tauri filesystem storage backend against the
   tauri-plugin-fs stub in fs_shim.js.

   The scenario these exist for is a SECOND run: write a value, then read it
   back. A first run on a fresh install never reads anything (the key is absent,
   [get] answers [Ok None] off [list_keys] without touching the file), so a
   suite that only exercised absence would pass with the read path completely
   broken — which is exactly what happened. The bug this pins was found on an
   Android handset, where a stored 128-byte JSON document read back as the
   literal ["[object ArrayBuffer]"]: [plugin:fs|read_text_file] answers with the
   file's bytes, and the backend applied [Jv.to_string] — an unchecked cast — to
   them.

   The three read shapes are driven through the public backend rather than
   asserted against an exposed internal: an ArrayBuffer (the custom-protocol and
   channel transports — Linux, Windows, and the Android path that failed), a
   JSON number array (macOS and iOS), and a shape that is neither (which must
   resolve [Error] and not hang, since the decoder runs past the point
   [Task.guard] can catch a raise).

   Assertions are deferred behind [_flush] until every chained task has resolved
   — the backend settles through [Fut.of_promise]/[Fut.await], whose hops are
   microtask-deferred (mirrors test_indexeddb). The scenarios are sequenced
   inside one another because they share the one scoped directory. *)

module Store = Nopal_storage_tauri.Make ()
open Nopal_mvu.Task.Syntax

let flush_then_run k =
  let flush = Jv.get Jv.global "_flush" in
  ignore (Jv.apply flush [| Jv.callback ~arity:1 (fun _ -> k ()) |])

let set_read_shape shape =
  ignore
    (Jv.apply
       (Jv.get Jv.global "__nopal_fs_set_read_shape")
       [| Jv.of_string shape |])

(* The value is a JSON document rather than a bare word on purpose: it is the
   shape the application actually stores, and a decode that returns
   ["[object ArrayBuffer]"] is caught by any of them — but a byte-exact
   round-trip of punctuation and a multi-byte character also pins that the
   TextEncoder/TextDecoder pair is UTF-8 and inverse, not merely present. *)
let stored = {|{"version":1,"events":[{"grade":"got_it","note":"café"}]}|}

let () =
  let roundtrip = ref None in
  let ios_shape = ref None in
  let bad_shape = ref None in
  let after_delete = ref None in
  let delete_absent = ref None in
  let listed = ref None in
  let write_task = Store.set ~key:"grokkr.reviews.v1" ~value:stored in
  let read_task = Store.get "grokkr.reviews.v1" in
  let keys_task = Store.keys () in
  let delete_task =
    let* _ = Store.delete "grokkr.reviews.v1" in
    Store.get "grokkr.reviews.v1"
  in
  (* Deleting a key that was never written. Sequenced last, so by the time it
     runs the store really is empty and the key really is absent. *)
  let delete_absent_task = Store.delete "grokkr.never.written" in
  Nopal_mvu.Task.run write_task (fun _ ->
      Nopal_mvu.Task.run read_task (fun r ->
          roundtrip := Some r;
          set_read_shape "array";
          Nopal_mvu.Task.run (Store.get "grokkr.reviews.v1") (fun ri ->
              ios_shape := Some ri;
              set_read_shape "bogus";
              Nopal_mvu.Task.run (Store.get "grokkr.reviews.v1") (fun rb ->
                  bad_shape := Some rb;
                  set_read_shape "buffer";
                  Nopal_mvu.Task.run keys_task (fun rk ->
                      listed := Some rk;
                      Nopal_mvu.Task.run delete_task (fun rd ->
                          after_delete := Some rd;
                          Nopal_mvu.Task.run delete_absent_task (fun ra ->
                              delete_absent := Some ra)))))));
  flush_then_run (fun () ->
      Alcotest.run "nopal_storage_tauri"
        [
          ( "fs_store",
            [
              Alcotest.test_case "set/get round-trips a stored value" `Quick
                (fun () ->
                  match !roundtrip with
                  | Some (Ok (Some v)) ->
                      Alcotest.(check string)
                        "value read back is the value written" stored v
                  | Some (Ok None) ->
                      Alcotest.fail
                        "expected the written value, got Ok None — the key was \
                         written but not found"
                  | Some (Error e) ->
                      Alcotest.failf "expected Ok (Some _), got error: %s"
                        (Nopal_storage.message e)
                  | None -> Alcotest.fail "read task never resolved");
              Alcotest.test_case "a number-array response decodes too" `Quick
                (fun () ->
                  match !ios_shape with
                  | Some (Ok (Some v)) ->
                      Alcotest.(check string)
                        "macOS/iOS number-array response decodes identically"
                        stored v
                  | Some (Ok None) -> Alcotest.fail "expected Ok (Some _)"
                  | Some (Error e) ->
                      Alcotest.failf "expected Ok (Some _), got error: %s"
                        (Nopal_storage.message e)
                  | None -> Alcotest.fail "number-array task never resolved");
              Alcotest.test_case "an undecodable response errors, not hangs"
                `Quick (fun () ->
                  match !bad_shape with
                  | Some (Error (Nopal_storage.Backend_error _)) -> ()
                  | Some (Error e) ->
                      Alcotest.failf "expected Backend_error, got: %s"
                        (Nopal_storage.message e)
                  | Some (Ok _) ->
                      Alcotest.fail
                        "expected Error for a response that is neither text \
                         nor bytes, got Ok"
                  | None ->
                      Alcotest.fail
                        "task never resolved — the decoder raised instead of \
                         reporting");
              Alcotest.test_case "keys round-trips the encoded filename" `Quick
                (fun () ->
                  match !listed with
                  | Some (Ok keys) ->
                      Alcotest.(check (list string))
                        "the key decodes back out of its filename"
                        [ "grokkr.reviews.v1" ] keys
                  | Some (Error e) ->
                      Alcotest.failf "expected Ok, got error: %s"
                        (Nopal_storage.message e)
                  | None -> Alcotest.fail "keys task never resolved");
              Alcotest.test_case "delete removes the value" `Quick (fun () ->
                  match !after_delete with
                  | Some (Ok None) -> ()
                  | Some (Ok (Some _)) -> Alcotest.fail "value survived delete"
                  | Some (Error e) ->
                      Alcotest.failf "expected Ok None, got error: %s"
                        (Nopal_storage.message e)
                  | None -> Alcotest.fail "delete task never resolved");
              (* Absence is not an error here, and this pins that it is a
                 deliberate contract rather than an accident of the
                 implementation. [Make]'s [delete] guards on [List.mem] over
                 [list_keys] and returns [Ok ()] when the key is not there, so a
                 caller cannot use the result to learn whether anything was
                 removed. That is the property to know about before writing a
                 caller that wants to: it would need [keys] first.

                 It also must not be an unresolved task. The decoder for a
                 delete runs where [Task.guard] cannot catch a raise, so "no
                 key" reaching the filesystem layer and raising would hang
                 rather than report — which is why the [None] arm below says so
                 specifically. *)
              Alcotest.test_case "deleting an absent key reports Ok ()" `Quick
                (fun () ->
                  match !delete_absent with
                  | Some (Ok ()) -> ()
                  | Some (Error e) ->
                      Alcotest.failf
                        "expected Ok () for a key that was never written, got \
                         error: %s"
                        (Nopal_storage.message e)
                  | None ->
                      Alcotest.fail
                        "delete-absent task never resolved — deleting a \
                         missing key raised instead of reporting");
            ] );
        ])

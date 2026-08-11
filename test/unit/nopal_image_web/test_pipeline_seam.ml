(* The browser backend reached through the seam application code actually calls.

   Every other suite drives one side with the other degenerate: the native seam
   tests drive [Processing.process] against a stub backend, and the pipeline
   suites drive [Nopal_image_web.process] as a task directly, bypassing
   registration and the command entirely. Neither exercises the thing this
   package exists to provide - the browser implementation reached through
   [register_backend] and dispatched as a [Cmd] - and a drift on either side of
   that join would compile, pass both suites, and surface first in an
   application.

   The registration in the doc comment on [Nopal_image_web.process] is the exact
   expression under test here, so it is compiled truth rather than prose. *)

open Nopal_image
open Image_web_test_helpers

(* The registration a mounting layer performs, undone afterwards however the
   case ends: the backend is module-level state, and a case that left the
   browser backend installed would change what every later case in this
   executable is testing. *)
let with_browser_backend f =
  Processing.register_backend { Processing.process = Nopal_image_web.process };
  Fun.protect
    ~finally:(fun () -> Processing.register_backend Processing.default_backend)
    f

(* Drives the seam's command and answers every message it dispatched. A list
   rather than an option because a seam that dispatched twice is invisible to an
   option that simply overwrites. *)
let dispatched ~blob_id ~config =
  let messages = ref [] in
  Nopal_mvu.Cmd.execute
    (fun outcome -> messages := outcome :: !messages)
    (Processing.process ~blob_id ~config Fun.id);
  flush ();
  List.rev !messages

let single ~context messages =
  match messages with
  | [ message ] -> message
  | [] ->
      Alcotest.failf "%s: the command dispatched nothing, expected one message"
        context
  | _ ->
      Alcotest.failf "%s: the command dispatched %d messages, expected one"
        context (List.length messages)

(* The whole join: a command built from the registered backend runs the real
   browser pipeline, and what comes back out of the command is what the pipeline
   produced - measured off the shim, not echoed from the configuration. *)
let test_registered_backend_runs_the_browser_pipeline () =
  reset ();
  set_source ~width:1000 ~height:750;
  let config = fixture_config () in
  let source_id = stored_source () in
  let info =
    with_browser_backend (fun () ->
        processed
          (single ~context:"the registered browser backend"
             (dispatched ~blob_id:source_id ~config)))
  in
  Alcotest.(check (list string))
    "the command ran the browser pipeline's stages in order"
    [ "decode"; "draw"; "encode"; "draw"; "pixels"; "release" ]
    (calls ());
  Alcotest.(check int)
    "the command's result reports the size the upload canvas was drawn at" 900
    info.Processing.width;
  Alcotest.(check bool)
    "the command's result carries a handle the store resolves" true
    (Brr.Blob.byte_length (blob_under info.Processing.blob_id) > 0);
  Alcotest.(check bool)
    "the processed image is stored under a handle of its own" true
    (not (String.equal info.Processing.blob_id source_id))

(* A failure crosses the join as a value too, keeping its arm: the seam does not
   flatten what the backend distinguished. *)
let test_backend_failure_reaches_the_caller_through_the_seam () =
  reset ();
  set_source ~width:1000 ~height:750;
  let config = fixture_config () in
  let outcome =
    with_browser_backend (fun () ->
        single ~context:"an unresolvable handle through the seam"
          (dispatched ~blob_id:(released_handle ()) ~config))
  in
  Alcotest.(check string)
    "the backend's own arm survives the seam" "blob lookup"
    (stage_of_error (failure_of outcome))

(* Restoring the default un-registers the browser backend. Without this the
   suite could not tell a registration that worked from one that was never
   needed, because the default answers every call too. *)
let test_restoring_the_default_unregisters_the_backend () =
  reset ();
  set_source ~width:1000 ~height:750;
  let config = fixture_config () in
  let source_id = stored_source () in
  ignore
    (with_browser_backend (fun () ->
         single ~context:"the registered browser backend"
           (dispatched ~blob_id:source_id ~config)));
  reset ();
  set_source ~width:1000 ~height:750;
  let outcome =
    single ~context:"the restored default"
      (dispatched ~blob_id:source_id ~config)
  in
  Alcotest.(check string)
    "the restored default answers instead of the browser backend" "canvas"
    (stage_of_error (failure_of outcome));
  Alcotest.(check (list string))
    "the restored default runs no browser stage at all" [] (calls ())

let tests =
  [
    Alcotest.test_case "a registered backend runs the browser pipeline" `Quick
      test_registered_backend_runs_the_browser_pipeline;
    Alcotest.test_case "a backend failure keeps its arm through the seam" `Quick
      test_backend_failure_reaches_the_caller_through_the_seam;
    Alcotest.test_case "restoring the default unregisters the backend" `Quick
      test_restoring_the_default_unregisters_the_backend;
  ]

let () = Alcotest.run "Pipeline seam" [ ("Pipeline seam", tests) ]

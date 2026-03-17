type test_msg = Got of Nopal_http.outcome | Mapped of string

(* Defers [k] until after all microtasks have flushed via setTimeout(0).
   Brr_io.Fetch wraps browser fetch in Promise.then() chains. Even with
   a synchronously-resolving fetch shim, .then() callbacks are microtasks
   that run after the current synchronous code completes. A single
   setTimeout(0) fires after the entire microtask queue drains, so all
   Cmd.task dispatch callbacks will have run by the time [k] executes. *)
let flush_then_run k =
  let flush = Jv.get Jv.global "_flush" in
  ignore (Jv.apply flush [| Jv.callback ~arity:1 (fun _ -> k ()) |])

let () =
  (* Execute all async commands now — dispatches happen during microtask flush *)
  let results_success = ref [] in
  let results_404 = ref [] in
  let results_network = ref [] in
  let results_body_error = ref [] in
  let results_mapped = ref [] in
  Nopal_mvu.Cmd.execute
    (fun msg -> results_success := msg :: !results_success)
    (Nopal_http_web.get "https://example.com/success" (fun outcome ->
         Got outcome));
  Nopal_mvu.Cmd.execute
    (fun msg -> results_404 := msg :: !results_404)
    (Nopal_http_web.get "https://example.com/404" (fun outcome -> Got outcome));
  Nopal_mvu.Cmd.execute
    (fun msg -> results_network := msg :: !results_network)
    (Nopal_http_web.get "https://example.com/network-error" (fun outcome ->
         Got outcome));
  Nopal_mvu.Cmd.execute
    (fun msg -> results_body_error := msg :: !results_body_error)
    (Nopal_http_web.get "https://example.com/body-error" (fun outcome ->
         Got outcome));
  Nopal_mvu.Cmd.execute
    (fun msg -> results_mapped := msg :: !results_mapped)
    (Nopal_http_web.get "https://example.com/success" (fun outcome ->
         match outcome with
         | Ok resp -> Mapped ("status:" ^ string_of_int resp.Nopal_http.status)
         | Error _ -> Mapped "error"));
  (* Defer all assertions until after microtask flush *)
  flush_then_run (fun () ->
      Alcotest.run "nopal_http_web"
        [
          ( "Http_web",
            [
              Alcotest.test_case "get success dispatches ok" `Quick (fun () ->
                  match !results_success with
                  | [ Got (Ok resp) ] ->
                      Alcotest.(check int)
                        "status is 200" 200 resp.Nopal_http.status;
                      Alcotest.(check string)
                        "body is ok body" "ok body" resp.Nopal_http.body
                  | _ ->
                      Alcotest.fail
                        "expected exactly one Got (Ok { status = 200; ... })");
              Alcotest.test_case "get non-200 dispatches ok with status" `Quick
                (fun () ->
                  match !results_404 with
                  | [ Got (Ok resp) ] ->
                      Alcotest.(check int)
                        "status is 404" 404 resp.Nopal_http.status;
                      Alcotest.(check string)
                        "body is not found" "not found" resp.Nopal_http.body
                  | _ ->
                      Alcotest.fail
                        "expected exactly one Got (Ok { status = 404; ... })");
              Alcotest.test_case "get network error dispatches error" `Quick
                (fun () ->
                  match !results_network with
                  | [ Got (Error (Nopal_http.Network_error msg)) ] ->
                      Alcotest.(check bool)
                        "error message is non-empty" true
                        (String.length msg > 0)
                  | _ ->
                      Alcotest.fail
                        "expected exactly one Got (Error (Network_error _))");
              Alcotest.test_case "get body read error dispatches error" `Quick
                (fun () ->
                  match !results_body_error with
                  | [ Got (Error (Nopal_http.Network_error msg)) ] ->
                      Alcotest.(check bool)
                        "error message is non-empty" true
                        (String.length msg > 0)
                  | _ ->
                      Alcotest.fail
                        "expected exactly one Got (Error (Network_error _))");
              Alcotest.test_case "get returns cmd" `Quick (fun () ->
                  let cmd =
                    Nopal_http_web.get "https://example.com/success"
                      (fun outcome -> Got outcome)
                  in
                  let is_cmd =
                    match Nopal_mvu.Cmd.extract_after cmd with
                    | None -> true
                    | Some _ -> false
                  in
                  Alcotest.(check bool)
                    "get returns a non-after cmd" true is_cmd);
              Alcotest.test_case "get callback maps outcome" `Quick (fun () ->
                  match !results_mapped with
                  | [ Mapped s ] ->
                      Alcotest.(check string)
                        "callback mapped outcome" "status:200" s
                  | _ -> Alcotest.fail "expected exactly one Mapped message");
            ] );
        ])

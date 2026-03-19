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
  let results_get_success = ref [] in
  let results_404 = ref [] in
  let results_network = ref [] in
  let results_body_error = ref [] in
  let results_mapped = ref [] in
  let results_post = ref [] in
  let results_post_network = ref [] in
  let results_get_headers = ref [] in
  let results_put = ref [] in
  let results_delete = ref [] in
  let results_patch = ref [] in
  let results_delete_body = ref [] in
  let results_form_encoded = ref [] in
  let results_multipart = ref [] in
  let results_timeout = ref [] in
  Nopal_mvu.Cmd.execute
    (fun msg -> results_get_success := msg :: !results_get_success)
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
  Nopal_mvu.Cmd.execute
    (fun msg -> results_post := msg :: !results_post)
    (Nopal_http_web.post
       ~headers:[ ("Content-Type", "application/json") ]
       ~body:
         (Nopal_http.String { content = "test-payload"; content_type = None })
       "https://example.com/success"
       (fun outcome -> Got outcome));
  Nopal_mvu.Cmd.execute
    (fun msg -> results_post_network := msg :: !results_post_network)
    (Nopal_http_web.post
       ~body:(Nopal_http.String { content = "hello"; content_type = None })
       "https://example.com/network-error"
       (fun outcome -> Got outcome));
  Nopal_mvu.Cmd.execute
    (fun msg -> results_get_headers := msg :: !results_get_headers)
    (Nopal_http_web.get
       ~headers:[ ("Authorization", "Bearer token123") ]
       "https://example.com/success"
       (fun outcome -> Got outcome));
  Nopal_mvu.Cmd.execute
    (fun msg -> results_put := msg :: !results_put)
    (Nopal_http_web.put
       ~body:
         (Nopal_http.String { content = "put-payload"; content_type = None })
       "https://example.com/success"
       (fun outcome -> Got outcome));
  Nopal_mvu.Cmd.execute
    (fun msg -> results_delete := msg :: !results_delete)
    (Nopal_http_web.delete_ "https://example.com/success" (fun outcome ->
         Got outcome));
  Nopal_mvu.Cmd.execute
    (fun msg -> results_patch := msg :: !results_patch)
    (Nopal_http_web.patch
       ~body:(Nopal_http.String { content = "patch-data"; content_type = None })
       "https://example.com/success"
       (fun outcome -> Got outcome));
  Nopal_mvu.Cmd.execute
    (fun msg -> results_delete_body := msg :: !results_delete_body)
    (Nopal_http_web.delete_
       ~body:
         (Nopal_http.String { content = "delete-payload"; content_type = None })
       "https://example.com/success"
       (fun outcome -> Got outcome));
  Nopal_mvu.Cmd.execute
    (fun msg -> results_form_encoded := msg :: !results_form_encoded)
    (Nopal_http_web.post
       ~body:
         (Nopal_http.Form_encoded
            [ ("a&b", "c=d"); ("space key", "val ue"); ("utf8", "\xc3\xa9") ])
       "https://example.com/success"
       (fun outcome -> Got outcome));
  Nopal_mvu.Cmd.execute
    (fun msg -> results_multipart := msg :: !results_multipart)
    (Nopal_http_web.post
       ~body:(Nopal_http.Multipart [ ("name", "nopal"); ("version", "1") ])
       "https://example.com/success"
       (fun outcome -> Got outcome));
  Nopal_mvu.Cmd.execute
    (fun msg -> results_timeout := msg :: !results_timeout)
    (Nopal_http_web.get ~timeout:0.01 "https://example.com/delay"
       (fun outcome -> Got outcome));
  (* Defer all assertions until after microtask flush *)
  flush_then_run (fun () ->
      Alcotest.run "nopal_http_web"
        [
          ( "Http_web",
            [
              Alcotest.test_case "get success: status, body, headers" `Quick
                (fun () ->
                  match !results_get_success with
                  | [ Got (Ok resp) ] ->
                      Alcotest.(check int)
                        "status is 200" 200 resp.Nopal_http.status;
                      Alcotest.(check string)
                        "body is ok body" "ok body" resp.Nopal_http.body;
                      (* Response headers populated *)
                      let has_ct =
                        List.exists
                          (fun (k, _) -> k = "content-type")
                          resp.Nopal_http.headers
                      in
                      let has_xrid =
                        List.exists
                          (fun (k, _) -> k = "x-request-id")
                          resp.Nopal_http.headers
                      in
                      Alcotest.(check bool)
                        "has content-type header" true has_ct;
                      Alcotest.(check bool)
                        "has x-request-id header" true has_xrid;
                      (* All header names lowercased *)
                      let all_lower =
                        List.for_all
                          (fun (k, _) -> k = String.lowercase_ascii k)
                          resp.Nopal_http.headers
                      in
                      Alcotest.(check bool)
                        "all header names are lowercase" true all_lower
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
              Alcotest.test_case "get callback maps outcome" `Quick (fun () ->
                  match !results_mapped with
                  | [ Mapped s ] ->
                      Alcotest.(check string)
                        "callback mapped outcome" "status:200" s
                  | _ -> Alcotest.fail "expected exactly one Mapped message");
              Alcotest.test_case "post sends body and headers" `Quick (fun () ->
                  match !results_post with
                  | [ Got (Ok resp) ] ->
                      Alcotest.(check int)
                        "status is 200" 200 resp.Nopal_http.status;
                      Alcotest.(check bool)
                        "response contains test-payload" true
                        (Test_util.string_contains resp.Nopal_http.body
                           ~sub:"test-payload");
                      Alcotest.(check bool)
                        "response contains content-type" true
                        (Test_util.string_contains resp.Nopal_http.body
                           ~sub:"content-type")
                  | _ ->
                      Alcotest.fail
                        "expected exactly one Got (Ok _) for post test");
              Alcotest.test_case "post network error dispatches error" `Quick
                (fun () ->
                  match !results_post_network with
                  | [ Got (Error (Nopal_http.Network_error msg)) ] ->
                      Alcotest.(check bool)
                        "error message is non-empty" true
                        (String.length msg > 0)
                  | _ ->
                      Alcotest.fail
                        "expected exactly one Got (Error (Network_error _))");
              Alcotest.test_case "get with headers sends headers" `Quick
                (fun () ->
                  match !results_get_headers with
                  | [ Got (Ok resp) ] ->
                      Alcotest.(check bool)
                        "response contains authorization" true
                        (Test_util.string_contains resp.Nopal_http.body
                           ~sub:"authorization")
                  | _ ->
                      Alcotest.fail
                        "expected exactly one Got (Ok _) for get headers test");
              Alcotest.test_case "put success and body" `Quick (fun () ->
                  match !results_put with
                  | [ Got (Ok resp) ] ->
                      Alcotest.(check int)
                        "status is 200" 200 resp.Nopal_http.status;
                      Alcotest.(check bool)
                        "response contains put-payload" true
                        (Test_util.string_contains resp.Nopal_http.body
                           ~sub:"put-payload")
                  | _ ->
                      Alcotest.fail
                        "expected exactly one Got (Ok _) for put test");
              Alcotest.test_case "delete success" `Quick (fun () ->
                  match !results_delete with
                  | [ Got (Ok resp) ] ->
                      Alcotest.(check int)
                        "status is 200" 200 resp.Nopal_http.status
                  | _ ->
                      Alcotest.fail
                        "expected exactly one Got (Ok { status = 200; ... })");
              Alcotest.test_case "patch success" `Quick (fun () ->
                  match !results_patch with
                  | [ Got (Ok resp) ] ->
                      Alcotest.(check int)
                        "status is 200" 200 resp.Nopal_http.status
                  | _ ->
                      Alcotest.fail
                        "expected exactly one Got (Ok { status = 200; ... })");
              Alcotest.test_case "form_encoded encodes special characters"
                `Quick (fun () ->
                  match !results_form_encoded with
                  | [ Got (Ok resp) ] ->
                      (* The fetch shim echoes the body field. Form-encoded body
                         should contain URL-encoded keys and values joined by &. *)
                      let body = resp.Nopal_http.body in
                      Alcotest.(check bool)
                        "body contains encoded ampersand (a%26b)" true
                        (Test_util.string_contains body ~sub:"a%26b");
                      Alcotest.(check bool)
                        "body contains encoded equals (c%3Dd)" true
                        (Test_util.string_contains body ~sub:"c%3Dd");
                      Alcotest.(check bool)
                        "body contains encoded space (space%20key)" true
                        (Test_util.string_contains body ~sub:"space%20key");
                      Alcotest.(check bool)
                        "body contains pair separator (&)" true
                        (Test_util.string_contains body ~sub:"&")
                  | _ ->
                      Alcotest.fail
                        "expected exactly one Got (Ok _) for form_encoded test");
              Alcotest.test_case "delete with body sends body" `Quick (fun () ->
                  match !results_delete_body with
                  | [ Got (Ok resp) ] ->
                      Alcotest.(check bool)
                        "response contains delete-payload" true
                        (Test_util.string_contains resp.Nopal_http.body
                           ~sub:"delete-payload")
                  | _ ->
                      Alcotest.fail
                        "expected exactly one Got (Ok _) for delete body test");
              Alcotest.test_case "multipart sends FormData entries" `Quick
                (fun () ->
                  match !results_multipart with
                  | [ Got (Ok resp) ] ->
                      (* The shim serialises FormData._entries as a JSON array.
                         Verify both entries appear in the echoed body. *)
                      Alcotest.(check bool)
                        "body contains name entry" true
                        (Test_util.string_contains resp.Nopal_http.body
                           ~sub:"nopal");
                      Alcotest.(check bool)
                        "body contains version entry" true
                        (Test_util.string_contains resp.Nopal_http.body
                           ~sub:"version")
                  | _ ->
                      Alcotest.fail
                        "expected exactly one Got (Ok _) for multipart test");
              Alcotest.test_case "timeout aborts and dispatches Timeout" `Quick
                (fun () ->
                  match !results_timeout with
                  | [ Got (Error Nopal_http.Timeout) ] -> ()
                  | [ Got (Error (Nopal_http.Network_error msg)) ] ->
                      Alcotest.fail
                        ("expected Timeout but got Network_error: " ^ msg)
                  | [ Got (Ok _) ] ->
                      Alcotest.fail
                        "expected Timeout but got Ok (request was not aborted)"
                  | _ ->
                      Alcotest.fail "expected exactly one Got (Error Timeout)");
            ] );
        ])

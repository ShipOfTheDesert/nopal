let test_response_construction () =
  let r : Nopal_http.response = { status = 200; body = "hello" } in
  Alcotest.(check int) "status is 200" 200 r.status;
  Alcotest.(check string) "body is hello" "hello" r.body

let test_error_network_error () =
  let err = Nopal_http.Network_error "connection refused" in
  match err with
  | Nopal_http.Network_error msg ->
      Alcotest.(check string) "error message" "connection refused" msg

let test_outcome_ok () =
  let r : Nopal_http.response = { status = 200; body = "ok" } in
  let outcome : Nopal_http.outcome = Ok r in
  match outcome with
  | Ok resp ->
      Alcotest.(check int) "ok status" 200 resp.status;
      Alcotest.(check string) "ok body" "ok" resp.body
  | Error _ -> Alcotest.fail "expected Ok"

let test_outcome_error () =
  let outcome : Nopal_http.outcome =
    Error (Nopal_http.Network_error "timeout")
  in
  match outcome with
  | Ok _ -> Alcotest.fail "expected Error"
  | Error (Nopal_http.Network_error msg) ->
      Alcotest.(check string) "error msg" "timeout" msg

type test_msg = Got of Nopal_http.outcome

let test_get_returns_cmd () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  let cmd = Nopal_http.get "https://example.com" (fun outcome -> Got outcome) in
  Nopal_mvu.Cmd.execute dispatch cmd;
  match !results with
  | [ Got (Error (Nopal_http.Network_error msg)) ] ->
      Alcotest.(check string)
        "error mentions url" "no HTTP backend: https://example.com" msg
  | _ -> Alcotest.fail "expected exactly one Got (Error (Network_error _))"

let test_register_backend () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  Fun.protect
    ~finally:(fun () -> Nopal_http.register_backend Nopal_http.default_backend)
    (fun () ->
      (* Register a custom backend that always succeeds *)
      Nopal_http.register_backend
        {
          Nopal_http.send =
            (fun _request on_result ->
              Nopal_mvu.Cmd.task (fun dispatch ->
                  dispatch
                    (on_result
                       (Ok { Nopal_http.status = 200; body = "custom" }))));
        };
      let cmd =
        Nopal_http.get "https://example.com" (fun outcome -> Got outcome)
      in
      Nopal_mvu.Cmd.execute dispatch cmd;
      match !results with
      | [ Got (Ok { status; body; _ }) ] ->
          Alcotest.(check int) "status from custom backend" 200 status;
          Alcotest.(check string) "body from custom backend" "custom" body
      | _ -> Alcotest.fail "expected exactly one Got (Ok _)")

let test_request_construction () =
  let req : Nopal_http.request =
    {
      meth = Nopal_http.POST;
      url = "https://example.com/api";
      headers = [ ("Content-Type", "application/json") ];
      body = {|{"key":"value"}|};
    }
  in
  Alcotest.(check string) "url" "https://example.com/api" req.url;
  Alcotest.(check string) "body" {|{"key":"value"}|} req.body;
  (match req.meth with
  | Nopal_http.POST -> ()
  | Nopal_http.GET -> Alcotest.fail "expected POST");
  match req.headers with
  | [ ("Content-Type", "application/json") ] -> ()
  | _ -> Alcotest.fail "expected single Content-Type header"

let test_request_get_empty_body () =
  let req : Nopal_http.request =
    {
      meth = Nopal_http.GET;
      url = "https://example.com";
      headers = [];
      body = "";
    }
  in
  (match req.meth with
  | Nopal_http.GET -> ()
  | Nopal_http.POST -> Alcotest.fail "expected GET");
  Alcotest.(check string) "url" "https://example.com" req.url;
  Alcotest.(check (list (pair string string))) "no headers" [] req.headers;
  Alcotest.(check string) "empty body" "" req.body

let test_request_multiple_headers () =
  let headers =
    [
      ("Authorization", "Bearer token123");
      ("Content-Type", "application/json");
      ("X-Custom", "nopal");
    ]
  in
  let req : Nopal_http.request =
    { meth = Nopal_http.POST; url = "https://example.com"; headers; body = "" }
  in
  Alcotest.(check (list (pair string string)))
    "headers preserved in order" headers req.headers

let test_send_returns_cmd () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  let req : Nopal_http.request =
    {
      meth = Nopal_http.POST;
      url = "https://example.com/api";
      headers = [];
      body = "hello";
    }
  in
  let cmd = Nopal_http.send req (fun outcome -> Got outcome) in
  Nopal_mvu.Cmd.execute dispatch cmd;
  match !results with
  | [ Got (Error (Nopal_http.Network_error msg)) ] ->
      Alcotest.(check string)
        "error mentions url" "no HTTP backend: https://example.com/api" msg
  | _ -> Alcotest.fail "expected exactly one Got (Error (Network_error _))"

let test_post_returns_cmd () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  let cmd =
    Nopal_http.post "https://example.com/api" ~body:"test body" (fun outcome ->
        Got outcome)
  in
  Nopal_mvu.Cmd.execute dispatch cmd;
  match !results with
  | [ Got (Error (Nopal_http.Network_error msg)) ] ->
      Alcotest.(check string)
        "error mentions url" "no HTTP backend: https://example.com/api" msg
  | _ -> Alcotest.fail "expected exactly one Got (Error (Network_error _))"

let test_get_backward_compatible () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  let cmd = Nopal_http.get "https://example.com" (fun outcome -> Got outcome) in
  Nopal_mvu.Cmd.execute dispatch cmd;
  match !results with
  | [ Got (Error (Nopal_http.Network_error msg)) ] ->
      Alcotest.(check string)
        "error mentions url" "no HTTP backend: https://example.com" msg
  | _ -> Alcotest.fail "expected exactly one Got (Error (Network_error _))"

let test_get_with_headers () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  let cmd =
    Nopal_http.get
      ~headers:[ ("Authorization", "Bearer x") ]
      "https://example.com"
      (fun outcome -> Got outcome)
  in
  Nopal_mvu.Cmd.execute dispatch cmd;
  match !results with
  | [ Got (Error (Nopal_http.Network_error msg)) ] ->
      Alcotest.(check string)
        "error mentions url" "no HTTP backend: https://example.com" msg
  | _ -> Alcotest.fail "expected exactly one Got (Error (Network_error _))"

let test_register_backend_send () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  Fun.protect
    ~finally:(fun () -> Nopal_http.register_backend Nopal_http.default_backend)
    (fun () ->
      Nopal_http.register_backend
        {
          Nopal_http.send =
            (fun request on_result ->
              Nopal_mvu.Cmd.task (fun dispatch ->
                  dispatch
                    (on_result
                       (Ok
                          {
                            Nopal_http.status = 201;
                            body = "posted:" ^ request.body;
                          }))));
        };
      let req : Nopal_http.request =
        {
          meth = Nopal_http.POST;
          url = "https://example.com/api";
          headers = [ ("Content-Type", "text/plain") ];
          body = "payload";
        }
      in
      let cmd = Nopal_http.send req (fun outcome -> Got outcome) in
      Nopal_mvu.Cmd.execute dispatch cmd;
      match !results with
      | [ Got (Ok { status; body; _ }) ] ->
          Alcotest.(check int) "status from custom backend" 201 status;
          Alcotest.(check string) "body echoes request" "posted:payload" body
      | _ -> Alcotest.fail "expected exactly one Got (Ok _)")

let () =
  Alcotest.run "nopal_http"
    [
      ( "Http",
        [
          Alcotest.test_case "response construction" `Quick
            test_response_construction;
          Alcotest.test_case "error network_error" `Quick
            test_error_network_error;
          Alcotest.test_case "outcome ok" `Quick test_outcome_ok;
          Alcotest.test_case "outcome error" `Quick test_outcome_error;
          Alcotest.test_case "get returns cmd" `Quick test_get_returns_cmd;
          Alcotest.test_case "register_backend overrides get" `Quick
            test_register_backend;
          Alcotest.test_case "request construction" `Quick
            test_request_construction;
          Alcotest.test_case "request get empty body" `Quick
            test_request_get_empty_body;
          Alcotest.test_case "request multiple headers" `Quick
            test_request_multiple_headers;
          Alcotest.test_case "send returns cmd" `Quick test_send_returns_cmd;
          Alcotest.test_case "post returns cmd" `Quick test_post_returns_cmd;
          Alcotest.test_case "get backward compatible" `Quick
            test_get_backward_compatible;
          Alcotest.test_case "get with headers" `Quick test_get_with_headers;
          Alcotest.test_case "register_backend_send" `Quick
            test_register_backend_send;
        ] );
    ]

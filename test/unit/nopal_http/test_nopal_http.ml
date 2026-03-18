type test_msg = Got of Nopal_http.outcome

let test_all_methods_return_cmd_with_default_backend () =
  let test_one label mk_cmd expected_url =
    let results = ref [] in
    let dispatch msg = results := msg :: !results in
    let cmd = mk_cmd (fun outcome -> Got outcome) in
    Nopal_mvu.Cmd.execute dispatch cmd;
    match !results with
    | [ Got (Error (Nopal_http.Network_error msg)) ] ->
        Alcotest.(check string)
          (label ^ " error mentions url")
          ("no HTTP backend: " ^ expected_url)
          msg
    | _ ->
        Alcotest.fail
          (label ^ ": expected exactly one Got (Error (Network_error _))")
  in
  let url = "https://example.com/api" in
  test_one "get" (Nopal_http.get url) url;
  test_one "get ~headers"
    (Nopal_http.get ~headers:[ ("Authorization", "Bearer x") ] url)
    url;
  test_one "post" (Nopal_http.post url ~body:"b") url;
  test_one "put" (Nopal_http.put url ~body:"b") url;
  test_one "delete_" (Nopal_http.delete_ url) url;
  test_one "delete_ ~body" (Nopal_http.delete_ ~body:"b" url) url;
  test_one "patch" (Nopal_http.patch url ~body:"b") url;
  test_one "send"
    (Nopal_http.send
       { meth = Nopal_http.POST; url; headers = []; body = "hello" })
    url

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
                       (Ok
                          {
                            Nopal_http.status = 200;
                            body = "custom";
                            headers = [];
                          }))));
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
                            headers = [];
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
          Alcotest.test_case "all methods return cmd with default backend"
            `Quick test_all_methods_return_cmd_with_default_backend;
          Alcotest.test_case "register_backend overrides get" `Quick
            test_register_backend;
          Alcotest.test_case "register_backend_send" `Quick
            test_register_backend_send;
        ] );
    ]

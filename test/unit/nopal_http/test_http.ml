type test_msg = Got of Nopal_http.outcome

let test_register_backend () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  Fun.protect
    ~finally:(fun () -> Nopal_http.register_backend Nopal_http.default_backend)
    (fun () ->
      Nopal_http.register_backend
        {
          Nopal_http.send =
            (fun _request ->
              Nopal_mvu.Task.return
                (Ok { Nopal_http.status = 200; body = "task-ok"; headers = [] }));
        };
      let req : Nopal_http.request =
        {
          meth = Nopal_http.GET;
          url = "https://example.com/api";
          headers = [];
          body = Nopal_http.Empty;
          timeout = None;
        }
      in
      let cmd = Nopal_http.send req (fun outcome -> Got outcome) in
      Nopal_mvu.Cmd.execute dispatch cmd;
      match !results with
      | [ Got (Ok { status; body; _ }) ] ->
          Alcotest.(check int) "status from task backend" 200 status;
          Alcotest.(check string) "body from task backend" "task-ok" body
      | _ -> Alcotest.fail "expected exactly one Got (Ok _)")

let test_default_backend_dispatches_error () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  let req : Nopal_http.request =
    {
      meth = Nopal_http.GET;
      url = "https://example.com/api";
      headers = [];
      body = Nopal_http.Empty;
      timeout = None;
    }
  in
  let cmd = Nopal_http.send req (fun outcome -> Got outcome) in
  Nopal_mvu.Cmd.execute dispatch cmd;
  match !results with
  | [ Got (Error (Nopal_http.Network_error msg)) ] ->
      Alcotest.(check bool)
        "error mentions url" true
        (Test_util.string_contains msg ~sub:"example.com")
  | _ -> Alcotest.fail "expected exactly one Got (Error (Network_error _))"

let test_http_cancellable_send_maps_cancelled_without_string_match () =
  let req : Nopal_http.request =
    {
      meth = Nopal_http.GET;
      url = "https://example.com/api";
      headers = [];
      body = Nopal_http.Empty;
      timeout = None;
    }
  in
  Fun.protect
    ~finally:(fun () -> Nopal_http.register_backend Nopal_http.default_backend)
    (fun () ->
      (* A genuine backend error whose message happens to be "cancelled" is a
         completed result and must pass through unchanged — not be mistaken for
         a cancellation. *)
      Nopal_http.register_backend
        {
          Nopal_http.send =
            (fun _request ->
              Nopal_mvu.Task.return
                (Error (Nopal_http.Network_error "cancelled")));
        };
      let completed = ref [] in
      let _token, cmd =
        Nopal_http.send_cancellable req (fun outcome -> Got outcome)
      in
      Nopal_mvu.Cmd.execute (fun msg -> completed := msg :: !completed) cmd;
      (match !completed with
      | [ Got (Error (Nopal_http.Network_error "cancelled")) ] -> ()
      | _ ->
          Alcotest.fail
            "genuine Network_error \"cancelled\" must pass through as completed");

      (* A real cancellation of a never-resolving request must deliver
         Network_error "cancelled" exactly once, at cancel time — independent of
         the aborted request ever completing. *)
      Nopal_http.register_backend
        {
          Nopal_http.send =
            (fun _request -> Nopal_mvu.Task.from_callback (fun _resolve -> ()));
        };
      let cancelled = ref [] in
      let token, cmd =
        Nopal_http.send_cancellable req (fun outcome -> Got outcome)
      in
      Nopal_mvu.Cmd.execute (fun msg -> cancelled := msg :: !cancelled) cmd;
      Nopal_mvu.Task.cancel token;
      match !cancelled with
      | [ Got (Error (Nopal_http.Network_error "cancelled")) ] -> ()
      | [] -> Alcotest.fail "cancel delivered no outcome"
      | _ -> Alcotest.fail "cancel must deliver exactly one Network_error")

let () =
  Alcotest.run "nopal_http (task-based)"
    [
      ( "Http",
        [
          Alcotest.test_case "register_backend with Task.return" `Quick
            test_register_backend;
          Alcotest.test_case "default backend dispatches error" `Quick
            test_default_backend_dispatches_error;
          Alcotest.test_case
            "cancellable send maps cancelled without string match" `Quick
            test_http_cancellable_send_maps_cancelled_without_string_match;
        ] );
    ]

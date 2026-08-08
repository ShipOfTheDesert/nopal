type test_msg = Got of Nopal_http.outcome

let test_all_methods_return_cmd_with_default_backend () =
  let test_one label mk_cmd =
    let results = ref [] in
    let dispatch msg = results := msg :: !results in
    let cmd = mk_cmd (fun outcome -> Got outcome) in
    Nopal_mvu.Cmd.execute dispatch cmd;
    match !results with
    | [ Got (Error (Nopal_http.Network_error _)) ] -> ()
    | _ -> Alcotest.fail (label ^ " expected Network_error")
  in
  let url = "https://example.com/api" in
  test_one "get" (Nopal_http.get url);
  test_one "get ~headers"
    (Nopal_http.get ~headers:[ ("Authorization", "Bearer x") ] url);
  test_one "post"
    (Nopal_http.post
       ~body:(Nopal_http.String { content = "b"; content_type = None })
       url);
  test_one "put"
    (Nopal_http.put
       ~body:(Nopal_http.String { content = "b"; content_type = None })
       url);
  test_one "delete_" (Nopal_http.delete_ url);
  test_one "delete_ ~body"
    (Nopal_http.delete_
       ~body:(Nopal_http.String { content = "b"; content_type = None })
       url);
  test_one "patch"
    (Nopal_http.patch
       ~body:(Nopal_http.String { content = "b"; content_type = None })
       url);
  test_one "send"
    (Nopal_http.send
       {
         meth = Nopal_http.POST;
         url;
         headers = [];
         body = Nopal_http.String { content = "hello"; content_type = None };
         timeout = None;
       })

let test_register_backend () =
  let results = ref [] in
  let dispatch msg = results := msg :: !results in
  Fun.protect
    ~finally:(fun () -> Nopal_http.register_backend Nopal_http.default_backend)
    (fun () ->
      Nopal_http.register_backend
        {
          Nopal_http.send =
            (fun request ->
              let body_str =
                match request.body with
                | Nopal_http.String { content; _ } -> content
                | _ -> ""
              in
              Nopal_mvu.Task.return
                (Ok
                   {
                     Nopal_http.status = 201;
                     body = "echoed:" ^ body_str;
                     headers = [];
                   }));
        };
      let req : Nopal_http.request =
        {
          meth = Nopal_http.POST;
          url = "https://example.com/api";
          headers = [ ("Content-Type", "text/plain") ];
          body = Nopal_http.String { content = "payload"; content_type = None };
          timeout = None;
        }
      in
      let cmd = Nopal_http.send req (fun outcome -> Got outcome) in
      Nopal_mvu.Cmd.execute dispatch cmd;
      match !results with
      | [ Got (Ok { status; body; _ }) ] ->
          Alcotest.(check int) "status from custom backend" 201 status;
          Alcotest.(check string) "body echoes request" "echoed:payload" body
      | _ -> Alcotest.fail "expected exactly one Got (Ok _)")

(* Posts [body] through a stub backend that captures the request body verbatim,
   then restores the default backend. Returns the captured body. *)
let capture_posted_body body =
  let captured = ref None in
  Fun.protect
    ~finally:(fun () -> Nopal_http.register_backend Nopal_http.default_backend)
    (fun () ->
      Nopal_http.register_backend
        {
          Nopal_http.send =
            (fun request ->
              captured := Some request.Nopal_http.body;
              Nopal_mvu.Task.return
                (Ok { Nopal_http.status = 200; body = ""; headers = [] }));
        };
      let cmd =
        Nopal_http.post ~body "https://example.com/upload" (fun outcome ->
            Got outcome)
      in
      Nopal_mvu.Cmd.execute (fun _msg -> ()) cmd);
  !captured

let test_multipart_mixed_parts () =
  let captured =
    capture_posted_body
      (Nopal_http.Multipart
         [
           Nopal_http.Field ("caption", "grocery run");
           Nopal_http.File
             {
               name = "receipt";
               blob_id = "blob-7";
               filename = Some "scan.png";
               mime = Some "image/png";
             };
         ])
  in
  match captured with
  | Some
      (Nopal_http.Multipart
         [
           Nopal_http.Field (field_name, field_value);
           Nopal_http.File { name; blob_id; filename; mime };
         ]) ->
      Alcotest.(check string) "field name" "caption" field_name;
      Alcotest.(check string) "field value" "grocery run" field_value;
      Alcotest.(check string) "file part name" "receipt" name;
      Alcotest.(check string) "file part blob_id" "blob-7" blob_id;
      Alcotest.(check (option string))
        "file part filename" (Some "scan.png") filename;
      Alcotest.(check (option string)) "file part mime" (Some "image/png") mime
  (* Enumerated rather than caught by [Some _]: a sixth body variant should
     break this file, the way it breaks every non-test match on [body]. *)
  | Some (Nopal_http.Multipart _)
  | Some (Nopal_http.String _)
  | Some (Nopal_http.Json _)
  | Some (Nopal_http.Form_encoded _)
  | Some Nopal_http.Empty
  | None ->
      Alcotest.fail "expected a Multipart body of [ Field _; File _ ] in order"

(* Deliberately not tested here: the four filename/mime override combinations.
   Reading them back out of a body a stub backend captured verbatim asserts only
   that a record survives being placed in a variant — it cannot fail unless
   [post] mangles its [~body]. The behaviour the overrides actually have lives
   in the web backend, where [test_nopal_http_web.ml] pins each combination
   against a separate stored blob. *)

let test_message_all_error_arms () =
  let network =
    Nopal_http.message (Nopal_http.Network_error "connection refused")
  in
  let timeout = Nopal_http.message Nopal_http.Timeout in
  let invalid_blob = Nopal_http.message (Nopal_http.Invalid_blob "blob-42") in
  List.iter
    (fun (label, m) ->
      Alcotest.(check bool) (label ^ " is non-empty") true (String.length m > 0))
    [
      ("Network_error", network);
      ("Timeout", timeout);
      ("Invalid_blob", invalid_blob);
    ];
  Alcotest.(check int)
    "every arm has a distinct message" 3
    (Test_util.count_unique String.equal [ network; timeout; invalid_blob ]);
  Alcotest.(check bool)
    "Network_error message carries its detail" true
    (Test_util.string_contains network ~sub:"connection refused");
  Alcotest.(check bool)
    "Invalid_blob message names the offending handle" true
    (Test_util.string_contains invalid_blob ~sub:"blob-42")

let () =
  Alcotest.run "nopal_http"
    [
      ( "Http",
        [
          Alcotest.test_case "all methods return cmd with default backend"
            `Quick test_all_methods_return_cmd_with_default_backend;
          Alcotest.test_case "register_backend echoes request body" `Quick
            test_register_backend;
          Alcotest.test_case "multipart body carries mixed field and file parts"
            `Quick test_multipart_mixed_parts;
          Alcotest.test_case "message describes every error arm" `Quick
            test_message_all_error_arms;
        ] );
    ]

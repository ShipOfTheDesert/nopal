type test_msg = Got of Nopal_http.outcome | Mapped of string

(* Defers [k] until after all microtasks have flushed via setTimeout(0).
   Brr_io.Fetch wraps browser fetch in Promise.then() chains. Even with
   a synchronously-resolving fetch shim, .then() callbacks are microtasks
   that run after the current synchronous code completes. A single
   setTimeout(0) fires after the entire microtask queue drains, so all
   Task resolve callbacks will have run by the time [k] executes. *)
let flush_then_run k =
  let flush = Jv.get Jv.global "_flush" in
  ignore (Jv.apply flush [| Jv.callback ~arity:1 (fun _ -> k ()) |])

(* Multipart file parts name their bytes by a blob-store handle, so the cases
   below seed the store with real browser objects — Node supplies the [Blob] and
   [File] globals [Brr.Blob] is built on.

   Every fixture holds the same 13 bytes, which is what the fetch shim echoes
   back as the appended value's [size]. A stringified value would report no size
   at all, so the assertion distinguishes "the Blob reached FormData" from "some
   description of it did". *)
let fixture_text = "receipt bytes"

let store_blob ~mime =
  Nopal_blob_web.Blob_store.store
    (Brr.Blob.of_jstr
       ~init:(Brr.Blob.init ~type':(Jstr.of_string mime) ())
       (Jstr.of_string fixture_text))

(* [Brr] exposes no [File] constructor, and a [File] is what the picker actually
   registers: a [Blob] that additionally carries its own [name]. Built through
   raw [Jv] so the "no filename override" cases can assert that the name the
   blob itself reports is the one the server sees. *)
let store_file ~name ~mime =
  let file =
    Jv.new' (Jv.get Jv.global "File")
      [|
        Jv.of_array Jv.of_jstr [| Jstr.of_string fixture_text |];
        Jv.of_jstr (Jstr.of_string name);
        Jv.obj [| ("type", Jv.of_jstr (Jstr.of_string mime)) |];
      |]
  in
  Nopal_blob_web.Blob_store.store (Brr.Blob.of_jv file)

(* The shim counts every fetch call. Reading it either side of a [Task.run] is
   what separates "resolved before issuing a request" from "issued a request and
   then failed" — the outcome alone cannot tell those apart. *)
let fetch_count () = Jv.Int.get Jv.global "_fetchCount"

let () =
  (* Execute all async tasks now — resolves happen during microtask flush *)
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
  let results_multipart_file = ref [] in
  let results_multipart_overrides = ref [] in
  let results_multipart_dangling = ref [] in
  let results_cancellable_dangling = ref [] in
  let fetches_around_file_part = ref (0, 0) in
  let fetches_around_dangling = ref (0, 0) in
  let fetches_around_cancellable_dangling = ref (0, 0) in
  let results_timeout = ref [] in
  Nopal_mvu.Task.run (Nopal_http_web.get "https://example.com/success")
    (fun outcome -> results_get_success := Got outcome :: !results_get_success);
  Nopal_mvu.Task.run (Nopal_http_web.get "https://example.com/404")
    (fun outcome -> results_404 := Got outcome :: !results_404);
  Nopal_mvu.Task.run (Nopal_http_web.get "https://example.com/network-error")
    (fun outcome -> results_network := Got outcome :: !results_network);
  Nopal_mvu.Task.run (Nopal_http_web.get "https://example.com/body-error")
    (fun outcome -> results_body_error := Got outcome :: !results_body_error);
  Nopal_mvu.Task.run
    (Nopal_mvu.Task.map
       (fun outcome ->
         match outcome with
         | Ok resp -> Mapped ("status:" ^ string_of_int resp.Nopal_http.status)
         | Error _ -> Mapped "error")
       (Nopal_http_web.get "https://example.com/success"))
    (fun msg -> results_mapped := msg :: !results_mapped);
  Nopal_mvu.Task.run
    (Nopal_http_web.post
       ~headers:[ ("Content-Type", "application/json") ]
       ~body:
         (Nopal_http.String { content = "test-payload"; content_type = None })
       "https://example.com/success")
    (fun outcome -> results_post := Got outcome :: !results_post);
  Nopal_mvu.Task.run
    (Nopal_http_web.post
       ~body:(Nopal_http.String { content = "hello"; content_type = None })
       "https://example.com/network-error")
    (fun outcome ->
      results_post_network := Got outcome :: !results_post_network);
  Nopal_mvu.Task.run
    (Nopal_http_web.get
       ~headers:[ ("Authorization", "Bearer token123") ]
       "https://example.com/success")
    (fun outcome -> results_get_headers := Got outcome :: !results_get_headers);
  Nopal_mvu.Task.run
    (Nopal_http_web.put
       ~body:
         (Nopal_http.String { content = "put-payload"; content_type = None })
       "https://example.com/success")
    (fun outcome -> results_put := Got outcome :: !results_put);
  Nopal_mvu.Task.run (Nopal_http_web.delete_ "https://example.com/success")
    (fun outcome -> results_delete := Got outcome :: !results_delete);
  Nopal_mvu.Task.run
    (Nopal_http_web.patch
       ~body:(Nopal_http.String { content = "patch-data"; content_type = None })
       "https://example.com/success")
    (fun outcome -> results_patch := Got outcome :: !results_patch);
  Nopal_mvu.Task.run
    (Nopal_http_web.delete_
       ~body:
         (Nopal_http.String { content = "delete-payload"; content_type = None })
       "https://example.com/success")
    (fun outcome -> results_delete_body := Got outcome :: !results_delete_body);
  Nopal_mvu.Task.run
    (Nopal_http_web.post
       ~body:
         (Nopal_http.Form_encoded
            [ ("a&b", "c=d"); ("space key", "val ue"); ("utf8", "\xc3\xa9") ])
       "https://example.com/success")
    (fun outcome ->
      results_form_encoded := Got outcome :: !results_form_encoded);
  Nopal_mvu.Task.run
    (Nopal_http_web.post
       ~body:
         (Nopal_http.Multipart
            [
              Nopal_http.Field ("name", "nopal");
              Nopal_http.Field ("version", "1");
            ])
       "https://example.com/success")
    (fun outcome -> results_multipart := Got outcome :: !results_multipart);
  let receipt_handle = store_blob ~mime:"image/png" in
  let fetches_before_file_part = fetch_count () in
  Nopal_mvu.Task.run
    (Nopal_http_web.post
       ~body:
         (Nopal_http.Multipart
            [
              Nopal_http.Field ("caption", "lunch");
              Nopal_http.File
                {
                  name = "receipt";
                  blob_id = receipt_handle;
                  filename = None;
                  mime = None;
                };
            ])
       "https://example.com/success")
    (fun outcome ->
      results_multipart_file := Got outcome :: !results_multipart_file);
  fetches_around_file_part := (fetches_before_file_part, fetch_count ());
  (* Three entries from three separate store entries, so no case can pass by
     observing another's blob: overrides on both axes, neither axis, and mime
     alone — the last is what proves the two overrides are independent, since
     re-typing a blob is what would otherwise discard the name it reports. *)
  let overridden_handle = store_file ~name:"receipt.png" ~mime:"image/png" in
  let deferred_handle = store_file ~name:"receipt.png" ~mime:"image/png" in
  let retyped_handle = store_file ~name:"receipt.png" ~mime:"image/png" in
  Nopal_mvu.Task.run
    (Nopal_http_web.post
       ~body:
         (Nopal_http.Multipart
            [
              Nopal_http.File
                {
                  name = "overridden";
                  blob_id = overridden_handle;
                  filename = Some "invoice.pdf";
                  mime = Some "application/pdf";
                };
              Nopal_http.File
                {
                  name = "deferred";
                  blob_id = deferred_handle;
                  filename = None;
                  mime = None;
                };
              Nopal_http.File
                {
                  name = "retyped";
                  blob_id = retyped_handle;
                  filename = None;
                  mime = Some "image/webp";
                };
            ])
       "https://example.com/success")
    (fun outcome ->
      results_multipart_overrides := Got outcome :: !results_multipart_overrides);
  (* Never issued by the store — [Blob_store.store] mints handles behind a
     random per-session prefix, so a hand-written literal cannot collide with a
     live entry. Paired with a [Field] so the assertion also covers atomicity:
     the resolvable part must not be sent on its own. *)
  let fabricated_handle = "nopal-blob-fabricated-0" in
  let fetches_before_dangling = fetch_count () in
  Nopal_mvu.Task.run
    (Nopal_http_web.post
       ~body:
         (Nopal_http.Multipart
            [
              Nopal_http.Field ("caption", "lunch");
              Nopal_http.File
                {
                  name = "receipt";
                  blob_id = fabricated_handle;
                  filename = None;
                  mime = None;
                };
            ])
       "https://example.com/success")
    (fun outcome ->
      results_multipart_dangling := Got outcome :: !results_multipart_dangling);
  fetches_around_dangling := (fetches_before_dangling, fetch_count ());
  (* [send_cancellable] carries its own copy of the body-preparation
     short-circuit, and its .mli promises the same [Invalid_blob] behaviour as
     {!send}. Sharing a pattern with a tested sibling is not coverage: an
     implementation that issued the fetch anyway, or that collapsed the failure
     into [Network_error], would pass every other case in this file. *)
  let cancellable_fabricated_handle = "nopal-blob-fabricated-1" in
  let fetches_before_cancellable_dangling = fetch_count () in
  let _cancellable_dangling_token, cancellable_dangling_task =
    Nopal_http_web.send_cancellable
      {
        Nopal_http.meth = POST;
        url = "https://example.com/success";
        headers = [];
        body =
          Nopal_http.Multipart
            [
              Nopal_http.Field ("caption", "lunch");
              Nopal_http.File
                {
                  name = "receipt";
                  blob_id = cancellable_fabricated_handle;
                  filename = None;
                  mime = None;
                };
            ];
        timeout = None;
      }
  in
  Nopal_mvu.Task.run cancellable_dangling_task (fun outcome ->
      results_cancellable_dangling :=
        Got outcome :: !results_cancellable_dangling);
  fetches_around_cancellable_dangling :=
    (fetches_before_cancellable_dangling, fetch_count ());
  Nopal_mvu.Task.run
    (Nopal_http_web.get ~timeout:0.01 "https://example.com/delay")
    (fun outcome -> results_timeout := Got outcome :: !results_timeout);
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
              Alcotest.test_case "multipart file part sends the stored blob"
                `Quick (fun () ->
                  match !results_multipart_file with
                  | [ Got (Ok resp) ] ->
                      let body = resp.Nopal_http.body in
                      Alcotest.(check bool)
                        "the string field is sent alongside the file" true
                        (Test_util.string_contains body ~sub:"caption"
                        && Test_util.string_contains body ~sub:"lunch");
                      (* Size and type can only come from the Blob itself; a
                         value stringified on the way into FormData would carry
                         neither. That is what pins the blob being handed to
                         FormData directly, rather than its bytes being read
                         into OCaml first. *)
                      (* [filename=blob] is what the shim records for a
                         two-argument [append], and it is the platform's own
                         default name for an omitted filename. A regression to
                         an unconditional three-argument call carrying an absent
                         filename would read [filename=undefined] here, which is
                         the literal string real FormData would put on the
                         wire. *)
                      Alcotest.(check bool)
                        "the appended value is the stored blob, named by the \
                         platform default"
                        true
                        (Test_util.string_contains body
                           ~sub:"<blob size=13 type=image/png filename=blob>");
                      Alcotest.(check bool)
                        "no filename was stated for it" false
                        (Test_util.string_contains body
                           ~sub:"filename=undefined");
                      Alcotest.(check bool)
                        "the appended value is not a stringified object" false
                        (Test_util.string_contains body ~sub:"[object");
                      let before, after = !fetches_around_file_part in
                      Alcotest.(check int)
                        "a resolvable multipart body issues its request"
                        (before + 1) after
                  | _ ->
                      Alcotest.fail
                        "expected exactly one Got (Ok _) for the multipart \
                         file part test");
              Alcotest.test_case
                "multipart file part applies filename and mime overrides" `Quick
                (fun () ->
                  match !results_multipart_overrides with
                  | [ Got (Ok resp) ] ->
                      let body = resp.Nopal_http.body in
                      Alcotest.(check bool)
                        "both overrides reach the appended entry" true
                        (Test_util.string_contains body
                           ~sub:
                             "<blob size=13 type=application/pdf \
                              filename=invoice.pdf>");
                      Alcotest.(check bool)
                        "no override defers to the blob's own type and name"
                        true
                        (Test_util.string_contains body
                           ~sub:
                             "<blob size=13 type=image/png \
                              filename=receipt.png>");
                      Alcotest.(check bool)
                        "a mime override alone leaves the blob's own name \
                         intact"
                        true
                        (Test_util.string_contains body
                           ~sub:
                             "<blob size=13 type=image/webp \
                              filename=receipt.png>")
                  | _ ->
                      Alcotest.fail
                        "expected exactly one Got (Ok _) for the multipart \
                         override test");
              Alcotest.test_case
                "multipart with unknown handle fails with Invalid_blob" `Quick
                (fun () ->
                  match !results_multipart_dangling with
                  | [ Got (Error (Nopal_http.Invalid_blob handle)) ] ->
                      Alcotest.(check string)
                        "the error names the unresolvable handle"
                        "nopal-blob-fabricated-0" handle;
                      let before, after = !fetches_around_dangling in
                      Alcotest.(check int)
                        "nothing was sent — not even the resolvable part" before
                        after
                  | [ Got (Error (Nopal_http.Network_error msg)) ] ->
                      Alcotest.fail
                        ("expected Invalid_blob but got Network_error: " ^ msg)
                  | [ Got (Error Nopal_http.Timeout) ] ->
                      Alcotest.fail "expected Invalid_blob but got Timeout"
                  | [ Got (Ok _) ] ->
                      Alcotest.fail
                        "expected Invalid_blob but the request was sent anyway"
                  | _ ->
                      Alcotest.fail
                        "expected exactly one Got (Error (Invalid_blob _))");
              Alcotest.test_case
                "send_cancellable with unknown handle fails with Invalid_blob"
                `Quick (fun () ->
                  match !results_cancellable_dangling with
                  | [ Got (Error (Nopal_http.Invalid_blob handle)) ] ->
                      Alcotest.(check string)
                        "the error names the unresolvable handle"
                        "nopal-blob-fabricated-1" handle;
                      let before, after =
                        !fetches_around_cancellable_dangling
                      in
                      Alcotest.(check int)
                        "nothing was sent — not even the resolvable part" before
                        after
                  | [ Got (Error (Nopal_http.Network_error msg)) ] ->
                      Alcotest.fail
                        ("expected Invalid_blob but got Network_error: " ^ msg)
                  | [ Got (Error Nopal_http.Timeout) ] ->
                      Alcotest.fail "expected Invalid_blob but got Timeout"
                  | [ Got (Ok _) ] ->
                      Alcotest.fail
                        "expected Invalid_blob but the request was sent anyway"
                  | _ ->
                      Alcotest.fail
                        "expected exactly one Got (Error (Invalid_blob _))");
              (* The boundary the platform generates depends on this header being
                 absent: a hand-written [Content-Type] would carry a boundary
                 that does not match the encoded body. The one line that holds it
                 ([content_type_from_body]'s [Multipart] arm) is otherwise
                 guarded only by the browser E2E. *)
              Alcotest.test_case "multipart sends no explicit Content-Type"
                `Quick (fun () ->
                  match (!results_multipart, !results_post) with
                  | [ Got (Ok multipart) ], [ Got (Ok with_header) ] ->
                      (* The shim echoes the request's headers as a JSON object.
                         The affirmative arm is the sibling POST, which does set
                         one — without it, an assertion that no header was
                         echoed would also pass if the shim echoed no headers at
                         all. *)
                      Alcotest.(check bool)
                        "a request that sets Content-Type echoes it" true
                        (Test_util.string_contains with_header.Nopal_http.body
                           ~sub:"content-type");
                      Alcotest.(check bool)
                        "the multipart request sent no headers at all" true
                        (Test_util.string_contains multipart.Nopal_http.body
                           ~sub:"\"headers\":{}");
                      Alcotest.(check bool)
                        "the multipart request sent no Content-Type" false
                        (Test_util.string_contains multipart.Nopal_http.body
                           ~sub:"content-type")
                  | _ ->
                      Alcotest.fail
                        "expected one Got (Ok _) for both the multipart and \
                         the Content-Type-setting POST");
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

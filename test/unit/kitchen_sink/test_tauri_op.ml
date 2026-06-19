(* RFC 0118 REQ-F5: the Tauri-op result-task chaining ([Kitchen_sink_app.Tauri_op],
   instantiated as [Op] in main.ml) must (a) thread the happy path through to the
   final message and (b) route the FIRST [Error] to [TauriOpError] — never hang
   the chain and never silently drop a failed op. These tests pin that routing
   directly, the seam the structural/E2E section tests only exercise indirectly. *)

(* A native-clean platform instantiating the kitchen sink functor: navigation is
   stubbed and storage is in-memory. The Tauri_op functor needs only the [msg]
   type and its [TauriOpError] constructor — no browser surface. *)
module Test_platform : Nopal_platform.Platform.S = struct
  let current_path () = "/"
  let push_state (_ : string) = ()
  let replace_state (_ : string) = ()
  let back () = ()
  let on_popstate (_ : string -> unit) () = ()

  module Store = Nopal_storage.In_memory ()

  let storage = (module Store : Nopal_storage.S)
end

module K = Kitchen_sink_app.Make (Test_platform)
open K

module Op = Kitchen_sink_app.Tauri_op.Make (struct
  type msg = K.msg

  let tauri_op_error e = TauriOpError e
end)

(* [Task.return] resolves synchronously, so [run] hands the message back inline. *)
let run_to_msg task =
  let captured = ref None in
  Nopal_mvu.Task.run task (fun m -> captured := Some m);
  match !captured with
  | Some m -> m
  | None -> Alcotest.fail "task did not resolve"

let ok v = Nopal_mvu.Task.return (Ok v)
let err e = Nopal_mvu.Task.return (Error e)

(* [let+] on [Ok v] applies the success map. *)
let test_map_ok_applies_success () =
  let msg =
    run_to_msg
      (let open Op in
       let+ s = ok "appname" in
       GotAppName s)
  in
  match msg with
  | GotAppName s -> Alcotest.(check string) "mapped value" "appname" s
  | _ -> Alcotest.fail "expected GotAppName"

(* [let+] on [Error e] routes to [TauriOpError e] instead of the success map. *)
let test_map_error_routes_to_tauri_op_error () =
  let msg =
    run_to_msg
      (let open Op in
       let+ s = err "boom" in
       GotAppName s)
  in
  match msg with
  | TauriOpError e -> Alcotest.(check string) "error string" "boom" e
  | _ -> Alcotest.fail "expected TauriOpError"

(* [let*] threads the happy path through every step to the final message. *)
let test_bind_ok_threads_chain () =
  let msg =
    run_to_msg
      (let open Op in
       let* () = ok () in
       let+ s = ok "v" in
       GotAppVersion s)
  in
  match msg with
  | GotAppVersion s -> Alcotest.(check string) "final value" "v" s
  | _ -> Alcotest.fail "expected GotAppVersion"

(* [let*] short-circuits on the first [Error]: the continuation never runs. *)
let test_bind_error_short_circuits () =
  let continued = ref false in
  let msg =
    run_to_msg
      (let open Op in
       let* () = err "first" in
       continued := true;
       let+ s = ok "v" in
       GotAppVersion s)
  in
  Alcotest.(check bool) "continuation skipped" false !continued;
  match msg with
  | TauriOpError e -> Alcotest.(check string) "first error" "first" e
  | _ -> Alcotest.fail "expected TauriOpError"

(* When two steps could fail, the FIRST error is the one surfaced. *)
let test_bind_first_error_wins () =
  let msg =
    run_to_msg
      (let open Op in
       let* () = err "one" in
       let+ () = err "two" in
       TauriEventEmitted)
  in
  match msg with
  | TauriOpError e -> Alcotest.(check string) "first error wins" "one" e
  | _ -> Alcotest.fail "expected TauriOpError"

let () =
  Alcotest.run "tauri_op"
    [
      ( "result-routing",
        [
          Alcotest.test_case "let+ Ok applies success map" `Quick
            test_map_ok_applies_success;
          Alcotest.test_case "let+ Error -> TauriOpError" `Quick
            test_map_error_routes_to_tauri_op_error;
          Alcotest.test_case "let* Ok threads chain" `Quick
            test_bind_ok_threads_chain;
          Alcotest.test_case "let* Error short-circuits" `Quick
            test_bind_error_short_circuits;
          Alcotest.test_case "let* first error wins" `Quick
            test_bind_first_error_wins;
        ] );
    ]

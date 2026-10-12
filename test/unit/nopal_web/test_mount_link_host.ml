(* Which link host a mount selects, and the mount that refuses to run.

   A page inside a Tauri webview defines [__TAURI_INTERNALS__]. Mounted there
   with no opener, an External link would navigate the webview away from the
   app, so both entry points refuse: the app's [view] never runs, the target
   holds the fault, and [on_error] receives the same text. The same page with
   an opener supplied mounts, and a click on its External link reaches that
   opener, which only a webview host does.

   Each case defines the global before mounting and deletes it afterwards, so
   no other case sees a Tauri runtime. *)

open Nopal_element

let url_text = "https://nopal-test-7Q2.example/"

let fault =
  "nopal_web refused to mount: this page runs in a Tauri webview and the mount \
   was given no ~open_external, so a link would navigate the webview away from \
   the app. Mount through Nopal_tauri_mount, which supplies one."

type msg = Open_failed of Link.open_error

let url =
  match Url.of_string url_text with
  | Ok url -> url
  | Error
      (Url.Missing_scheme _ | Url.Unsupported_scheme _ | Url.Control_character _)
    ->
      Alcotest.fail "fixture URL is refused"

module type PROBE = sig
  val view_calls : int ref
end

module Make_app (P : PROBE) = struct
  type model = unit
  type nonrec msg = msg

  let init () = ((), Nopal_mvu.Cmd.none)
  let update () (_ : msg) = ((), Nopal_mvu.Cmd.none)

  let view _vp () =
    incr P.view_calls;
    Element.link
      (Link.External { url; on_open_failed = (fun error -> Open_failed error) })
      (Element.text "Docs")

  let subscriptions () = Nopal_mvu.Sub.none
end

type entry = Mount | Mount_with_telemetry

let show_entry = function
  | Mount -> "mount"
  | Mount_with_telemetry -> "mount_with_telemetry"

(* What one mount showed: how often [view] ran, the target's text, what
   [on_error] received, and the anchor the target holds, if any. *)
type outcome = {
  view_calls : int;
  target_text : string;
  errors : string list;
  first_child : Jv.t;
  logged : int option;  (** the returned handle's log; [None] for [mount] *)
  unmount_is_safe : bool;
}

let with_tauri_runtime f =
  Jv.set Jv.global "__TAURI_INTERNALS__" (Jv.obj [||]);
  Fun.protect ~finally:(fun () -> Jv.delete Jv.global "__TAURI_INTERNALS__") f

let bridge () = Jv.get (Jv.get Jv.global "window") "__nopal_telemetry__"

let clear_bridge () =
  Jv.delete (Jv.get Jv.global "window") "__nopal_telemetry__"

let mount_app ?open_external entry =
  let module P = struct
    (* mutable: a mounted app's [view] is observable only through this count. *)
    let view_calls = ref 0
  end in
  let module A = Make_app (P) in
  (* mutable: the mount reports each fault only through this callback. *)
  let errors = ref [] in
  let on_error text = errors := !errors @ [ text ] in
  let target = Brr.El.v (Jstr.v "div") [] in
  let logged, unmount =
    match entry with
    | Mount ->
        let m =
          (Nopal_web.mount ~on_error ?open_external (module A) target
            : Nopal_web.mounted)
        in
        (None, m.unmount)
    | Mount_with_telemetry ->
        let m =
          (Nopal_web.mount_with_telemetry ~on_error ?open_external
             (module A)
             target
            : Nopal_web.mounted_with_telemetry)
        in
        ( Some (List.length (Nopal_runtime.Telemetry.events m.telemetry)),
          m.unmount )
  in
  let unmount_is_safe =
    match unmount () with
    | () -> true
    | exception _ -> false
  in
  let target_jv = Brr.El.to_jv target in
  {
    view_calls = !P.view_calls;
    target_text = Jv.to_string (Jv.get target_jv "textContent");
    errors = !errors;
    first_child = Jv.get target_jv "firstChild";
    logged;
    unmount_is_safe;
  }

let click anchor =
  let ev =
    Jv.new'
      (Jv.get Jv.global "MouseEvent")
      [| Jv.of_string "click"; Jv.obj [| ("cancelable", Jv.true') |] |]
  in
  Jv.to_bool (Jv.call anchor "dispatchEvent" [| ev |])

let tag node =
  match Jv.is_null node with
  | true -> "<none>"
  | false -> String.lowercase_ascii (Jv.to_string (Jv.get node "nodeName"))

let test_mount_refuses_tauri_runtime_without_opener () =
  List.iter
    (fun entry ->
      let label what = show_entry entry ^ ": " ^ what in
      clear_bridge ();
      let refused = with_tauri_runtime (fun () -> mount_app entry) in
      Alcotest.(check bool)
        (label "no telemetry bridge is installed")
        true
        (Jv.is_undefined (bridge ()));
      Alcotest.(check bool)
        (label "unmount is a safe no-op")
        true refused.unmount_is_safe;
      (match (entry, refused.logged) with
      | Mount, None -> ()
      | Mount_with_telemetry, Some n ->
          Alcotest.(check int) (label "the handle records nothing") 0 n
      | _ -> Alcotest.fail "unexpected handle shape");
      Alcotest.(check int) (label "view is never called") 0 refused.view_calls;
      Alcotest.(check string)
        (label "the target holds the fault")
        fault refused.target_text;
      Alcotest.(check (list string))
        (label "on_error receives the fault")
        [ fault ] refused.errors;
      (* mutable: the opener reports each call only through this callback. *)
      let opened = ref [] in
      let open_external url _resolve =
        opened := !opened @ [ Url.to_string url ]
      in
      let mounted =
        with_tauri_runtime (fun () -> mount_app ~open_external entry)
      in
      Alcotest.(check bool)
        (label "with an opener, view runs")
        true (mounted.view_calls > 0);
      Alcotest.(check (list string))
        (label "with an opener, nothing is reported")
        [] mounted.errors;
      Alcotest.(check string)
        (label "with an opener, the target holds the link")
        "a" (tag mounted.first_child);
      Alcotest.(check bool)
        (label "the click is cancelled, so the webview does not navigate")
        false
        (click mounted.first_child);
      Alcotest.(check (list string))
        (label "a click on the External link reaches the opener")
        [ url_text ] !opened)
    [ Mount; Mount_with_telemetry ]

let () =
  Alcotest.run "nopal_web mount link host"
    [
      ( "mount",
        [
          Alcotest.test_case "mount_refuses_tauri_runtime_without_opener" `Quick
            test_mount_refuses_tauri_runtime_without_opener;
        ] );
    ]

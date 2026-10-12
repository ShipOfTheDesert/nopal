(* [Nopal_tauri_mount]'s two entry points on a page inside a Tauri webview.

   [tauri_shim.js] defines [__TAURI_INTERNALS__] for the whole process, so a
   mount that supplies no opener is refused here. Each case mounts an app whose
   view is one External link and one button that asks for a clipboard write,
   then shows that the app mounted, that a click on the link reaches the opener
   plugin, and that the write reaches the clipboard plugin. The shim records
   every plugin invoke and parks its settlement until the case flushes it.

   Each case mounts with an id namespace of its own, because the DOM shim's
   element registry is never pruned. *)

open Nopal_element

let url_text = "https://nopal-test-7Q2.example/"
let copied_text = "nopal-test-copy-7Q2"

type msg =
  | Open_failed of Link.open_error
  | Copy
  | Copied of (unit, Nopal_mvu.Clipboard.error) result

let show_open_error = function
  | Link.Not_permitted -> "Not_permitted"
  | Link.Failed reason -> Printf.sprintf "Failed %S" reason

let show_clipboard_error = function
  | Nopal_mvu.Clipboard.Not_permitted -> "Not_permitted"
  | Nopal_mvu.Clipboard.Unavailable -> "Unavailable"
  | Nopal_mvu.Clipboard.Failed reason -> Printf.sprintf "Failed %S" reason

let show_msg = function
  | Open_failed error -> "Open_failed (" ^ show_open_error error ^ ")"
  | Copy -> "Copy"
  | Copied (Ok ()) -> "Copied (Ok ())"
  | Copied (Error error) -> "Copied (Error " ^ show_clipboard_error error ^ ")"

let msg =
  Alcotest.testable (fun fmt m -> Format.pp_print_string fmt (show_msg m)) ( = )

let url =
  match Url.of_string url_text with
  | Ok url -> url
  | Error
      (Url.Missing_scheme _ | Url.Unsupported_scheme _ | Url.Control_character _)
    ->
      Alcotest.fail "fixture URL is refused"

module type IDS = sig
  val prefix : string
end

module Make_app (I : IDS) = struct
  let link_id = I.prefix ^ "-link"
  let copy_id = I.prefix ^ "-copy"

  (* mutable: a mounted app's [view] is observable only through this count. *)
  let view_calls = ref 0

  (* mutable: a mounted runtime's model cannot be read from outside the mount,
     so the app appends every message it receives here for the case to read. *)
  let received : msg list ref = ref []

  type model = unit
  type nonrec msg = msg

  let init () = ((), Nopal_mvu.Cmd.none)

  let update () m =
    received := !received @ [ m ];
    match m with
    | Copy ->
        ( (),
          Nopal_mvu.Cmd.write_clipboard copied_text ~on_result:(fun r ->
              Copied r) )
    | Open_failed _
    | Copied _ ->
        ((), Nopal_mvu.Cmd.none)

  let view _vp () =
    incr view_calls;
    Element.column
      [
        Element.link
          ~attrs:[ ("id", link_id) ]
          (Link.External
             { url; on_open_failed = (fun error -> Open_failed error) })
          (Element.text "Docs");
        Element.button
          ~attrs:[ ("id", copy_id) ]
          ~button_type:Element.Push ~disabled:false ~on_click:Copy
          (Element.text "copy");
      ]

  let subscriptions () = Nopal_mvu.Sub.none
end

type entry = Mount | Mount_with_telemetry

let show_entry = function
  | Mount -> "mount"
  | Mount_with_telemetry -> "mount_with_telemetry"

let by_id id =
  Jv.call (Jv.get Jv.global "document") "getElementById" [| Jv.of_string id |]

let click id =
  let ev =
    Jv.new'
      (Jv.get Jv.global "MouseEvent")
      [| Jv.of_string "click"; Jv.obj [| ("cancelable", Jv.true') |] |]
  in
  Jv.to_bool (Jv.call (by_id id) "dispatchEvent" [| ev |])

let reset () = ignore (Jv.call Jv.global "__nopal_reset_subs" [||])

let flush () =
  ignore (Jv.call Jv.global "__nopal_opener_flush" [||]);
  ignore (Jv.call Jv.global "__nopal_clipboard_flush" [||])

(* Each recorded invoke of one plugin, as its command and its arguments. *)
let invokes global =
  Jv.to_list
    (fun invoke -> (Jv.to_string (Jv.get invoke "cmd"), Jv.get invoke "args"))
    (Jv.get Jv.global global)

let commands global = List.map fst (invokes global)

let string_arg global key =
  List.map (fun (_, args) -> Jv.to_string (Jv.get args key)) (invokes global)

let test_tauri_mount_supplies_opener_and_clipboard () =
  List.iter
    (fun entry ->
      let label what = show_entry entry ^ ": " ^ what in
      reset ();
      let module A = Make_app (struct
        let prefix = "tauri-mount-" ^ show_entry entry
      end) in
      (* mutable: the mount reports each fault only through this callback. *)
      let errors = ref [] in
      let on_error text = errors := !errors @ [ text ] in
      let target = Brr.El.v (Jstr.v "div") [] in
      (match entry with
      | Mount ->
          ignore
            (Nopal_tauri_mount.mount ~on_error (module A) target
              : Nopal_web.mounted)
      | Mount_with_telemetry ->
          ignore
            (Nopal_tauri_mount.mount_with_telemetry ~on_error (module A) target
              : Nopal_web.mounted_with_telemetry));
      Alcotest.(check bool) (label "view runs") true (!A.view_calls > 0);
      Alcotest.(check (list string)) (label "nothing is reported") [] !errors;
      Alcotest.(check bool)
        (label "the target holds the link")
        false
        (Jv.is_null (by_id A.link_id));
      Alcotest.(check bool)
        (label "the click is cancelled, so the webview does not navigate")
        false (click A.link_id);
      Alcotest.(check (list string))
        (label "a click on the External link reaches the opener plugin")
        [ "plugin:opener|open_url" ]
        (commands "__nopal_opener_invokes");
      Alcotest.(check (list string))
        (label "the opener is given the link's URL")
        [ url_text ]
        (string_arg "__nopal_opener_invokes" "url");
      ignore (click A.copy_id : bool);
      Alcotest.(check (list string))
        (label "the clipboard write reaches the clipboard plugin")
        [ "plugin:clipboard-manager|write_text" ]
        (commands "__nopal_clipboard_invokes");
      Alcotest.(check (list string))
        (label "the clipboard plugin is given the text")
        [ copied_text ]
        (string_arg "__nopal_clipboard_invokes" "text");
      flush ();
      Alcotest.(check (list msg))
        (label "the app receives the copy and its outcome, and nothing else")
        [ Copy; Copied (Ok ()) ] !A.received;
      Alcotest.(check (list string))
        (label "nothing is reported after the plugins answer")
        [] !errors)
    [ Mount; Mount_with_telemetry ]

let () =
  Alcotest.run "nopal_tauri mount"
    [
      ( "mount",
        [
          Alcotest.test_case "tauri_mount_supplies_opener_and_clipboard" `Quick
            test_tauri_mount_supplies_opener_and_clipboard;
        ] );
    ]

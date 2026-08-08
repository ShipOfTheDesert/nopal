(* Renderer coverage for the [File_input] element: the picker attributes it
   emits, the styling and attrs it applies, the change listener it wires, and
   what a reconcile patches.

   Runs under dom_shim.js. The shim has no [files] property on an <input>, so
   each case installs one directly: a JS array of real [File] objects built with
   Node's global [File] constructor, which is exactly what [Brr.El.Input.files]
   reads ([Jv.find e "files"] then [Jv.to_list]). Using real Files rather than
   fake objects means [Brr.File.name] / [Brr.Blob.byte_length] /
   [Brr.Blob.type'] / [Brr.File.last_modified_ms] read the same properties they
   read in a browser. *)

open Nopal_element.Element
module Blob_store = Nopal_web.Blob_store

type msg = Picked of file_info list | Repicked of file_info list

let fresh_dispatch () =
  let msgs = ref [] in
  let dispatch msg = msgs := msg :: !msgs in
  (dispatch, msgs)

let fresh_parent () = Brr.El.v (Jstr.v "div") []

(* A style whose only layout opinion is a left padding, so the assertion has one
   unambiguous CSS property to look for. [default_layout] is all-[None] (it
   carries no behaviour), but [paint] does carry concrete values, so every paint
   field is written out explicitly here rather than inherited. *)
let styled ~padding_left =
  Nopal_style.Style.
    {
      layout = { default_layout with padding_left = Some padding_left };
      paint =
        {
          background = None;
          border = None;
          opacity = 1.0;
          shadow = None;
          overflow = Visible;
        };
      text = default_text;
    }

(* An interaction with a hover override, so [Interaction.has_any] is true and
   the renderer takes the class-injection path instead of inline styles. *)
let hover_interaction =
  Nopal_style.Interaction.
    { hover = Some (styled ~padding_left:12.0); pressed = None; focused = None }

let file_input ~style ~interaction ~attrs ~accept ~capture ~multiple ~on_change
    =
  File_input { style; interaction; attrs; accept; capture; multiple; on_change }

(* A plain, unconfigured file input — every case overrides the fields it is
   about, so nothing is inherited implicitly. *)
let plain ?(style = styled ~padding_left:8.0)
    ?(interaction = Nopal_style.Interaction.default) ?(attrs = [])
    ?(accept = []) ?capture ?(multiple = false) ?on_change () =
  file_input ~style ~interaction ~attrs ~accept ~capture ~multiple ~on_change

let attr node name =
  let v = Jv.call node "getAttribute" [| Jv.of_string name |] in
  if Jv.is_null v then None else Some (Jv.to_string v)

let render el =
  let parent = fresh_parent () in
  let dispatch, msgs = fresh_dispatch () in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el in
  (handle, Nopal_web.Renderer.dom_node handle, msgs, dispatch)

(* Builds a real File, the kind a picker hands over. [last_modified_ms] is a
   float because a real epoch-millisecond timestamp exceeds the 32-bit OCaml int
   js_of_ocaml compiles to, so an int literal would be truncated at compile
   time; JavaScript's [lastModified] is a plain number either way. *)
let make_file ~name ~text ~mime ~last_modified_ms =
  let parts = Jv.of_list Jv.of_string [ text ] in
  let init =
    Jv.obj
      [|
        ("type", Jv.of_string mime);
        ("lastModified", Jv.of_float last_modified_ms);
      |]
  in
  Jv.new' (Jv.get Jv.global "File") [| parts; Jv.of_string name; init |]

let set_files node files = Jv.set node "files" (Jv.of_list Fun.id files)

let fire_change node =
  let ev = Jv.new' (Jv.get Jv.global "Event") [| Jv.of_string "change" |] in
  ignore (Jv.call node "dispatchEvent" [| ev |])

let picked_files = function
  | Picked files -> files
  | Repicked files -> files

let file_info_testable =
  Alcotest.testable
    (fun fmt (fi : file_info) ->
      Format.fprintf fmt "{blob_id=%S; name=%S; size=%d; mime=%S; lm=%f}"
        fi.blob_id fi.name fi.size fi.mime fi.last_modified)
    (fun (a : file_info) (b : file_info) ->
      String.equal a.blob_id b.blob_id
      && String.equal a.name b.name
      && Int.equal a.size b.size
      && String.equal a.mime b.mime
      && Float.equal a.last_modified b.last_modified)

(* ---- picker attributes ---- *)

let test_type_is_file () =
  let _handle, node, _msgs, _dispatch = render (plain ()) in
  Alcotest.(check (option string)) "type=file" (Some "file") (attr node "type")

let test_accept_joined_by_commas () =
  let _handle, node, _msgs, _dispatch =
    render (plain ~accept:[ "image/png"; "image/jpeg"; ".heic" ] ())
  in
  Alcotest.(check (option string))
    "accept is the comma-joined list" (Some "image/png,image/jpeg,.heic")
    (attr node "accept")

(* The absence arm needs an affirmative one on the same fixture: an empty accept
   must omit the attribute *because the list is empty*, not because the create
   arm never writes accept at all. Reconciling the same live node to a non-empty
   accept proves the attribute can appear here, and covers the patch path. *)
let test_accept_omitted_when_empty () =
  let handle, node, _msgs, dispatch = render (plain ~accept:[] ()) in
  Alcotest.(check (option string))
    "no accept attribute for an empty list" None (attr node "accept");
  Nopal_web.Renderer.update ~dispatch handle (plain ~accept:[ "text/plain" ] ());
  Alcotest.(check (option string))
    "accept appears once the list is non-empty" (Some "text/plain")
    (attr node "accept")

let test_capture_and_multiple_rendered () =
  let _handle, node, _msgs, _dispatch =
    render (plain ~capture:Environment ~multiple:true ())
  in
  Alcotest.(check (option string))
    "capture uses the wire token for Environment" (Some "environment")
    (attr node "capture");
  Alcotest.(check (option string))
    "multiple is present as a boolean attribute" (Some "")
    (attr node "multiple");
  let _handle, node, _msgs, _dispatch =
    render (plain ~capture:User ~multiple:false ())
  in
  Alcotest.(check (option string))
    "capture uses the wire token for User" (Some "user") (attr node "capture");
  Alcotest.(check (option string))
    "multiple is absent when false" None (attr node "multiple")

(* A reconcile that drops capture and multiple must remove the attributes, not
   just leave the previous render's values in the DOM. *)
let test_reconcile_removes_capture_and_multiple () =
  let handle, node, _msgs, dispatch =
    render
      (plain ~accept:[ "image/png" ] ~capture:Environment ~multiple:true ())
  in
  Nopal_web.Renderer.update ~dispatch handle
    (plain ~accept:[] ~multiple:false ());
  Alcotest.(check (option string)) "accept removed" None (attr node "accept");
  Alcotest.(check (option string)) "capture removed" None (attr node "capture");
  Alcotest.(check (option string))
    "multiple removed" None (attr node "multiple")

(* ---- styling and attrs ---- *)

let test_style_and_attrs_applied () =
  let _handle, node, _msgs, _dispatch =
    render (plain ~attrs:[ ("data-field", "receipt") ] ())
  in
  let style_obj = Jv.get node "style" in
  Alcotest.(check string)
    "inline padding-left from the element's style" "8px"
    (Jv.Jstr.get style_obj "padding-left" |> Jstr.to_string);
  Alcotest.(check (option string))
    "call-site attrs reach the DOM" (Some "receipt") (attr node "data-field")

let test_reconcile_patches_attrs () =
  let handle, node, _msgs, dispatch =
    render (plain ~attrs:[ ("data-field", "receipt") ] ())
  in
  Nopal_web.Renderer.update ~dispatch handle
    (plain ~attrs:[ ("data-field", "invoice"); ("aria-label", "Pick") ] ());
  Alcotest.(check (option string))
    "changed attr is rewritten" (Some "invoice") (attr node "data-field");
  Alcotest.(check (option string))
    "added attr is written" (Some "Pick") (attr node "aria-label")

(* A non-interactive file input is painted with inline styles, so a style change
   must repaint. Reconciling to a structurally different style — a fresh record
   each render, as a real view rebuilds it — has to move the inline value. *)
let test_reconcile_repaints_a_changed_style () =
  let handle, node, _msgs, dispatch =
    render (plain ~style:(styled ~padding_left:8.0) ())
  in
  let style_obj = Jv.get node "style" in
  Alcotest.(check string)
    "initial padding" "8px"
    (Jv.Jstr.get style_obj "padding-left" |> Jstr.to_string);
  Nopal_web.Renderer.update ~dispatch handle
    (plain ~style:(styled ~padding_left:16.0) ());
  Alcotest.(check string)
    "changed padding is repainted" "16px"
    (Jv.Jstr.get style_obj "padding-left" |> Jstr.to_string)

(* An interactive file input is styled through an injected class, not inline. If
   the reconcile path does not recognise the element as interactive it falls
   back to the inline-style branch and paints over the class — observable as
   inline-style writes on a style change that should only swap the base class. *)
let test_interactive_reconcile_stays_class_based () =
  let handle, node, _msgs, dispatch =
    render
      (plain ~style:(styled ~padding_left:8.0) ~interaction:hover_interaction ())
  in
  let style_obj = Jv.get node "style" in
  Alcotest.(check int)
    "an interactive file input is not painted inline at create" 0
    (Jv.Int.get style_obj "_writes");
  Nopal_web.Renderer.update ~dispatch handle
    (plain ~style:(styled ~padding_left:16.0) ~interaction:hover_interaction ());
  Alcotest.(check int)
    "a style change on an interactive file input writes no inline style" 0
    (Jv.Int.get style_obj "_writes")

(* ---- change listener ---- *)

let test_change_dispatches_file_info () =
  let _handle, node, msgs, _dispatch =
    render (plain ~on_change:(fun files -> Picked files) ())
  in
  set_files node
    [
      make_file ~name:"receipt.txt" ~text:"receipt bytes" ~mime:"text/plain"
        ~last_modified_ms:1712345678000.0;
    ];
  fire_change node;
  match !msgs with
  | [ m ] -> (
      match picked_files m with
      | [ fi ] ->
          Alcotest.(check string) "name" "receipt.txt" fi.name;
          Alcotest.(check int) "size is the byte length" 13 fi.size;
          Alcotest.(check string) "mime" "text/plain" fi.mime;
          Alcotest.(check (float 0.0))
            "last_modified survives as float milliseconds" 1712345678000.0
            fi.last_modified;
          let stored = Blob_store.lookup fi.blob_id in
          Alcotest.(check bool)
            "blob_id resolves in the store" true (Option.is_some stored);
          Alcotest.(check int)
            "the stored blob is the selected file" 13
            (match stored with
            | Some b -> Brr.Blob.byte_length b
            | None -> -1)
      | files ->
          Alcotest.failf "expected one file_info, got %d" (List.length files))
  | msgs -> Alcotest.failf "expected one dispatch, got %d" (List.length msgs)

let test_change_dispatches_every_file () =
  let _handle, node, msgs, _dispatch =
    render (plain ~multiple:true ~on_change:(fun files -> Picked files) ())
  in
  set_files node
    [
      make_file ~name:"a.txt" ~text:"aa" ~mime:"text/plain"
        ~last_modified_ms:1000.0;
      make_file ~name:"b.txt" ~text:"bbbb" ~mime:"text/plain"
        ~last_modified_ms:2000.0;
    ];
  fire_change node;
  match !msgs with
  | [ m ] ->
      let files = picked_files m in
      Alcotest.(check (list string))
        "both files, in selection order" [ "a.txt"; "b.txt" ]
        (List.map (fun (fi : file_info) -> fi.name) files);
      Alcotest.(check (list int))
        "each carries its own size" [ 2; 4 ]
        (List.map (fun (fi : file_info) -> fi.size) files);
      Alcotest.(check bool)
        "each file gets its own handle" true
        (match List.map (fun (fi : file_info) -> fi.blob_id) files with
        | [ a; b ] -> not (String.equal a b)
        | []
        | [ _ ]
        | _ :: _ :: _ :: _ ->
            false)
  | msgs -> Alcotest.failf "expected one dispatch, got %d" (List.length msgs)

(* Clearing the picker must dispatch the handler with an empty list rather than
   dispatching nothing, so the model can drop the previous selection. *)
let test_change_with_no_files_dispatches_empty_list () =
  let _handle, node, msgs, _dispatch =
    render (plain ~on_change:(fun files -> Picked files) ())
  in
  set_files node [];
  fire_change node;
  match !msgs with
  | [ m ] ->
      Alcotest.(check (list file_info_testable))
        "handler fired with an empty list" [] (picked_files m)
  | msgs ->
      Alcotest.failf "expected exactly one dispatch, got %d" (List.length msgs)

let test_change_without_handler_is_inert () =
  let _handle, node, msgs, _dispatch = render (plain ?on_change:None ()) in
  set_files node
    [
      make_file ~name:"a.txt" ~text:"aa" ~mime:"text/plain"
        ~last_modified_ms:1000.0;
    ];
  fire_change node;
  Alcotest.(check int) "no handler means no dispatch" 0 (List.length !msgs)

(* A reconcile rewires the listener: the new handler runs, and the old one is
   detached rather than firing alongside it. *)
let test_reconcile_rewires_change_listener () =
  let handle, node, msgs, dispatch =
    render (plain ~on_change:(fun files -> Picked files) ())
  in
  Nopal_web.Renderer.update ~dispatch handle
    (plain ~on_change:(fun files -> Repicked files) ());
  set_files node
    [
      make_file ~name:"a.txt" ~text:"aa" ~mime:"text/plain"
        ~last_modified_ms:1000.0;
    ];
  fire_change node;
  match !msgs with
  | [ Repicked [ fi ] ] ->
      Alcotest.(check string)
        "the new handler received the file" "a.txt" fi.name
  | [ Picked _ ] -> Alcotest.fail "the stale handler fired after reconcile"
  | msgs ->
      Alcotest.failf "expected exactly one dispatch, got %d" (List.length msgs)

let () =
  Alcotest.run "nopal_web file input renderer"
    [
      ( "attributes",
        [
          Alcotest.test_case "renders type=file" `Quick test_type_is_file;
          Alcotest.test_case "renders accept joined by commas" `Quick
            test_accept_joined_by_commas;
          Alcotest.test_case "omits accept when empty" `Quick
            test_accept_omitted_when_empty;
          Alcotest.test_case "renders capture and multiple" `Quick
            test_capture_and_multiple_rendered;
          Alcotest.test_case "reconcile removes capture and multiple" `Quick
            test_reconcile_removes_capture_and_multiple;
        ] );
      ( "style and attrs",
        [
          Alcotest.test_case "applies style and attrs" `Quick
            test_style_and_attrs_applied;
          Alcotest.test_case "reconcile patches attrs" `Quick
            test_reconcile_patches_attrs;
          Alcotest.test_case "reconcile repaints a changed style" `Quick
            test_reconcile_repaints_a_changed_style;
          Alcotest.test_case "interactive reconcile stays class-based" `Quick
            test_interactive_reconcile_stays_class_based;
        ] );
      ( "change listener",
        [
          Alcotest.test_case "change dispatches file metadata" `Quick
            test_change_dispatches_file_info;
          Alcotest.test_case "change dispatches every selected file" `Quick
            test_change_dispatches_every_file;
          Alcotest.test_case "change with no files dispatches empty list" `Quick
            test_change_with_no_files_dispatches_empty_list;
          Alcotest.test_case "change without a handler is inert" `Quick
            test_change_without_handler_is_inert;
          Alcotest.test_case "reconcile rewires the change listener" `Quick
            test_reconcile_rewires_change_listener;
        ] );
    ]

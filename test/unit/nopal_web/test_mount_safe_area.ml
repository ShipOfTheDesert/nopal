(* Unit coverage for [Nopal_web.mount]'s [?safe_area_source] passthrough (RFC
   0116, Task 3 / REQ-F4). When a native safe-area source is supplied, the
   insets it delivers must be merged into the viewport the runtime renders
   against — instead of the CSS safe-area env() read — and a subsequent resize
   must rebuild from the cached native insets, not clobber them with a stale
   env() read (the Risk-list "env() and the source fight on resize" row).

   These run under dom_shim + mount_shim. mount_shim now captures the
   ResizeObserver callback and the rAF callback on [globalThis] so a resize and
   a single render frame can be driven synchronously (the base shim makes rAF a
   no-op to avoid an infinite loop). *)

(* App whose view encodes the current viewport's safe-area into text, so the
   merged insets are directly observable in the rendered DOM. *)
module Safe_area_app = struct
  type model = unit
  type msg = unit

  let init () = ((), Nopal_mvu.Cmd.none)
  let update model () = (model, Nopal_mvu.Cmd.none)

  let view vp () =
    let sa = Nopal_element.Viewport.safe_area vp in
    let content =
      Printf.sprintf "%d|%d|%d|%d"
        (Nopal_element.Viewport.safe_area_top sa)
        (Nopal_element.Viewport.safe_area_right sa)
        (Nopal_element.Viewport.safe_area_bottom sa)
        (Nopal_element.Viewport.safe_area_left sa)
    in
    Nopal_element.Element.Text { content; text_style = None }

  let subscriptions _model = Nopal_mvu.Sub.none
end

let safe_area_module :
    (module Nopal_mvu.App.S
       with type model = Safe_area_app.model
        and type msg = Safe_area_app.msg) =
  (module Safe_area_app)

let fresh_parent () = Brr.El.v (Jstr.v "div") []

(* The rendered root is [target]'s first child (a <span> from Element.Text); its
   textContent is the "t|r|b|l" the view encoded from the viewport. *)
let first_child_text target =
  let node0 = Jv.get (Jv.get (Brr.El.to_jv target) "childNodes") "0" in
  Jv.to_string (Jv.get node0 "textContent")

(* A safe-area source that delivers [insets] synchronously at setup (mirroring
   the degenerate-value-then-native contract of [Platform_tauri.safe_area_source]
   for a value already known), then never again. *)
let const_source insets (set : Nopal_element.Viewport.safe_area -> unit) =
  set insets;
  fun () -> ()

(* Drive the ResizeObserver callback mount_shim captured. *)
let fire_resize () =
  let cb = Jv.get Jv.global "__nopal_resize_cb" in
  if not (Jv.is_undefined cb) then ignore (Jv.apply cb [| Jv.undefined |])

(* Run exactly one rAF frame so a damaged tree re-renders into the DOM. *)
let run_frame () =
  let cb = Jv.get Jv.global "__nopal_raf_cb" in
  if not (Jv.is_undefined cb) then ignore (Jv.apply cb [| Jv.of_float 0. |])

(* With a source supplied, the delivered insets reach the viewport the view
   renders against (not the env() zeros the shim reports). *)
let test_safe_area_source_merges_into_viewport () =
  let target = fresh_parent () in
  let insets =
    Nopal_element.Viewport.make_safe_area ~top:10 ~right:20 ~bottom:30 ~left:40
      ()
  in
  Nopal_web.mount ~safe_area_source:(const_source insets) safe_area_module
    target;
  Alcotest.(check string)
    "viewport reflects source insets" "10|20|30|40" (first_child_text target)

(* A resize after the source delivered insets must rebuild from the cached
   insets, not a fresh env() read (which would zero them). Without the cache the
   post-resize re-render would show "0|0|0|0". *)
let test_safe_area_source_resize_uses_cache () =
  let target = fresh_parent () in
  let insets =
    Nopal_element.Viewport.make_safe_area ~top:11 ~right:22 ~bottom:33 ~left:44
      ()
  in
  Nopal_web.mount ~safe_area_source:(const_source insets) safe_area_module
    target;
  fire_resize ();
  run_frame ();
  Alcotest.(check string)
    "resize keeps cached source insets, not env zeros" "11|22|33|44"
    (first_child_text target)

(* Omitting [?safe_area_source] keeps today's behaviour: the env() read (zero
   under the shim) feeds the viewport. *)
let test_mount_without_source_uses_env () =
  let target = fresh_parent () in
  Nopal_web.mount safe_area_module target;
  Alcotest.(check string)
    "no source falls back to env() insets" "0|0|0|0" (first_child_text target)

let () =
  Alcotest.run "nopal_web mount safe_area"
    [
      ( "safe_area_source",
        [
          Alcotest.test_case "source insets merged into viewport" `Quick
            test_safe_area_source_merges_into_viewport;
          Alcotest.test_case "resize rebuilds from cached source insets" `Quick
            test_safe_area_source_resize_uses_cache;
          Alcotest.test_case "omitted source falls back to env()" `Quick
            test_mount_without_source_uses_env;
        ] );
    ]

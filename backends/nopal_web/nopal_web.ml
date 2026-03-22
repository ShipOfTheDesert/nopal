module Style_css = Style_css
module Style_sheet = Style_sheet
module Renderer = Renderer
module Platform_web = Platform_web
module Storage = Storage

let schedule_after ms callback =
  let w = Jv.get Jv.global "window" in
  let _id = Jv.call w "setTimeout" [| Jv.repr callback; Jv.of_int ms |] in
  ()

let parse_css_px raw =
  let or_else f o =
    match o with
    | Some _ -> o
    | None -> f ()
  in
  let trimmed = String.trim raw in
  let strip_px s =
    let len = String.length s in
    if len > 2 && String.sub s (len - 2) 2 = "px" then String.sub s 0 (len - 2)
    else s
  in
  let num_str = strip_px trimmed in
  int_of_string_opt trimmed
  |> or_else (fun () -> int_of_string_opt num_str)
  |> or_else (fun () -> Option.map int_of_float (float_of_string_opt num_str))
  |> Option.value ~default:0

let inject_safe_area_style () =
  let document = Jv.get Jv.global "document" in
  let style_el = Jv.call document "createElement" [| Jv.of_string "style" |] in
  let css =
    ":root {--nopal-sat: env(safe-area-inset-top, 0px);--nopal-sar: \
     env(safe-area-inset-right, 0px);--nopal-sab: env(safe-area-inset-bottom, \
     0px);--nopal-sal: env(safe-area-inset-left, 0px);}"
  in
  Jv.set style_el "textContent" (Jv.of_string css);
  let head = Jv.get document "head" in
  ignore (Jv.call head "appendChild" [| style_el |])

let read_safe_area () =
  let document = Jv.get Jv.global "document" in
  let doc_el = Jv.get document "documentElement" in
  let computed = Jv.call Jv.global "getComputedStyle" [| doc_el |] in
  let read var =
    Jv.to_string (Jv.call computed "getPropertyValue" [| Jv.of_string var |])
    |> parse_css_px
  in
  let top = read "--nopal-sat" in
  let right = read "--nopal-sar" in
  let bottom = read "--nopal-sab" in
  let left = read "--nopal-sal" in
  Nopal_element.Viewport.make_safe_area ~top ~right ~bottom ~left ()

let read_viewport safe_area =
  let w = Jv.get Jv.global "window" in
  let width = Jv.to_int (Jv.get w "innerWidth") in
  let height = Jv.to_int (Jv.get w "innerHeight") in
  Nopal_element.Viewport.make ~width ~height ~safe_area ()

let mount (type model msg)
    (module A : Nopal_mvu.App.S with type model = model and type msg = msg)
    (target : Brr.El.t) =
  let module R = Nopal_runtime.Runtime.Make (A) in
  let rt = R.create ~schedule_after () in
  (* Inject CSS custom properties bridging env() safe area values into JS-readable
     form. Must run before read_safe_area. Runs once on startup (REQ-N3). *)
  inject_safe_area_style ();
  let safe_area = read_safe_area () in
  R.start rt;
  (* Set initial viewport after start so dispatch is valid if subscriptions exist *)
  let initial_vp = read_viewport safe_area in
  R.set_viewport rt initial_vp;
  let view_lwd = R.view rt in
  let root = Lwd.observe view_lwd in
  let initial_element = Lwd.quick_sample root in
  let handle =
    Renderer.create ~dispatch:(R.dispatch rt) ~parent:target initial_element
  in
  (* A ref is used because OCaml's value restriction prevents directly
     defining a recursive closure that is passed to Jv.repr. The ref
     lets us tie the knot: each frame's callback reads !raf_loop to
     schedule the next frame via requestAnimationFrame. *)
  let raf_loop =
    (* mutable: holds the rAF callback so each frame can schedule the next *)
    ref (fun (_ts : float) -> ())
  in
  (raf_loop :=
     fun _ts ->
       if Lwd.is_damaged root then begin
         let new_element = Lwd.quick_sample root in
         Renderer.update ~dispatch:(R.dispatch rt) handle new_element
       end;
       let w = Jv.get Jv.global "window" in
       ignore (Jv.call w "requestAnimationFrame" [| Jv.repr !raf_loop |]));
  let w = Jv.get Jv.global "window" in
  ignore (Jv.call w "requestAnimationFrame" [| Jv.repr !raf_loop |]);
  (* Set up ResizeObserver to track viewport changes (REQ-F4, REQ-N2).
     The observer watches [target] as a resize trigger but [read_viewport]
     reads from [window.innerWidth]/[window.innerHeight], so the viewport
     always reflects the full browser window. This is correct when [target]
     fills the viewport — the expected usage for Nopal applications. *)
  let resize_cb =
    Jv.callback ~arity:1 (fun _entries ->
        let new_vp = read_viewport safe_area in
        R.set_viewport rt new_vp)
  in
  let observer = Jv.new' (Jv.get Jv.global "ResizeObserver") [| resize_cb |] in
  ignore (Jv.call observer "observe" [| Brr.El.to_jv target |])

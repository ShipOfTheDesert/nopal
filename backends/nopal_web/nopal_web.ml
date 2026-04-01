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

let focus_element id =
  let document = Jv.get Jv.global "document" in
  let el = Jv.call document "getElementById" [| Jv.of_string id |] in
  if not (Jv.is_none el) then ignore (Jv.call el "focus" [||])

let mount (type model msg)
    (module A : Nopal_mvu.App.S with type model = model and type msg = msg)
    (target : Brr.El.t) =
  let module R = Nopal_runtime.Runtime.Make (A) in
  let rt = R.create ~focus:focus_element ~schedule_after () in
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
  ignore (Jv.call observer "observe" [| Brr.El.to_jv target |]);
  (* keydown_prevent subscription management: a single global keydown listener
     dispatches to the current On_keydown_prevent callbacks. The callbacks ref
     is updated each rAF frame from the model's subscriptions.
     NOTE: This subscription type is managed here rather than through
     Sub_manager because it requires platform-specific preventDefault
     behavior that the platform-agnostic runtime cannot express. See
     Task 4 reflections in tasks/current.md for the full rationale. *)
  let keydown_prevent_cbs : (string * (string -> (msg * bool) option)) list ref
      =
    (* mutable: updated each rAF frame with the current model's
       On_keydown_prevent callbacks so the global keydown listener
       always dispatches against the latest subscription set *)
    ref []
  in
  let keydown_listener =
    (* mutable: holds the listener reference so it can be removed when no
       On_keydown_prevent subscriptions are active *)
    ref Jv.null
  in
  let update_keydown_prevent () =
    let subs = A.subscriptions (R.model rt) in
    let cbs = Nopal_mvu.Sub.extract_on_keydown_prevents subs in
    keydown_prevent_cbs := cbs;
    let w = Jv.get Jv.global "window" in
    match cbs with
    | [] ->
        if not (Jv.is_none !keydown_listener) then (
          ignore
            (Jv.call w "removeEventListener"
               [| Jv.of_string "keydown"; !keydown_listener |]);
          keydown_listener := Jv.null)
    | _ ->
        if Jv.is_none !keydown_listener then (
          let listener =
            Jv.callback ~arity:1 (fun event ->
                let raw_key = Jv.to_string (Jv.get event "key") in
                let shift = Jv.to_bool (Jv.get event "shiftKey") in
                let key =
                  if shift && not (String.equal raw_key "Shift") then
                    "Shift+" ^ raw_key
                  else raw_key
                in
                List.iter
                  (fun (_sub_key, f) ->
                    match f key with
                    | Some (msg, prevent) ->
                        if prevent then
                          ignore (Jv.call event "preventDefault" [||]);
                        R.dispatch rt msg
                    | Option.None -> ())
                  !keydown_prevent_cbs)
          in
          keydown_listener := listener;
          ignore
            (Jv.call w "addEventListener"
               [| Jv.of_string "keydown"; listener |]))
  in
  (raf_loop :=
     fun _ts ->
       if Lwd.is_damaged root then begin
         let new_element = Lwd.quick_sample root in
         Renderer.update ~dispatch:(R.dispatch rt) handle new_element
       end;
       update_keydown_prevent ();
       let w = Jv.get Jv.global "window" in
       ignore (Jv.call w "requestAnimationFrame" [| Jv.repr !raf_loop |]));
  let w = Jv.get Jv.global "window" in
  ignore (Jv.call w "requestAnimationFrame" [| Jv.repr !raf_loop |]);
  update_keydown_prevent ()

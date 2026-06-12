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

(* Shared DOM wiring for both {!mount} and {!mount_with_telemetry}. It is given
   the runtime operations as closures (already bound to a concrete runtime
   value), plus an optional telemetry handle: when present, the
   [window.__nopal_telemetry__] bridge is installed over it (Layer 2). Keeping
   runtime construction in the two entry points lets them own the [focus] /
   [schedule_after] platform callbacks, so those never leak into the public API.
   The on/off distinction is the entry point's name and return type, never an
   optional argument (RFC 0110, Implementation Decision 2). *)
let drive (type msg) ~(start : unit -> unit)
    ~(set_viewport : Nopal_element.Viewport.t -> unit)
    ~(view_lwd : msg Nopal_element.Element.t Lwd.t) ~(dispatch : msg -> unit)
    ~(subscriptions : unit -> msg Nopal_mvu.Sub.t)
    ~(safe_area_source :
       ((Nopal_element.Viewport.safe_area -> unit) -> unit -> unit) option)
    ~(bridge : Nopal_runtime.Telemetry.handle option) (target : Brr.El.t) =
  (* Inject CSS custom properties bridging env() safe area values into JS-readable
     form. Must run before read_safe_area. Runs once on startup (REQ-N3). *)
  inject_safe_area_style ();
  let env_safe_area = read_safe_area () in
  start ();
  (* last_insets caches the most recent safe-area insets so the ResizeObserver
     rebuild reuses the live native value (from [safe_area_source]) rather than a
     stale [env()] read, preventing an orientation update from being clobbered by
     a later resize (RFC 0116 Risk row). It seeds from the [env()] read so that
     with no source the resize behaviour is identical to before.
     mutable: updated on every safe-area delivery, read by the resize callback. *)
  let last_insets = ref env_safe_area in
  (* Set initial viewport after start so dispatch is valid if subscriptions exist *)
  set_viewport (read_viewport !last_insets);
  (* When a native source is supplied, register it: each delivered inset updates
     the cache and re-pushes the viewport. The source dispatches its degenerate
     value synchronously at setup, so this runs before the initial render below.
     The returned unlisten cleanup is unused: [mount] runs for the page lifetime
     (the existing ResizeObserver is likewise never disconnected). *)
  let _unlisten_safe_area =
    match safe_area_source with
    | Some source ->
        source (fun insets ->
            last_insets := insets;
            set_viewport (read_viewport insets))
    | None -> fun () -> ()
  in
  let root = Lwd.observe view_lwd in
  let initial_element = Lwd.quick_sample root in
  let handle = Renderer.create ~dispatch ~parent:target initial_element in
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
        let new_vp = read_viewport !last_insets in
        set_viewport new_vp)
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
    let subs = subscriptions () in
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
                        dispatch msg
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
         Renderer.update ~dispatch handle new_element
       end;
       update_keydown_prevent ();
       let w = Jv.get Jv.global "window" in
       ignore (Jv.call w "requestAnimationFrame" [| Jv.repr !raf_loop |]));
  (* Install the browser telemetry bridge over the driven runtime's handle
     (Layer 2). Only [mount_with_telemetry] supplies a handle; [mount] passes
     [None] and installs nothing. *)
  (match bridge with
  | Some handle -> Telemetry_bridge.install handle
  | None -> ());
  let w = Jv.get Jv.global "window" in
  ignore (Jv.call w "requestAnimationFrame" [| Jv.repr !raf_loop |]);
  update_keydown_prevent ()

let mount (type model msg) ?safe_area_source
    (module A : Nopal_mvu.App.S with type model = model and type msg = msg)
    (target : Brr.El.t) =
  let module R = Nopal_runtime.Runtime.Make (A) in
  let rt = R.create ~focus:focus_element ~schedule_after () in
  drive
    ~start:(fun () -> R.start rt)
    ~set_viewport:(fun vp -> R.set_viewport rt vp)
    ~view_lwd:(R.view rt)
    ~dispatch:(fun msg -> R.dispatch rt msg)
    ~subscriptions:(fun () -> A.subscriptions (R.model rt))
    ~safe_area_source ~bridge:None target

let mount_with_telemetry (type model msg) ?safe_area_source
    (module A : Nopal_mvu.App.S with type model = model and type msg = msg)
    ?serialize_msg ?serialize_model (target : Brr.El.t) =
  let module R = Nopal_runtime.Runtime.Make (A) in
  let rt, handle =
    R.create_with_telemetry ~focus:focus_element ~schedule_after ?serialize_msg
      ?serialize_model ()
  in
  drive
    ~start:(fun () -> R.start rt)
    ~set_viewport:(fun vp -> R.set_viewport rt vp)
    ~view_lwd:(R.view rt)
    ~dispatch:(fun msg -> R.dispatch rt msg)
    ~subscriptions:(fun () -> A.subscriptions (R.model rt))
    ~safe_area_source ~bridge:(Some handle) target;
  handle

module Style_css = Style_css
module Style_sheet = Style_sheet
module Renderer = Renderer
module Canvas_renderer = Canvas_renderer
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

(* Drain queued [Cmd.focus] targets, focusing each in request order. The runtime
   interprets a command synchronously during dispatch, before the rAF loop
   applies the model's DOM patch, so focusing inline would no-op against an
   element the same [update] just created (FR-3). The web backend therefore
   enqueues focus requests and flushes the queue here, once per frame *after*
   {!Renderer.update}, so the target node is already in the DOM — consistent with
   RFC 0118 Decision 9's off-rAF timing model. Already-present targets focus on
   the next frame either way, leaving existing focus behaviour unchanged. *)
let drain_focus pending =
  while not (Queue.is_empty pending) do
    focus_element (Queue.take pending)
  done

(* The DOM keydown/keyup [event.key] string the subscription handler receives.
   A held [Shift] is folded into a ["Shift+<key>"] prefix (except for the bare
   [Shift] keypress itself) so handlers can match chords like ["Shift+Tab"]
   without reading the modifier flags themselves — preserving the contract the
   pre-interpreter rAF keydown listener established (REQ-F3). *)
let event_key event =
  let raw_key = Jv.to_string (Jv.get event "key") in
  let shift = Jv.to_bool (Jv.get event "shiftKey") in
  if shift && not (String.equal raw_key "Shift") then "Shift+" ^ raw_key
  else raw_key

(* Web backend's per-atom subscription interpreter handed to the runtime
   ([Sub_manager.diff] via [Runtime.create ~interpret_atom]). Exhaustive over
   [Sub.atom] — a new constructor is a compile error here, never a silent
   no-op (REQ-F3).

   [Custom] runs its setup with the runtime-supplied [dispatch]. [Viewport] is a
   no-op because the viewport is delivered through the [ResizeObserver] /
   [set_viewport] seam below, not a listener. The five remaining built-ins set
   up a browser source — [Every] a [setInterval]; [Keydown]/[Keyup]/[Resize]
   [window] listeners; [Visibility] a [document] [visibilitychange] listener —
   and return a cleanup that tears it down, so [Sub_manager] removing the key
   stops the source. [Keydown] serves both the plain and preventDefault forms
   the [atom] unified ([handler] returns [Some (msg, prevent)] or [None]);
   [Keyup] dispatches only on [Some], dropping [None] (the filtered-keyup
   contract). *)
let web_interpret_atom (type msg) ~(dispatch : msg -> unit)
    (atom : msg Nopal_mvu.Sub.atom) : (unit -> unit, string) result =
  let w = Jv.get Jv.global "window" in
  let listen target event_type listener =
    ignore
      (Jv.call target "addEventListener"
         [| Jv.of_string event_type; listener |]);
    fun () ->
      ignore
        (Jv.call target "removeEventListener"
           [| Jv.of_string event_type; listener |])
  in
  match atom with
  | Nopal_mvu.Sub.Custom { setup; _ } -> Ok (setup dispatch)
  | Viewport _ -> Ok (fun () -> ())
  | Every { interval_ms; tick; _ } ->
      let cb = Jv.callback ~arity:1 (fun _ -> dispatch (tick ())) in
      let id = Jv.call w "setInterval" [| cb; Jv.of_int interval_ms |] in
      Ok (fun () -> ignore (Jv.call w "clearInterval" [| id |]))
  | Keydown { handler; _ } ->
      let listener =
        Jv.callback ~arity:1 (fun event ->
            match handler (event_key event) with
            | Some (msg, prevent) ->
                if prevent then ignore (Jv.call event "preventDefault" [||]);
                dispatch msg
            | Option.None -> ())
      in
      Ok (listen w "keydown" listener)
  | Keyup { handler; _ } ->
      let listener =
        Jv.callback ~arity:1 (fun event ->
            match handler (event_key event) with
            | Some msg -> dispatch msg
            | Option.None -> ())
      in
      Ok (listen w "keyup" listener)
  | Resize { handler; _ } ->
      let listener =
        Jv.callback ~arity:1 (fun _event ->
            let width = Jv.to_int (Jv.get w "innerWidth") in
            let height = Jv.to_int (Jv.get w "innerHeight") in
            dispatch (handler width height))
      in
      Ok (listen w "resize" listener)
  | Visibility { handler; _ } ->
      let document = Jv.get Jv.global "document" in
      let listener =
        Jv.callback ~arity:1 (fun _event ->
            let state = Jv.to_string (Jv.get document "visibilityState") in
            dispatch (handler (String.equal state "visible")))
      in
      Ok (listen document "visibilitychange" listener)

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
    ~(flush_focus : unit -> unit)
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
  (* keydown subscriptions are now interpreted by {!web_interpret_atom} and
     diffed through [Sub_manager] like every other built-in (REQ-F3): the
     runtime sets up a [window] keydown listener when a keydown sub appears and
     tears it down when it leaves. The previous per-rAF-frame
     [update_keydown_prevent] re-extraction is gone — subscriptions only change
     on a dispatch, which already triggers a diff. *)
  (raf_loop :=
     fun _ts ->
       if Lwd.is_damaged root then begin
         let new_element = Lwd.quick_sample root in
         Renderer.update ~dispatch handle new_element
       end;
       (* After the DOM patch so a [Cmd.focus] for an element created by this
          frame's update finds it in the DOM (FR-3). *)
       flush_focus ();
       let w = Jv.get Jv.global "window" in
       ignore (Jv.call w "requestAnimationFrame" [| Jv.repr !raf_loop |]));
  (* Install the browser telemetry bridge over the driven runtime's handle
     (Layer 2). Only [mount_with_telemetry] supplies a handle; [mount] passes
     [None] and installs nothing. *)
  (match bridge with
  | Some handle -> Telemetry_bridge.install handle
  | None -> ());
  let w = Jv.get Jv.global "window" in
  ignore (Jv.call w "requestAnimationFrame" [| Jv.repr !raf_loop |])

let mount (type model msg) ?safe_area_source ?on_error
    (module A : Nopal_mvu.App.S with type model = model and type msg = msg)
    (target : Brr.El.t) =
  let module R = Nopal_runtime.Runtime.Make (A) in
  let pending_focus = Queue.create () in
  let rt =
    R.create
      ~focus:(fun id -> Queue.add id pending_focus)
      ~schedule_after ?on_error ~interpret_atom:web_interpret_atom ()
  in
  drive
    ~start:(fun () -> R.start rt)
    ~set_viewport:(fun vp -> R.set_viewport rt vp)
    ~view_lwd:(R.view rt)
    ~dispatch:(fun msg -> R.dispatch rt msg)
    ~flush_focus:(fun () -> drain_focus pending_focus)
    ~safe_area_source ~bridge:None target

let mount_with_telemetry (type model msg) ?safe_area_source ?on_error
    (module A : Nopal_mvu.App.S with type model = model and type msg = msg)
    ?serialize_msg ?serialize_model (target : Brr.El.t) =
  let module R = Nopal_runtime.Runtime.Make (A) in
  let pending_focus = Queue.create () in
  let rt, handle =
    R.create_with_telemetry
      ~focus:(fun id -> Queue.add id pending_focus)
      ~schedule_after ?on_error ~interpret_atom:web_interpret_atom
      ?serialize_msg ?serialize_model ()
  in
  drive
    ~start:(fun () -> R.start rt)
    ~set_viewport:(fun vp -> R.set_viewport rt vp)
    ~view_lwd:(R.view rt)
    ~dispatch:(fun msg -> R.dispatch rt msg)
    ~flush_focus:(fun () -> drain_focus pending_focus)
    ~safe_area_source ~bridge:(Some handle) target;
  handle

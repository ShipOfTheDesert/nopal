module Style_css = Style_css
module Renderer = Renderer

let schedule_after ms callback =
  let w = Jv.get Jv.global "window" in
  let _id = Jv.call w "setTimeout" [| Jv.repr callback; Jv.of_int ms |] in
  ()

let mount (type model msg)
    (module A : Nopal_mvu.App.S with type model = model and type msg = msg)
    (target : Brr.El.t) =
  let module R = Nopal_runtime.Runtime.Make (A) in
  let rt = R.create ~schedule_after () in
  R.start rt;
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
  ignore (Jv.call w "requestAnimationFrame" [| Jv.repr !raf_loop |])

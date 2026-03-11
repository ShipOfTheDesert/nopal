let () =
  let open Brr in
  let target =
    match Document.find_el_by_id G.document (Jstr.v "app") with
    | Some el -> el
    | None ->
        let body = Document.body G.document in
        let div = El.div [] in
        El.append_children body [ div ];
        div
  in
  let module R = Nopal_runtime.Runtime.Make (
    Charts_bench :
      Nopal_mvu.App.S
        with type model = Charts_bench.model
         and type msg = Charts_bench.msg) in
  let schedule_after ms callback =
    let w = Jv.get Jv.global "window" in
    let _id = Jv.call w "setTimeout" [| Jv.repr callback; Jv.of_int ms |] in
    ()
  in
  let rt = R.create ~schedule_after () in
  R.start rt;
  let view_lwd = R.view rt in
  let root = Lwd.observe view_lwd in
  let initial_element = Lwd.quick_sample root in
  let handle =
    Nopal_web.Renderer.create ~dispatch:(R.dispatch rt) ~parent:target
      initial_element
  in
  let raf_loop =
    (* mutable: holds the rAF callback so each frame can schedule the next *)
    ref (fun (_ts : float) -> ())
  in
  (raf_loop :=
     fun _ts ->
       if Lwd.is_damaged root then begin
         let new_element = Lwd.quick_sample root in
         Nopal_web.Renderer.update ~dispatch:(R.dispatch rt) handle new_element
       end;
       let w = Jv.get Jv.global "window" in
       ignore (Jv.call w "requestAnimationFrame" [| Jv.repr !raf_loop |]));
  let w = Jv.get Jv.global "window" in
  ignore (Jv.call w "requestAnimationFrame" [| Jv.repr !raf_loop |])

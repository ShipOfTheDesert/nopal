type cleanup = unit -> unit
type 'msg t = { active : (string, cleanup) Hashtbl.t }

let create () = { active = Hashtbl.create 8 }

let diff ~dispatch new_subs mgr =
  (* Only Custom subscriptions are managed here. Built-in types (Every,
     On_keydown, On_keyup, On_resize, On_visibility_change) require
     platform-specific interpreters (e.g. setInterval, DOM event listeners)
     and are handled by the platform backend (nopal_web, etc.), not the
     platform-agnostic runtime. *)
  let new_customs = Nopal_mvu.Sub.extract_customs new_subs in
  let new_keys = List.map fst new_customs in
  let old_keys = Hashtbl.fold (fun k _v acc -> k :: acc) mgr.active [] in
  (* Stop removed subscriptions. Linear scan over new_keys is faster than
     hashing for the expected subscription count (<20 keys). *)
  List.iter
    (fun k ->
      if not (List.mem k new_keys) then (
        (match Hashtbl.find_opt mgr.active k with
        | Some cleanup_fn -> cleanup_fn ()
        | None -> ());
        Hashtbl.remove mgr.active k))
    old_keys;
  List.iter
    (fun (k, setup) ->
      if not (Hashtbl.mem mgr.active k) then (
        (* Register a no-op placeholder before calling setup so that
           re-entrant diffs (setup dispatching a message that triggers
           refresh -> diff) see this key as already active. *)
        Hashtbl.replace mgr.active k (fun () -> ());
        let cleanup_fn = setup dispatch in
        Hashtbl.replace mgr.active k cleanup_fn))
    new_customs

let stop_all mgr =
  Hashtbl.iter (fun _k cleanup_fn -> cleanup_fn ()) mgr.active;
  Hashtbl.clear mgr.active

let active_keys mgr =
  Hashtbl.fold (fun k _v acc -> k :: acc) mgr.active []
  |> List.sort String.compare

type cleanup = unit -> unit
type 'msg t = { active : (string, cleanup) Hashtbl.t }

let create () = { active = Hashtbl.create 8 }

let diff ?(on_error = fun _msg -> ()) ~interpret new_subs mgr =
  (* The subscription tree is normalized to a flat atom list (flattening
     [batch], carrying [map] into handlers); the backend-supplied [interpret]
     sets up one atom and returns its cleanup or an [Error] reason. This module
     stays platform-agnostic: it owns key lifecycle (add / keep / remove) and
     the failure policy, never the platform setup itself (REQ-F3, REQ-F4). *)
  let new_atoms = Nopal_mvu.Sub.atoms new_subs in
  let new_keys = List.map Nopal_mvu.Sub.atom_key new_atoms in
  let old_keys = Hashtbl.fold (fun k _v acc -> k :: acc) mgr.active [] in
  (* Stop removed subscriptions: a key active now but absent from [new_keys] is
     cleaned up exactly once and dropped. Linear scan over [new_keys] is faster
     than hashing for the expected subscription count (< 20 keys). *)
  List.iter
    (fun k ->
      if not (List.mem k new_keys) then (
        (match Hashtbl.find_opt mgr.active k with
        | Some cleanup_fn -> cleanup_fn ()
        | None -> ());
        Hashtbl.remove mgr.active k))
    old_keys;
  (* Set up new subscriptions. [seen] tracks keys handled in *this* diff so a
     key appearing twice in one tree is a reported duplicate (first wins),
     distinct from a key already active from a prior diff (stable, skipped
     silently). *)
  let seen = Hashtbl.create 8 in
  List.iter
    (fun atom ->
      let k = Nopal_mvu.Sub.atom_key atom in
      if Hashtbl.mem seen k then
        on_error
          (Printf.sprintf
             "Sub_manager: duplicate subscription key %S — first wins, this \
              one ignored"
             k)
      else begin
        Hashtbl.add seen k ();
        if Hashtbl.mem mgr.active k then ()
        else begin
          (* Register a no-op placeholder before [interpret] so a re-entrant
             diff (setup dispatching a message that triggers refresh -> diff)
             sees this key as already active and does not set it up twice. On
             [Error] the placeholder is removed so the key is NOT registered and
             the next diff retries it (REQ-F4). *)
          Hashtbl.replace mgr.active k (fun () -> ());
          match interpret atom with
          | Ok cleanup_fn -> Hashtbl.replace mgr.active k cleanup_fn
          | Error reason ->
              Hashtbl.remove mgr.active k;
              on_error
                (Printf.sprintf "Sub_manager: subscription %S setup failed: %s"
                   k reason)
        end
      end)
    new_atoms

let stop_all mgr =
  Hashtbl.iter (fun _k cleanup_fn -> cleanup_fn ()) mgr.active;
  Hashtbl.clear mgr.active

let active_keys mgr =
  Hashtbl.fold (fun k _v acc -> k :: acc) mgr.active []
  |> List.sort String.compare

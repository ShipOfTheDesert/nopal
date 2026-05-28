module Make () = struct
  open Nopal_mvu.Task.Syntax

  (* Ensure the scoped directory exists before each op, then run [f] against it.
     The directory itself is the persistence; per-op [ensure_dir] keeps the
     backend free of mutable handle state (matching nopal_storage_web's per-op
     [open_db]) and makes [keys ()] / [get] on a fresh install resolve [Ok []] /
     [Ok None] rather than fail on a missing directory. *)
  let after_dir f =
    let* prepared = Fs_store.ensure_dir () in
    match prepared with
    | Error _ as e -> Nopal_mvu.Task.return e
    | Ok () -> f ()

  let get key =
    after_dir (fun () ->
        let* listed = Fs_store.list_keys () in
        match listed with
        | Error e -> Nopal_mvu.Task.return (Error e)
        | Ok keys ->
            if List.mem key keys then
              let+ read = Fs_store.read_text ~key in
              match read with
              | Ok value -> Ok (Some value)
              | Error e -> Error e
            else Nopal_mvu.Task.return (Ok None))

  let set ~key ~value = after_dir (fun () -> Fs_store.write_text ~key ~value)

  let delete key =
    after_dir (fun () ->
        let* listed = Fs_store.list_keys () in
        match listed with
        | Error e -> Nopal_mvu.Task.return (Error e)
        | Ok keys ->
            if List.mem key keys then Fs_store.remove ~key
            else Nopal_mvu.Task.return (Ok ()))

  let keys ?prefix () =
    after_dir (fun () ->
        let+ listed = Fs_store.list_keys () in
        match listed with
        | Error _ as e -> e
        | Ok all -> (
            match prefix with
            | None -> Ok all
            | Some prefix -> Ok (List.filter (String.starts_with ~prefix) all)))

  let rec remove_all = function
    | [] -> Nopal_mvu.Task.return (Ok ())
    | key :: rest -> (
        let* removed = Fs_store.remove ~key in
        match removed with
        | Error _ as e -> Nopal_mvu.Task.return e
        | Ok () -> remove_all rest)

  let clear () =
    after_dir (fun () ->
        let* listed = Fs_store.list_keys () in
        match listed with
        | Error e -> Nopal_mvu.Task.return (Error e)
        | Ok keys -> remove_all keys)
end

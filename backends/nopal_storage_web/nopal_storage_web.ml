let database = "nopal_storage"
let store = "kv"

module Make () = struct
  open Nopal_mvu.Task.Syntax

  (* Open the database fresh per operation, run [f] against the handle, then
     close it once the op resolves. Opening is cheap relative to user-driven
     storage calls (RFC 0107 Performance), and per-op open/close keeps the
     backend free of mutable handle state — the database itself is the
     persistence. Closing is mandatory: a leaked connection blocks the next
     schema-version upgrade ([Indexeddb.close]). *)
  let with_db f =
    let* opened = Indexeddb.open_db ~name:database ~store in
    match opened with
    | Error e -> Nopal_mvu.Task.return (Error e)
    | Ok db ->
        let* result = f db in
        Indexeddb.close db;
        Nopal_mvu.Task.return result

  let get key = with_db (fun db -> Indexeddb.get db ~store ~key)
  let set ~key ~value = with_db (fun db -> Indexeddb.put db ~store ~key ~value)
  let delete key = with_db (fun db -> Indexeddb.delete db ~store ~key)

  let keys ?prefix () =
    with_db (fun db ->
        let+ all_keys = Indexeddb.get_all_keys db ~store in
        match all_keys with
        | Error _ as e -> e
        | Ok all -> (
            match prefix with
            | None -> Ok all
            | Some prefix -> Ok (List.filter (String.starts_with ~prefix) all)))

  let clear () = with_db (fun db -> Indexeddb.clear db ~store)
end

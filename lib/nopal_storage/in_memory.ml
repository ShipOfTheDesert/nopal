module Make () = struct
  (* The backend's persistence is, by definition, mutable state retained across
     calls. The generative [()] gives each application its own [table], so two
     [Make ()] instances never share keys. Side effects are deferred into the
     task body (via [from_callback]) so building a task in [update] stays pure;
     the mutation happens only when the runtime [run]s it. *)
  let table : (string, string) Hashtbl.t = Hashtbl.create 16

  let get key =
    Nopal_mvu.Task.from_callback (fun resolve ->
        resolve (Ok (Hashtbl.find_opt table key)))

  let set ~key ~value =
    Nopal_mvu.Task.from_callback (fun resolve ->
        Hashtbl.replace table key value;
        resolve (Ok ()))

  let delete key =
    Nopal_mvu.Task.from_callback (fun resolve ->
        Hashtbl.remove table key;
        resolve (Ok ()))

  let keys ?prefix () =
    Nopal_mvu.Task.from_callback (fun resolve ->
        let all = Hashtbl.fold (fun key _ acc -> key :: acc) table [] in
        let selected =
          match prefix with
          | None -> all
          | Some prefix -> List.filter (String.starts_with ~prefix) all
        in
        resolve (Ok selected))

  let clear () =
    Nopal_mvu.Task.from_callback (fun resolve ->
        Hashtbl.reset table;
        resolve (Ok ()))

  let reset () = Hashtbl.reset table
end

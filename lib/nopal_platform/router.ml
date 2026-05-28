type 'route t = {
  platform : (module Platform.NAV);
  parse : string -> 'route option;
  to_path : 'route -> string;
  not_found : 'route;
}

let create ~platform ~parse ~to_path ~not_found =
  { platform; parse; to_path; not_found }

let current t =
  let module P = (val t.platform : Platform.NAV) in
  let path = P.current_path () in
  match t.parse path with
  | Some route -> route
  | None -> t.not_found

let push t route =
  Nopal_mvu.Cmd.perform (fun _dispatch ->
      let module P = (val t.platform : Platform.NAV) in
      P.push_state (t.to_path route))

let replace t route =
  Nopal_mvu.Cmd.perform (fun _dispatch ->
      let module P = (val t.platform : Platform.NAV) in
      P.replace_state (t.to_path route))

let back t =
  Nopal_mvu.Cmd.perform (fun _dispatch ->
      let module P = (val t.platform : Platform.NAV) in
      P.back ())

let on_navigate t to_msg =
  Nopal_mvu.Sub.custom "nopal_platform:on_navigate" (fun dispatch ->
      let module P = (val t.platform : Platform.NAV) in
      let callback path =
        let route =
          match t.parse path with
          | Some r -> r
          | None -> t.not_found
        in
        dispatch (to_msg route)
      in
      P.on_popstate callback)

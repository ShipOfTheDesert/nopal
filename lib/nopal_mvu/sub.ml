type 'msg dispatch = 'msg -> unit

type 'msg t =
  | None
  | Batch of 'msg t list
  | Every of { key : string; ms : int; f : unit -> 'msg }
  | On_keydown of { key : string; f : string -> 'msg }
  | On_keyup of { key : string; f : string -> 'msg }
  | On_resize of { key : string; f : int -> int -> 'msg }
  | On_visibility_change of { key : string; f : bool -> 'msg }
  | Custom of { key : string; setup : 'msg dispatch -> unit -> unit }

let none = None
let batch subs = Batch subs
let every key ms f = Every { key; ms; f }
let on_keydown key f = On_keydown { key; f }
let on_keyup key f = On_keyup { key; f }
let on_resize key f = On_resize { key; f }
let on_visibility_change key f = On_visibility_change { key; f }
let custom key setup = Custom { key; setup }

let rec keys sub =
  match sub with
  | None -> []
  | Batch subs ->
      let all_keys = List.concat_map keys subs in
      let seen = Hashtbl.create 8 in
      List.filter
        (fun k ->
          if Hashtbl.mem seen k then false
          else (
            Hashtbl.add seen k ();
            true))
        all_keys
  | Every { key; _ } -> [ key ]
  | On_keydown { key; _ } -> [ key ]
  | On_keyup { key; _ } -> [ key ]
  | On_resize { key; _ } -> [ key ]
  | On_visibility_change { key; _ } -> [ key ]
  | Custom { key; _ } -> [ key ]

let rec map f sub =
  match sub with
  | None -> None
  | Batch subs -> Batch (List.map (map f) subs)
  | Every { key; ms; f = g } -> Every { key; ms; f = (fun () -> f (g ())) }
  | On_keydown { key; f = g } -> On_keydown { key; f = (fun k -> f (g k)) }
  | On_keyup { key; f = g } -> On_keyup { key; f = (fun k -> f (g k)) }
  | On_resize { key; f = g } -> On_resize { key; f = (fun w h -> f (g w h)) }
  | On_visibility_change { key; f = g } ->
      On_visibility_change { key; f = (fun v -> f (g v)) }
  | Custom { key; setup } ->
      Custom
        { key; setup = (fun dispatch -> setup (fun msg -> dispatch (f msg))) }

let extract_every = function
  | Every { ms; f; _ } -> Some (ms, f)
  | None
  | Batch _
  | On_keydown _
  | On_keyup _
  | On_resize _
  | On_visibility_change _
  | Custom _ ->
      Option.none

let extract_on_keydown = function
  | On_keydown { f; _ } -> Some f
  | None
  | Batch _
  | Every _
  | On_keyup _
  | On_resize _
  | On_visibility_change _
  | Custom _ ->
      Option.none

let extract_on_keyup = function
  | On_keyup { f; _ } -> Some f
  | None
  | Batch _
  | Every _
  | On_keydown _
  | On_resize _
  | On_visibility_change _
  | Custom _ ->
      Option.none

let extract_on_resize = function
  | On_resize { f; _ } -> Some f
  | None
  | Batch _
  | Every _
  | On_keydown _
  | On_keyup _
  | On_visibility_change _
  | Custom _ ->
      Option.none

let extract_on_visibility_change = function
  | On_visibility_change { f; _ } -> Some f
  | None
  | Batch _
  | Every _
  | On_keydown _
  | On_keyup _
  | On_resize _
  | Custom _ ->
      Option.none

let extract_custom = function
  | Custom { setup; _ } -> Some setup
  | None
  | Batch _
  | Every _
  | On_keydown _
  | On_keyup _
  | On_resize _
  | On_visibility_change _ ->
      Option.none

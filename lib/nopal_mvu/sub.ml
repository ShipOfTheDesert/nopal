type 'msg dispatch = 'msg -> unit

type 'msg t =
  | None
  | Batch of 'msg t list
  | Every of { key : string; ms : int; f : unit -> 'msg }
  | On_keydown of { key : string; f : string -> ('msg * bool) option }
  | On_keyup of { key : string; f : string -> 'msg option }
  | On_resize of { key : string; f : int -> int -> 'msg }
  | On_visibility_change of { key : string; f : bool -> 'msg }
  | On_viewport_change of { key : string; f : Nopal_element.Viewport.t -> 'msg }
  | Custom of { key : string; setup : 'msg dispatch -> unit -> unit }

let none = None
let batch subs = Batch subs
let every key ms f = Every { key; ms; f }
let on_keydown key f = On_keydown { key; f }

let on_key key ~key:target ~prevent msg =
  On_keydown
    {
      key;
      f =
        (fun pressed ->
          if String.equal pressed target then Some (msg, prevent)
          else Option.none);
    }

let on_keyup key f = On_keyup { key; f }
let on_resize key f = On_resize { key; f }
let on_visibility_change key f = On_visibility_change { key; f }
let on_viewport_change key f = On_viewport_change { key; f }
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
  | On_viewport_change { key; _ } -> [ key ]
  | Custom { key; _ } -> [ key ]

let describe = function
  | None -> "none"
  | Batch _ -> "batch"
  | Every _ -> "every"
  | On_keydown _ -> "on_keydown"
  | On_keyup _ -> "on_keyup"
  | On_resize _ -> "on_resize"
  | On_visibility_change _ -> "on_visibility_change"
  | On_viewport_change _ -> "on_viewport_change"
  | Custom _ -> "custom"

let rec map f sub =
  match sub with
  | None -> None
  | Batch subs -> Batch (List.map (map f) subs)
  | Every { key; ms; f = g } -> Every { key; ms; f = (fun () -> f (g ())) }
  | On_keydown { key; f = g } ->
      On_keydown
        {
          key;
          f =
            (fun k -> Option.map (fun (msg, prevent) -> (f msg, prevent)) (g k));
        }
  | On_keyup { key; f = g } ->
      On_keyup { key; f = (fun k -> Option.map f (g k)) }
  | On_resize { key; f = g } -> On_resize { key; f = (fun w h -> f (g w h)) }
  | On_visibility_change { key; f = g } ->
      On_visibility_change { key; f = (fun v -> f (g v)) }
  | On_viewport_change { key; f = g } ->
      On_viewport_change { key; f = (fun vp -> f (g vp)) }
  | Custom { key; setup } ->
      Custom
        { key; setup = (fun dispatch -> setup (fun msg -> dispatch (f msg))) }

(* Defined after every [t] combinator so [Every]/[Custom] in those functions
   resolve to [t], not to this variant. *)
type 'msg atom =
  | Every of { key : string; interval_ms : int; tick : unit -> 'msg }
  | Keydown of { key : string; handler : string -> ('msg * bool) option }
  | Keyup of { key : string; handler : string -> 'msg option }
  | Resize of { key : string; handler : int -> int -> 'msg }
  | Visibility of { key : string; handler : bool -> 'msg }
  | Viewport of { key : string; handler : Nopal_element.Viewport.t -> 'msg }
  | Custom of { key : string; setup : 'msg dispatch -> unit -> unit }

let atom_key : 'msg atom -> string = function
  | Every { key; _ } -> key
  | Keydown { key; _ } -> key
  | Keyup { key; _ } -> key
  | Resize { key; _ } -> key
  | Visibility { key; _ } -> key
  | Viewport { key; _ } -> key
  | Custom { key; _ } -> key

let describe_atom : 'msg atom -> string = function
  | Every _ -> "every"
  | Keydown _ -> "keydown"
  | Keyup _ -> "keyup"
  | Resize _ -> "resize"
  | Visibility _ -> "visibility"
  | Viewport _ -> "viewport"
  | Custom _ -> "custom"

let rec atoms (sub : 'msg t) : 'msg atom list =
  match sub with
  | None -> []
  | Batch subs -> List.concat_map atoms subs
  | Every { key; ms; f } -> [ Every { key; interval_ms = ms; tick = f } ]
  | On_keydown { key; f } -> [ Keydown { key; handler = f } ]
  | On_keyup { key; f } -> [ Keyup { key; handler = f } ]
  | On_resize { key; f } -> [ Resize { key; handler = f } ]
  | On_visibility_change { key; f } -> [ Visibility { key; handler = f } ]
  | On_viewport_change { key; f } -> [ Viewport { key; handler = f } ]
  | Custom { key; setup } -> [ Custom { key; setup } ]

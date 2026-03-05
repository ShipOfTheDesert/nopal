type 'msg dispatch = 'msg -> unit

type 'msg t =
  | None
  | Batch of 'msg t list
  | Perform of ('msg dispatch -> unit)
  | Task of ('msg dispatch -> unit)
  | After of { ms : int; msg : 'msg }

let none = None

let batch cmds =
  let flatten = function
    | Batch inner -> inner
    | other -> [ other ]
  in
  Batch (List.concat_map flatten cmds)

let perform f = Perform f
let task f = Task f
let after ms msg = After { ms; msg }

let rec map f cmd =
  match cmd with
  | None -> None
  | Batch cmds -> Batch (List.map (map f) cmds)
  | Perform g -> Perform (fun dispatch -> g (fun a -> dispatch (f a)))
  | Task g -> Task (fun dispatch -> g (fun a -> dispatch (f a)))
  | After { ms; msg } -> After { ms; msg = f msg }

let rec execute dispatch cmd =
  match cmd with
  | None -> ()
  | Batch cmds -> List.iter (execute dispatch) cmds
  | Perform f -> f dispatch
  | Task f -> f dispatch
  | After _ -> ()

let extract_after = function
  | After { ms; msg } -> Some (ms, msg)
  | None
  | Batch _
  | Perform _
  | Task _ ->
      Option.none

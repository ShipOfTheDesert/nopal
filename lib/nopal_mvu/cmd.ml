type 'msg dispatch = 'msg -> unit

type 'msg t =
  | None
  | Batch of 'msg t list
  | Perform of ('msg dispatch -> unit)
  | Task of 'msg Task.t
  | After of { ms : int; msg : 'msg }
  | Focus of { id : string }

let none = None

let batch cmds =
  let flatten = function
    | Batch inner -> inner
    | other -> [ other ]
  in
  Batch (List.concat_map flatten cmds)

let perform f = Perform f
let task t = Task t
let after ms msg = After { ms; msg }
let focus id = Focus { id }

let rec map f cmd =
  match cmd with
  | None -> None
  | Batch cmds -> Batch (List.map (map f) cmds)
  | Perform g -> Perform (fun dispatch -> g (fun a -> dispatch (f a)))
  | Task t -> Task (Task.map f t)
  | After { ms; msg } -> After { ms; msg = f msg }
  | Focus { id } -> Focus { id }

let rec execute dispatch cmd =
  match cmd with
  | None -> ()
  | Batch cmds -> List.iter (execute dispatch) cmds
  | Perform f -> f dispatch
  | Task t -> Task.run t dispatch
  | After _
  | Focus _ ->
      ()

let extract_after = function
  | After { ms; msg } -> Some (ms, msg)
  | None
  | Batch _
  | Perform _
  | Task _
  | Focus _ ->
      Option.none

let extract_focus = function
  | Focus { id } -> Some id
  | None
  | Batch _
  | Perform _
  | Task _
  | After _ ->
      Option.none

let rec extract_focuses = function
  | Focus { id } -> [ id ]
  | Batch cmds -> List.concat_map extract_focuses cmds
  | None
  | Perform _
  | Task _
  | After _ ->
      []

let rec interpret ~focus ~dispatch ~schedule_after = function
  | None -> ()
  | Batch cmds -> List.iter (interpret ~focus ~dispatch ~schedule_after) cmds
  | Perform f -> f dispatch
  | Task t -> Task.run t dispatch
  | After { ms; msg } -> schedule_after ms msg
  | Focus { id } -> focus id

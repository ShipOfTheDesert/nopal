type 'msg dispatch = 'msg -> unit

type 'msg t =
  | None
  | Batch of 'msg t list
  | Perform of ('msg dispatch -> unit)
  | Task of 'msg Task.t
  | After of { ms : int; msg : 'msg }
  | Focus of { id : string }
  | Scroll_by of { id : string; delta : Nopal_element.Scroll_delta.t }
  | Write_clipboard of {
      text : string;
      on_result : (unit, Clipboard.error) result -> 'msg;
    }

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
let scroll_by id delta = Scroll_by { id; delta }
let write_clipboard text ~on_result = Write_clipboard { text; on_result }

let is_none = function
  | None -> true
  | Batch _
  | Perform _
  | Task _
  | After _
  | Focus _
  | Scroll_by _
  | Write_clipboard _ ->
      false

let describe = function
  | None -> "none"
  | Batch _ -> "batch"
  | Perform _ -> "perform"
  | Task _ -> "task"
  | After _ -> "after"
  | Focus _ -> "focus"
  | Scroll_by _ -> "scroll_by"
  | Write_clipboard _ -> "write_clipboard"

let rec map f cmd =
  match cmd with
  | None -> None
  | Batch cmds -> Batch (List.map (map f) cmds)
  | Perform g -> Perform (fun dispatch -> g (fun a -> dispatch (f a)))
  | Task t -> Task (Task.map f t)
  | After { ms; msg } -> After { ms; msg = f msg }
  | Focus { id } -> Focus { id }
  | Scroll_by { id; delta } -> Scroll_by { id; delta }
  | Write_clipboard { text; on_result } ->
      Write_clipboard { text; on_result = (fun r -> f (on_result r)) }

let rec execute dispatch cmd =
  match cmd with
  | None -> ()
  | Batch cmds -> List.iter (execute dispatch) cmds
  | Perform f -> f dispatch
  | Task t -> Task.run t dispatch
  | After _
  | Focus _
  | Scroll_by _
  | Write_clipboard _ ->
      ()

let extract_after = function
  | After { ms; msg } -> Some (ms, msg)
  | None
  | Batch _
  | Perform _
  | Task _
  | Focus _
  | Scroll_by _
  | Write_clipboard _ ->
      Option.none

let extract_focus = function
  | Focus { id } -> Some id
  | None
  | Batch _
  | Perform _
  | Task _
  | After _
  | Scroll_by _
  | Write_clipboard _ ->
      Option.none

let rec extract_focuses = function
  | Focus { id } -> [ id ]
  | Batch cmds -> List.concat_map extract_focuses cmds
  | None
  | Perform _
  | Task _
  | After _
  | Scroll_by _
  | Write_clipboard _ ->
      []

let rec extract_scroll_bys = function
  | Scroll_by { id; delta } -> [ (id, delta) ]
  | Batch cmds -> List.concat_map extract_scroll_bys cmds
  | None
  | Perform _
  | Task _
  | After _
  | Focus _
  | Write_clipboard _ ->
      []

let rec extract_clipboard_writes = function
  | Write_clipboard { text; on_result } -> [ (text, on_result) ]
  | Batch cmds -> List.concat_map extract_clipboard_writes cmds
  | None
  | Perform _
  | Task _
  | After _
  | Focus _
  | Scroll_by _ ->
      []

let rec interpret ~focus ~scroll_by ~write_clipboard ~dispatch ~schedule_after =
  function
  | None -> ()
  | Batch cmds ->
      List.iter
        (interpret ~focus ~scroll_by ~write_clipboard ~dispatch ~schedule_after)
        cmds
  | Perform f -> f dispatch
  | Task t -> Task.run t dispatch
  | After { ms; msg } -> schedule_after ms msg
  | Focus { id } -> focus id
  | Scroll_by { id; delta } -> scroll_by id delta
  | Write_clipboard { text; on_result } ->
      Task.run
        (Task.guard_once
           ~on_exn:(fun e -> Clipboard.Failed (Printexc.to_string e))
           (write_clipboard text))
        (fun r -> dispatch (on_result r))

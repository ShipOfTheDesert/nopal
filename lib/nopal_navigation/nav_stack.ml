type 'screen t = { current : 'screen; below : 'screen list }
(* [below] is ordered nearest-first: its head is the screen [pop] returns to. *)

let create root = { current = root; below = [] }
let push s t = { current = s; below = t.current :: t.below }

let pop t =
  match t.below with
  | [] -> t
  | prev :: rest -> { current = prev; below = rest }

let current t = t.current
let depth t = 1 + List.length t.below

let can_pop t =
  match t.below with
  | [] -> false
  | _ :: _ -> true

let screens t = List.rev (t.current :: t.below)

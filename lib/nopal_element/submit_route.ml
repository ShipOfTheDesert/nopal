type 'msg t =
  | Dispatch of { msg : 'msg; prevent_default : bool }
  | To_enclosing_form
  | Nothing

(* The one spelling of the key that makes a form submit implicitly, so the
   contract has a single greppable token rather than a literal repeated at
   each site that cares about Enter. *)
let enter_key = "Enter"

let of_key ~key ~on_keydown ~on_submit =
  (* The keydown handler is consulted for every key, before anything else. *)
  let consumed = Option.bind on_keydown (fun handler -> handler key) in
  match key with
  | k when k = enter_key -> (
      match (consumed, on_submit) with
      | Some msg, (Some _ | None) -> Dispatch { msg; prevent_default = true }
      | None, Some msg -> Dispatch { msg; prevent_default = true }
      | None, None -> To_enclosing_form)
  | _ -> (
      match consumed with
      | Some msg -> Dispatch { msg; prevent_default = false }
      | None -> Nothing)

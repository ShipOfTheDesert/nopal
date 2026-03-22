type 'a t = ('a -> unit) -> unit

let return x resolve = resolve x
let from_callback f = f
let map f task resolve = task (fun x -> resolve (f x))
let bind f task resolve = task (fun x -> f x resolve)
let run task resolve = task resolve

(* Mutable: one-shot signal shared between cancel caller and task closure.
   on_cancel is set by platform backends to wire cancellation to I/O abort
   mechanisms (e.g., AbortController). *)
type cancellation_token = {
  mutable cancelled : bool;
  mutable on_cancel : (unit -> unit) option;
}

let cancellable f =
  let token = { cancelled = false; on_cancel = None } in
  let task = f token in
  let wrapped resolve =
    let resolved = Atomic.make false in
    let guarded_resolve result =
      if Atomic.compare_and_set resolved false true then resolve result
    in
    if token.cancelled then guarded_resolve (Error "cancelled")
    else begin
      task (fun value ->
          if token.cancelled then guarded_resolve (Error "cancelled")
          else guarded_resolve (Ok value));
      if token.cancelled && not (Atomic.get resolved) then
        guarded_resolve (Error "cancelled")
    end
  in
  (token, wrapped)

let cancel token =
  if not token.cancelled then begin
    token.cancelled <- true;
    match token.on_cancel with
    | Some f -> f ()
    | None -> ()
  end

let set_on_cancel token f =
  token.on_cancel <- Some f;
  if token.cancelled then f ()

let is_cancelled token = token.cancelled

module Syntax = struct
  let ( let* ) task f = bind f task
  let ( let+ ) task f = map f task
end

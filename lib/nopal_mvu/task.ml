type 'a t = ('a -> unit) -> unit

let return x resolve = resolve x
let from_callback f = f

let guard ~on_exn f resolve =
  try f resolve with
  | e -> resolve (Error (on_exn e))

let map f task resolve = task (fun x -> resolve (f x))
let bind f task resolve = task (fun x -> f x resolve)
let run task resolve = task resolve

type 'a outcome = Completed of 'a | Cancelled

(* Mutable: one-shot signal shared between cancel caller and task closure.
   on_cancel is set by platform backends to wire cancellation to I/O abort
   mechanisms (e.g., AbortController). deliver_cancelled is set internally by
   the cancellable wrapper once it is run, so that cancel delivers [Cancelled]
   at cancel time rather than waiting on the aborted work to resolve; it is
   distinct from on_cancel so a backend hook and the delivery path never clobber
   each other. *)
type cancellation_token = {
  mutable cancelled : bool;
  mutable on_cancel : (unit -> unit) option;
  mutable deliver_cancelled : (unit -> unit) option;
}

let cancellable f =
  let token =
    { cancelled = false; on_cancel = None; deliver_cancelled = None }
  in
  let task = f token in
  let wrapped resolve =
    let resolved = Atomic.make false in
    let guarded_resolve outcome =
      if Atomic.compare_and_set resolved false true then resolve outcome
    in
    if token.cancelled then guarded_resolve Cancelled
    else begin
      token.deliver_cancelled <- Some (fun () -> guarded_resolve Cancelled);
      task (fun value ->
          if token.cancelled then guarded_resolve Cancelled
          else guarded_resolve (Completed value))
    end
  in
  (token, wrapped)

let cancel token =
  if not token.cancelled then begin
    token.cancelled <- true;
    (match token.on_cancel with
    | Some f -> f ()
    | None -> ());
    match token.deliver_cancelled with
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

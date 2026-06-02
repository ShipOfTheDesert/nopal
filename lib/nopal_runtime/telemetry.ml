type event =
  | Message of string
  | Model_transition of { before : string; after : string }
  | Command of string
  | Subscription of string

type sink = { id : int; notify : event -> unit }

type log = {
  mutable events : event list;
      (* mutable: the in-process record, accumulated newest-first as events are
         recorded and emptied by [clear]. Reversed on read by [events]. *)
  mutable sinks : sink list;
      (* mutable: [on_record] sinks, stored in registration order so [append]
         invokes them in that order; each carries an [id] so its disposer can
         remove exactly that registration. *)
  mutable next_sink_id : int;
      (* mutable: monotonic id source giving every [on_record] subscription a
         stable identity, so a disposer removes the right sink even when two
         sinks are physically-equal closures. *)
}

type recorder = On of log | Off
type handle = log

(* A single shared constant: the non-recording target allocates nothing per
   event because every [record_*] matches [Off] before building an event. *)
let off = Off

let create () =
  let log = { events = []; sinks = []; next_sink_id = 0 } in
  (On log, log)

let append log event =
  log.events <- event :: log.events;
  List.iter (fun { notify; _ } -> notify event) log.sinks

let record_message recorder msg ~serialize =
  match recorder with
  | Off -> ()
  | On log -> append log (Message (serialize msg))

let record_transition recorder ~before ~after ~serialize =
  match recorder with
  | Off -> ()
  | On log ->
      append log
        (Model_transition { before = serialize before; after = serialize after })

let record_command recorder label =
  match recorder with
  | Off -> ()
  | On log -> append log (Command label)

let record_subscription recorder label =
  match recorder with
  | Off -> ()
  | On log -> append log (Subscription label)

let events handle = List.rev handle.events
let clear handle = handle.events <- []

(* Append at registration (rare) so [append] can iterate sinks directly in
   registration order (frequent), without reversing on every event. Returns a
   disposer that drops this sink, so one-shot waiters do not leak. Filtering
   builds a fresh list, so disposing from inside a sink (mid-[append]) is safe —
   [append]'s [List.iter] keeps iterating the old immutable list. *)
let on_record handle notify =
  let id = handle.next_sink_id in
  handle.next_sink_id <- id + 1;
  handle.sinks <- handle.sinks @ [ { id; notify } ];
  fun () -> handle.sinks <- List.filter (fun s -> s.id <> id) handle.sinks

let pp_event fmt = function
  | Message s -> Format.fprintf fmt "Message %S" s
  | Model_transition { before; after } ->
      Format.fprintf fmt "Model_transition { before = %S; after = %S }" before
        after
  | Command s -> Format.fprintf fmt "Command %S" s
  | Subscription s -> Format.fprintf fmt "Subscription %S" s

let pp_events fmt events =
  List.iter (fun e -> Format.fprintf fmt "%a@." pp_event e) events

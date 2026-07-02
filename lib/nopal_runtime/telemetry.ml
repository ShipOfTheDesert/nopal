type event =
  | Message of string
  | Model_transition of { before : string; after : string }
  | Command of string
  | Subscription of string

type sink = { id : int; notify : event -> unit }

(* The retained-event ceiling. An [expose]d Tauri/web mirror forwards every
   recorded event for the whole session, so an unbounded list would leak; beyond
   this many events the oldest are dropped (drop-oldest). Kept in parity with the
   Rust [TelemetryMirror] bound so the host and browser mirrors agree and neither
   grows without limit (feature 0120 FR-7). *)
let log_capacity = 10_000

type log = {
  mutable events : event list;
      (* mutable: the in-process record, accumulated newest-first as events are
         recorded and emptied by [clear]. Reversed on read by [events]. Bounded
         to [log_capacity] (drop-oldest) so it cannot grow unbounded. *)
  mutable event_count : int;
      (* mutable: number of retained events, so [append] enforces [log_capacity]
         in O(1) below the cap without an O(n) length scan per event. *)
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
  let log = { events = []; event_count = 0; sinks = []; next_sink_id = 0 } in
  (On log, log)

let append log event =
  log.events <- event :: log.events;
  log.event_count <- log.event_count + 1;
  (* Drop-oldest once past the cap: [events] is newest-first, so keeping the
     first [log_capacity] entries discards the oldest. The guard is O(1) below
     the cap (the common case), so recording stays cheap until the mirror is
     actually full. *)
  if log.event_count > log_capacity then begin
    log.events <- List.filteri (fun i _ -> i < log_capacity) log.events;
    log.event_count <- log_capacity
  end;
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

let clear handle =
  handle.events <- [];
  handle.event_count <- 0

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

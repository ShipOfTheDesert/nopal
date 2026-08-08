(* Module-level state rather than a value the caller threads around: there is
   exactly one JavaScript heap per page session to register blobs against, and
   the store's whole purpose is to be reachable from unrelated backends — the
   web renderer's file-input change listener registers, an HTTP send resolves —
   without either appearing in the other's signature. Making it a functor or an
   explicit handle would force that singleton through every intermediate type
   for no added safety. Same
   global-mutable exception, and the same rationale, as nopal_http.ml's
   [current_backend] and style_sheet.ml's per-document sheet. *)
let entries : (string, Brr.Blob.t) Hashtbl.t = Hashtbl.create 16

(* mutable: monotonic handle counter, the source of handle uniqueness. Never
   reset — not by [remove], not by [clear] — so a released handle is never
   reissued and a stale handle resolves to [None] instead of to a later blob. *)
let next_id = ref 0

(* The counter alone makes a handle guessable — "nopal-blob-3" is a literal
   anyone could write — and a guessed handle resolves to somebody else's blob
   with no error path, since [lookup] cannot tell a fabricated handle from a
   real one. A per-session random prefix closes that: the counter still supplies
   uniqueness, this supplies unguessability. Drawn from its own [Random.State.t]
   rather than [Random.self_init], which would perturb the global state that
   application code shares. *)
let session_prefix =
  let st = Random.State.make_self_init () in
  Printf.sprintf "%08x%08x" (Random.State.bits st) (Random.State.bits st)

let store blob =
  let id = !next_id in
  next_id := id + 1;
  let handle = "nopal-blob-" ^ session_prefix ^ "-" ^ string_of_int id in
  Hashtbl.replace entries handle blob;
  handle

let lookup handle = Hashtbl.find_opt entries handle
let remove handle = Hashtbl.remove entries handle
let clear () = Hashtbl.reset entries

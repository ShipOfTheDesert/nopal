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

(* The global URL object, but only once it actually carries [method'] as
   something callable. Probed inside each call rather than read once at module
   initialisation: an environment supplying neither would otherwise throw while
   this module is being linked, taking the whole bundle down instead of failing
   the one call that wanted the capability.

   This package's stated contract is that resolving a handle is an absence and
   never an exception, and the probe is half of what keeps the two functions
   below total: it covers the environment that predates object URLs, where
   reading the global blind and calling what is not there would raise. The
   other half is the guard at each call site — the probe establishes that the
   member exists and is callable, never that calling it succeeds — because a
   member that exists and refuses is the same broken promise to the caller. *)
let url_object_with method' =
  match Jv.find Jv.global "URL" with
  | None -> None
  | Some url -> (
      match Jv.find url method' with
      | None -> None
      | Some candidate -> (
          match
            String.equal (Jstr.to_string (Jv.typeof candidate)) "function"
          with
          | true -> Some url
          | false -> None))

let object_url handle =
  match lookup handle with
  | None -> None
  | Some blob -> (
      match url_object_with "createObjectURL" with
      | None -> None
      | Some url -> (
          (* A refusal is an absence here, not an exception: a quota, a
             hardened or proxied global or a blocked call all leave the caller
             with no URL, which is the one outcome this signature can express.
             Any exception rather than [Jv.Error] alone — what an environment
             throws is its own to choose, and only a thrown value that is an
             [Error] instance crosses into OCaml as [Jv.Error] (brr's [Jv]
             says so at the exception itself), so narrowing the pattern would
             leave the rest escaping the contract. *)
          match Jv.call url "createObjectURL" [| Brr.Blob.to_jv blob |] with
          | exception _ -> None
          | minted -> (
              (* [Jv.to_string] is an unchecked cast, so the mint is
                 type-checked before it is taken: an environment answering with
                 anything but a string would otherwise produce a value typed
                 [string] that is not one, and every later [String.length] on
                 it would read a shape the runtime never laid out. *)
              match
                String.equal (Jstr.to_string (Jv.typeof minted)) "string"
              with
              | true -> Some (Jv.to_string minted)
              | false -> None)))

let revoke_url url =
  match url_object_with "revokeObjectURL" with
  | None -> ()
  | Some url_object -> (
      (* Idempotence and tolerance of an unrecognised string are the platform's:
         revokeObjectURL is specified to do nothing when the string names no
         live entry, which covers both a repeat release and a caller passing
         something that was never a URL.

         A refusal the platform does raise on stops here, on the same grounds
         as the mint above and one sharper one: releasing reports no outcome at
         all, so a caller has nothing to inspect and no way to respond. An
         escaping exception would instead abandon whatever sequence of effects
         the release was part of, which is a far larger consequence than the
         unreleased URL it came from. *)
      match Jv.call url_object "revokeObjectURL" [| Jv.of_string url |] with
      | exception _ -> ()
      | _returned -> ())

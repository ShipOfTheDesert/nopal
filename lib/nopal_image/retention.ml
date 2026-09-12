type backend = { release : blob_id:string -> unit }

(* Nothing can have been stored through this backend, so there is nothing it
   could release. *)
let default_backend = { release = (fun ~blob_id:_ -> ()) }

(* Mutable: backend registration lets a platform implementation be injected at
   startup, so application code names the seam and never a platform package. *)
let current_backend = ref default_backend
let register_backend b = current_backend := b

(* [Cmd.perform], not [Cmd.task]: releasing a stored image cannot fail and
   reports nothing, so it dispatches zero messages, and a [Task] would promise
   exactly one. The backend is read here rather than inside the thunk so that a
   command built while one backend is registered cannot be interpreted against
   another. *)
let release ~blob_id =
  let backend = !current_backend in
  Nopal_mvu.Cmd.perform (fun _dispatch -> backend.release ~blob_id)

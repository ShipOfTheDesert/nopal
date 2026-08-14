type error =
  | Blob_not_found of string
  | Url_unavailable of string
  | Backend_unregistered of string

let message = function
  | Blob_not_found detail -> Printf.sprintf "Preview blob not found: %s" detail
  | Url_unavailable detail ->
      Printf.sprintf "Preview URL unavailable: %s" detail
  | Backend_unregistered detail ->
      Printf.sprintf "Preview backend unregistered: %s" detail

type backend = {
  url : blob_id:string -> (string, error) result Nopal_mvu.Task.t;
  revoke : url:string -> unit;
}

let default_backend =
  {
    url =
      (fun ~blob_id:_ ->
        Nopal_mvu.Task.return
          (Error
             (Backend_unregistered
                "no image preview backend was registered for this platform")));
    (* Nothing can have been minted through this backend, so there is nothing it
       could release. *)
    revoke = (fun ~url:_ -> ());
  }

(* Mutable: backend registration lets a platform implementation (nopal_image_web
   is the first) be injected at startup, so application code names the seam and
   never a platform package. *)
let current_backend = ref default_backend
let register_backend b = current_backend := b

let preview_url ~blob_id on_result =
  Nopal_mvu.Cmd.task
    (Nopal_mvu.Task.map on_result (!current_backend.url ~blob_id))

(* [Cmd.perform], not [Cmd.task]: releasing a URL cannot fail and reports
   nothing, so it dispatches zero messages, and a [Task] would promise exactly
   one. The backend is read here rather than inside the thunk so that a command
   built while one backend is registered cannot be interpreted against another,
   matching how the task above captures it. *)
let revoke ~url =
  let backend = !current_backend in
  Nopal_mvu.Cmd.perform (fun _dispatch -> backend.revoke ~url)

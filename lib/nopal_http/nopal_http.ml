type response = {
  status : int;
  body : string;
  headers : (string * string) list;
}

type body =
  | String of { content : string; content_type : string option }
  | Json of string
  | Form_encoded of (string * string) list
  | Multipart of (string * string) list
  | Empty

type error = Network_error of string | Timeout
type outcome = (response, error) result
type meth = GET | POST | PUT | DELETE | PATCH

type request = {
  meth : meth;
  url : string;
  headers : (string * string) list;
  body : body;
  timeout : float option;
}

type backend = { send : request -> outcome Nopal_mvu.Task.t }

type cancellable_backend = {
  send_cancellable :
    request -> Nopal_mvu.Task.cancellation_token * outcome Nopal_mvu.Task.t;
}

let default_backend =
  {
    send =
      (fun request ->
        Nopal_mvu.Task.return
          (Error (Network_error ("no HTTP backend: " ^ request.url))));
  }

(* Mutable: backend registration allows platform-specific HTTP implementations
   (e.g. nopal_http_web) to be injected at startup without coupling application
   code to a specific backend. *)
let current_backend = ref default_backend
let register_backend b = current_backend := b

let make_default_cancellable_send backend request =
  let token, wrapped =
    Nopal_mvu.Task.cancellable (fun _token -> backend.send request)
  in
  let task =
    Nopal_mvu.Task.map
      (function
        | Error "cancelled" -> Error (Network_error "cancelled")
        | Error other -> Error (Network_error other)
        | Ok outcome -> outcome)
      wrapped
  in
  (token, task)

let default_cancellable_backend =
  { send_cancellable = make_default_cancellable_send default_backend }

(* Mutable: cancellable backend registration allows platform-specific
   cancellable HTTP implementations (e.g. nopal_http_web.send_cancellable
   with AbortController) to be injected at startup. *)
let current_cancellable_backend = ref None
let register_cancellable_backend b = current_cancellable_backend := Some b

let send request on_result =
  Nopal_mvu.Cmd.task
    (Nopal_mvu.Task.map on_result (!current_backend.send request))

let get ?(headers = []) ?timeout url on_result =
  send { meth = GET; url; headers; body = Empty; timeout } on_result

let post ?(headers = []) ?timeout ~body url on_result =
  send { meth = POST; url; headers; body; timeout } on_result

let put ?(headers = []) ?timeout ~body url on_result =
  send { meth = PUT; url; headers; body; timeout } on_result

let delete_ ?(body = Empty) ?(headers = []) ?timeout url on_result =
  send { meth = DELETE; url; headers; body; timeout } on_result

let patch ?(headers = []) ?timeout ~body url on_result =
  send { meth = PATCH; url; headers; body; timeout } on_result

let send_cancellable request on_result =
  let token, task =
    match !current_cancellable_backend with
    | Some b -> b.send_cancellable request
    | None -> make_default_cancellable_send !current_backend request
  in
  (token, Nopal_mvu.Cmd.task (Nopal_mvu.Task.map on_result task))

let get_cancellable ?(headers = []) ?timeout url on_result =
  send_cancellable { meth = GET; url; headers; body = Empty; timeout } on_result

let post_cancellable ?(headers = []) ?timeout ~body url on_result =
  send_cancellable { meth = POST; url; headers; body; timeout } on_result

let put_cancellable ?(headers = []) ?timeout ~body url on_result =
  send_cancellable { meth = PUT; url; headers; body; timeout } on_result

let delete_cancellable ?(body = Empty) ?(headers = []) ?timeout url on_result =
  send_cancellable { meth = DELETE; url; headers; body; timeout } on_result

let patch_cancellable ?(headers = []) ?timeout ~body url on_result =
  send_cancellable { meth = PATCH; url; headers; body; timeout } on_result

type response = {
  status : int;
  body : string;
  headers : (string * string) list;
}

type error = Network_error of string
type outcome = (response, error) result
type meth = GET | POST | PUT | DELETE | PATCH

type request = {
  meth : meth;
  url : string;
  headers : (string * string) list;
  body : string;
}

type backend = {
  send : 'msg. request -> (outcome -> 'msg) -> 'msg Nopal_mvu.Cmd.t;
}

let default_backend =
  {
    send =
      (fun request on_result ->
        Nopal_mvu.Cmd.task (fun dispatch ->
            dispatch
              (on_result
                 (Error (Network_error ("no HTTP backend: " ^ request.url))))));
  }

(* Mutable: backend registration allows platform-specific HTTP implementations
   (e.g. nopal_http_web) to be injected at startup without coupling application
   code to a specific backend. *)
let current_backend = ref default_backend
let register_backend b = current_backend := b
let send request on_result = !current_backend.send request on_result

let get ?(headers = []) url on_result =
  send { meth = GET; url; headers; body = "" } on_result

let post url ?(headers = []) ~body on_result =
  send { meth = POST; url; headers; body } on_result

let put url ?(headers = []) ~body on_result =
  send { meth = PUT; url; headers; body } on_result

let delete_ ?(body = "") ?(headers = []) url on_result =
  send { meth = DELETE; url; headers; body } on_result

let patch url ?(headers = []) ~body on_result =
  send { meth = PATCH; url; headers; body } on_result

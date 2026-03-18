type response = { status : int; body : string }
type error = Network_error of string
type outcome = (response, error) result

type backend = {
  get : 'msg. string -> (outcome -> 'msg) -> 'msg Nopal_mvu.Cmd.t;
}

let default_backend =
  {
    get =
      (fun url on_result ->
        Nopal_mvu.Cmd.task (fun dispatch ->
            dispatch
              (on_result (Error (Network_error ("no HTTP backend: " ^ url))))));
  }

(* Mutable: backend registration allows platform-specific HTTP implementations
   (e.g. nopal_http_web) to be injected at startup without coupling application
   code to a specific backend. *)
let current_backend = ref default_backend
let register_backend b = current_backend := b
let get url on_result = !current_backend.get url on_result

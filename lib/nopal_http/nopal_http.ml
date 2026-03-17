type response = { status : int; body : string }
type error = Network_error of string
type outcome = (response, error) result

let get url on_result =
  Nopal_mvu.Cmd.task (fun dispatch ->
      dispatch (on_result (Error (Network_error ("no HTTP backend: " ^ url)))))

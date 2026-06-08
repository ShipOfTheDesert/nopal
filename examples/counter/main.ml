let serialize_msg : Counter.msg -> string = function
  | Counter.Increment -> "Increment"
  | Counter.Decrement -> "Decrement"
  | Counter.Reset -> "Reset"

(* Each field is terminated with ';' so substring assertions can't prefix-alias
   (e.g. "count=1;" does not match "count=10;"). *)
let serialize_model (model : Counter.model) =
  Printf.sprintf "count=%d;" model.Counter.count

let () =
  let open Brr in
  let target =
    match Document.find_el_by_id G.document (Jstr.v "app") with
    | Some el -> el
    | None ->
        let body = Document.body G.document in
        let div = El.div [] in
        El.append_children body [ div ];
        div
  in
  let (_ : Nopal_runtime.Telemetry.handle) =
    Nopal_web.mount_with_telemetry
      (module Counter : Nopal_mvu.App.S
        with type model = Counter.model
         and type msg = Counter.msg)
      ~serialize_msg ~serialize_model target
  in
  ()

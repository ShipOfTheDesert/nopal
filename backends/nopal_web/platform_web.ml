let current_path () =
  let location = Jv.get Jv.global "location" in
  Jv.to_string (Jv.get location "pathname")

let push_state path =
  let history = Jv.get Jv.global "history" in
  ignore
    (Jv.call history "pushState"
       [| Jv.null; Jv.of_string ""; Jv.of_string path |])

let replace_state path =
  let history = Jv.get Jv.global "history" in
  ignore
    (Jv.call history "replaceState"
       [| Jv.null; Jv.of_string ""; Jv.of_string path |])

let back () =
  let history = Jv.get Jv.global "history" in
  ignore (Jv.call history "back" [||])

let on_popstate callback =
  let window = Jv.get Jv.global "window" in
  let listener =
    Jv.callback ~arity:1 (fun _event ->
        let path = current_path () in
        callback path)
  in
  ignore
    (Jv.call window "addEventListener" [| Jv.of_string "popstate"; listener |]);
  fun () ->
    ignore
      (Jv.call window "removeEventListener"
         [| Jv.of_string "popstate"; listener |])

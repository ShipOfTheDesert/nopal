let present v =
  match Jv.is_none v with
  | true -> None
  | false -> Some v

(* Every read here tolerates any value: a rejection reason is whatever the
   platform passed, and a decode that raised inside the rejection callback
   would leave the write unresolved, with nothing left on the stack to catch
   it. *)
let string_field v key =
  match present v with
  | None -> None
  | Some v -> (
      let field = Jv.get v key in
      match Jstr.to_string (Jv.typeof field) with
      | "string" -> Some (Jv.to_string field)
      | _ -> None)

let no_reason = "the clipboard write failed and the platform gave no reason"

(* [String(v)], as [Ipc.error_to_string] does, for a reason that is not an
   object with a message. [String] itself can raise on an exotic value, so the
   conversion is guarded to stay total. *)
let stringified v =
  match present v with
  | None -> None
  | Some v -> (
      match Jv.to_string (Jv.call Jv.global "String" [| v |]) with
      | "" -> None
      | text -> Some text
      | exception _ -> None)

let reason_of v =
  match string_field v "message" with
  | Some message when message <> "" -> message
  | _ -> (
      match stringified v with
      | Some text -> text
      | None -> no_reason)

let error_of_rejection v : Nopal_mvu.Clipboard.error =
  match string_field v "name" with
  | Some "NotAllowedError" -> Not_permitted
  | Some _
  | None ->
      Failed (reason_of v)

let error_of_exn : exn -> Nopal_mvu.Clipboard.error = function
  | Jv.Error e -> Failed (reason_of (Jv.of_error e))
  | e -> Failed (Printexc.to_string e)

let clipboard_with_write_text () =
  let ( let* ) = Option.bind in
  let* navigator = present (Jv.get Jv.global "navigator") in
  let* clipboard = present (Jv.get navigator "clipboard") in
  let* _write_text = present (Jv.get clipboard "writeText") in
  Some clipboard

let write text resolve =
  Nopal_mvu.Task.run
    (Nopal_mvu.Task.guard_once ~on_exn:error_of_exn (fun resolve ->
         match clipboard_with_write_text () with
         | None -> resolve (Error Nopal_mvu.Clipboard.Unavailable)
         | Some clipboard ->
             let promise =
               Jv.call clipboard "writeText" [| Jv.of_string text |]
             in
             let on_fulfilled =
               Jv.callback ~arity:1 (fun _ -> resolve (Ok ()))
             in
             let on_rejected =
               Jv.callback ~arity:1 (fun reason ->
                   resolve (Error (error_of_rejection reason)))
             in
             ignore (Jv.call promise "then" [| on_fulfilled; on_rejected |])))
    resolve

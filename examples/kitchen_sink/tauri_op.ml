module Make (M : sig
  type msg

  val tauri_op_error : string -> msg
end) =
struct
  let ( let* ) task f =
    Nopal_mvu.Task.bind
      (function
        | Ok v -> f v
        | Error e -> Nopal_mvu.Task.return (M.tauri_op_error e))
      task

  let ( let+ ) task f =
    Nopal_mvu.Task.map
      (function
        | Ok v -> f v
        | Error e -> M.tauri_op_error e)
      task
end

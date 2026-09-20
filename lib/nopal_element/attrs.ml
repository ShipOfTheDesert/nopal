let resolve name attrs =
  List.fold_left
    (fun resolved (k, v) -> if String.equal k name then Some v else resolved)
    None attrs

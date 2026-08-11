let wrap f =
  (* Mutable: a one-shot latch over a single wrapped action. It has exactly one
     transition, from unrun to run, and nothing reads it but the call it guards.
     It is set before [f] runs rather than after, so an [f] that raises part way
     through has still had its one turn. *)
  let ran = ref false in
  fun x ->
    match !ran with
    | true -> ()
    | false ->
        ran := true;
        f x

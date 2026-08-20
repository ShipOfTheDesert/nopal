(* A keypress of the Ctrl or Shift key itself carries no prefixes, whichever
   other modifier is held, so one held chord never reports two different names
   depending on which key was struck last. Matching on the key name rather than
   subtracting the pressed modifier's own prefix is what makes that true on the
   cross-modifier events (Ctrl pressed while Shift is down, Shift released while
   Ctrl is still down). Those two are the only exempt names: Alt and Meta are
   not folded, so their own key names take a held prefix like any other key. *)
let of_event ~key ~ctrl ~shift =
  match key with
  | "Control"
  | "Shift" ->
      key
  | _ -> (
      match (ctrl, shift) with
      | false, false -> key
      | true, false -> "Ctrl+" ^ key
      | false, true -> "Shift+" ^ key
      | true, true -> "Ctrl+Shift+" ^ key)

open Nopal_element

type model = { last_key : string; trap_keys : bool }
type msg = Focus_input | Toggle_trap of bool | Key_trapped of string

let init () = ({ last_key = ""; trap_keys = false }, Nopal_mvu.Cmd.none)

let update model msg =
  match msg with
  | Focus_input -> (model, Nopal_mvu.Cmd.focus "demo-input")
  | Toggle_trap checked ->
      ({ model with trap_keys = checked }, Nopal_mvu.Cmd.none)
  | Key_trapped key -> ({ model with last_key = key }, Nopal_mvu.Cmd.none)

let view _vp model =
  Element.column
    ~attrs:[ ("data-testid", "focus-keyboard-section") ]
    [
      Element.button
        ~attrs:[ ("data-testid", "focus-button") ]
        ~on_click:Focus_input
        (Element.text "Focus Input");
      Element.input
        ~attrs:[ ("id", "demo-input"); ("data-testid", "demo-input") ]
        ~placeholder:"Focus target"
        ~on_change:(fun _ -> Focus_input)
        "";
      Element.checkbox
        ~attrs:
          [
            ("data-testid", "trap-toggle"); ("aria-label", "Trap keyboard focus");
          ]
        ~on_toggle:(fun b -> Toggle_trap b)
        model.trap_keys;
      Element.text
        (if model.last_key = "" then "No key trapped yet"
         else "Last key: " ^ model.last_key);
    ]

let subscriptions model =
  if model.trap_keys then
    Nopal_mvu.Sub.on_keydown_prevent "focus-keyboard-trap" (fun key ->
        match key with
        | "Tab" -> Some (Key_trapped "Tab", true)
        | _ -> None)
  else Nopal_mvu.Sub.none

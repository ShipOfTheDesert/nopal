module E = Nopal_element.Element

type step = Step_one | Step_two | Step_three | Summary
type model = { step : step; depth : int }
type msg = Next of step | Jump_to_summary | Back | Route_changed of step

let step_to_string = function
  | Step_one -> "Step_one"
  | Step_two -> "Step_two"
  | Step_three -> "Step_three"
  | Summary -> "Summary"

(* Linear wizard order: [next_step] for the forward control, [prev_step] for the
   back control's optimistic update (corrected by [Route_changed] when the real
   browser history differs, e.g. after a replace). *)
let next_step = function
  | Step_one -> Step_two
  | Step_two -> Step_three
  | Step_three -> Summary
  | Summary -> Summary

let prev_step = function
  | Step_one -> Step_one
  | Step_two -> Step_one
  | Step_three -> Step_two
  | Summary -> Step_three

(* Relative paths so navigation resolves against the document URL, keeping the
   demo working under a mount prefix (e.g. /router_demo/). [parse] matches on the
   final path segment for the same reason. *)
let to_path = function
  | Step_one -> "./"
  | Step_two -> "step-two"
  | Step_three -> "step-three"
  | Summary -> "summary"

let parse path =
  match Filename.basename path with
  | "step-two" -> Some Step_two
  | "step-three" -> Some Step_three
  | "summary" -> Some Summary
  | _ -> None

let init router () =
  let step = Nopal_platform.Router.current router in
  ({ step; depth = 1 }, Nopal_mvu.Cmd.none)

let update router model msg =
  match msg with
  | Next step ->
      ({ step; depth = model.depth + 1 }, Nopal_platform.Router.push router step)
  | Jump_to_summary ->
      ( { step = Summary; depth = model.depth },
        Nopal_platform.Router.replace router Summary )
  | Back ->
      ( { step = prev_step model.step; depth = max 1 (model.depth - 1) },
        Nopal_platform.Router.back router )
  | Route_changed step -> ({ model with step }, Nopal_mvu.Cmd.none)

let subscriptions router _model =
  Nopal_platform.Router.on_navigate router (fun step -> Route_changed step)

(* A wizard nav button: [Nopal_ui.Button] for styling, with the call-site
   interaction anchor on [data-action]. Every config field is set explicitly
   (no [Button.default]-derived record). *)
let nav_button ~action ~msg label =
  Nopal_ui.Button.view
    {
      Nopal_ui.Button.variant = Nopal_ui.Button.Primary;
      disabled = false;
      loading = false;
      on_click = Some msg;
      style = None;
      interaction = None;
      attrs = [ ("data-action", action) ];
    }
    (E.text label)

let view _vp model =
  E.column
    [
      E.text ("Current step: " ^ step_to_string model.step);
      E.text (Printf.sprintf "history depth: %d" model.depth);
      E.row
        [
          nav_button ~action:"wizard-next"
            ~msg:(Next (next_step model.step))
            "Next";
          nav_button ~action:"wizard-back" ~msg:Back "Back";
          nav_button ~action:"wizard-jump-summary" ~msg:Jump_to_summary
            "Jump to Summary";
        ];
    ]

let serialize_msg = function
  | Next step -> "Next " ^ step_to_string step
  | Jump_to_summary -> "Jump_to_summary"
  | Back -> "Back"
  | Route_changed step -> "Route_changed " ^ step_to_string step

(* Each field is terminated with ';' so substring assertions can't prefix-alias
   (e.g. "depth=1;" does not match "depth=10;"). *)
let serialize_model model =
  Printf.sprintf "step=%s; depth=%d;" (step_to_string model.step) model.depth

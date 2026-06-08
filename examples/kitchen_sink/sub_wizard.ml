open Nopal_element
open Nopal_style

(* Visual reference for the router-demo wizard's interaction anchors (RFC 0112).
   The real routed example lives in examples/router_demo; the kitchen sink is a
   single app under /kitchen_sink/, so this section steps through local state
   rather than driving the History API (which would hijack the page URL). It
   carries the same call-site anchors so the wizard interaction is documented
   here per the kitchen-sink-updated-with-every-feature rule. *)

type step = Step_one | Step_two | Step_three | Summary
type model = { step : step; depth : int }
type msg = Next of step | Jump_to_summary | Back

let init () = ({ step = Step_one; depth = 1 }, Nopal_mvu.Cmd.none)

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

let step_name = function
  | Step_one -> "Step One"
  | Step_two -> "Step Two"
  | Step_three -> "Step Three"
  | Summary -> "Summary"

let update model msg =
  let model' =
    match msg with
    | Next step -> { step; depth = model.depth + 1 }
    | Jump_to_summary -> { step = Summary; depth = model.depth }
    | Back -> { step = prev_step model.step; depth = max 1 (model.depth - 1) }
  in
  (model', Nopal_mvu.Cmd.none)

let row_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with cross_align = Some Center; gap = Some 8.0 })

let column_style =
  Style.default |> Style.with_layout (fun l -> { l with gap = Some 8.0 })

let button_style =
  Style.default
  |> Style.with_layout (fun l -> l |> Style.padding 6.0 14.0 6.0 14.0)
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some (Style.hex "#f0eeea");
        border =
          Some
            {
              width = 1.0;
              style = Solid;
              color = Style.hex "#d5d3cf";
              radius = 6.0;
            };
      })
  |> Style.with_text (fun t -> t |> Text.font_weight Font.Semi_bold)

let button_interaction =
  let hover =
    Style.default
    |> Style.with_paint (fun p ->
        { p with background = Some (Style.hex "#e5e3df") })
  in
  { Interaction.default with hover = Some hover }

let nav_button ~action ~msg label =
  Element.button ~style:button_style ~interaction:button_interaction
    ~attrs:[ ("data-action", action) ]
    ~on_click:msg (Element.text label)

let step_text =
  Text.default |> Text.font_weight Font.Bold |> Text.font_family System_ui

let view _vp model =
  Element.column ~style:column_style
    [
      Element.styled_text ~text_style:step_text
        ("Current step: " ^ step_name model.step);
      Element.text (Printf.sprintf "history depth: %d" model.depth);
      Element.row ~style:row_style
        [
          nav_button ~action:"wizard-next"
            ~msg:(Next (next_step model.step))
            "Next";
          nav_button ~action:"wizard-back" ~msg:Back "Back";
          nav_button ~action:"wizard-jump-summary" ~msg:Jump_to_summary
            "Jump to Summary";
        ];
    ]

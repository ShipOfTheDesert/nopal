open Nopal_element
open Nopal_style

type model = {
  checkbox_on : bool;
  selected_radio : string;
  selected_option : string;
}

type msg =
  | Toggle_checkbox of bool
  | Select_radio of string
  | Change_select of string

let init () =
  ( { checkbox_on = false; selected_radio = "opt-a"; selected_option = "val-1" },
    Nopal_mvu.Cmd.none )

let update model msg =
  match msg with
  | Toggle_checkbox v -> ({ model with checkbox_on = v }, Nopal_mvu.Cmd.none)
  | Select_radio v -> ({ model with selected_radio = v }, Nopal_mvu.Cmd.none)
  | Change_select v -> ({ model with selected_option = v }, Nopal_mvu.Cmd.none)

let label_text =
  Text.default |> Text.font_size 0.9 |> Text.font_family System_ui

let row_style =
  Style.default
  |> Style.with_layout (fun l -> { l with gap = 12.0; cross_align = Center })

let group_style =
  Style.default |> Style.with_layout (fun l -> { l with gap = 8.0 })

let view _vp model =
  Element.column ~style:group_style
    ~attrs:[ ("data-testid", "form-section") ]
    [
      (* Togglable checkbox *)
      Element.row ~style:row_style
        [
          Element.checkbox
            ~attrs:
              [ ("data-testid", "form-checkbox"); ("aria-label", "Toggle") ]
            ~on_toggle:(fun v -> Toggle_checkbox v)
            model.checkbox_on;
          Element.styled_text ~text_style:label_text
            (if model.checkbox_on then "Checked" else "Unchecked");
        ];
      (* Disabled checkbox *)
      Element.row ~style:row_style
        [
          Element.checkbox
            ~attrs:
              [
                ("data-testid", "form-checkbox-disabled");
                ("aria-label", "Disabled toggle");
              ]
            ~disabled:true true;
          Element.styled_text ~text_style:label_text "Disabled checkbox";
        ];
      (* Radio group: 3 options, 1 disabled *)
      Element.column ~style:group_style
        [
          Element.styled_text ~text_style:label_text "Radio group:";
          Element.row ~style:row_style
            [
              Element.radio ~name:"form-radio"
                ~attrs:
                  [
                    ("data-testid", "form-radio-a"); ("aria-label", "Option A");
                  ]
                ~checked:(String.equal model.selected_radio "opt-a")
                ~on_select:(Select_radio "opt-a") ();
              Element.styled_text ~text_style:label_text "Option A";
            ];
          Element.row ~style:row_style
            [
              Element.radio ~name:"form-radio"
                ~attrs:
                  [
                    ("data-testid", "form-radio-b"); ("aria-label", "Option B");
                  ]
                ~checked:(String.equal model.selected_radio "opt-b")
                ~on_select:(Select_radio "opt-b") ();
              Element.styled_text ~text_style:label_text "Option B";
            ];
          Element.row ~style:row_style
            [
              Element.radio ~name:"form-radio"
                ~attrs:
                  [
                    ("data-testid", "form-radio-c"); ("aria-label", "Option C");
                  ]
                ~checked:(String.equal model.selected_radio "opt-c")
                ~disabled:true ();
              Element.styled_text ~text_style:label_text "Option C (disabled)";
            ];
        ];
      (* Select *)
      Element.column ~style:group_style
        [
          Element.styled_text ~text_style:label_text "Select:";
          Element.select
            ~attrs:
              [ ("data-testid", "form-select"); ("aria-label", "Select value") ]
            ~on_change:(fun v -> Change_select v)
            ~selected:model.selected_option
            [
              Element.select_option ~value:"val-1" "Value 1";
              Element.select_option ~value:"val-2" "Value 2";
              Element.select_option ~value:"val-3" ~disabled:true
                "Value 3 (disabled)";
            ];
        ];
      (* Disabled select *)
      Element.column ~style:group_style
        [
          Element.styled_text ~text_style:label_text "Disabled select:";
          Element.select
            ~attrs:
              [
                ("data-testid", "form-select-disabled");
                ("aria-label", "Disabled select");
              ]
            ~disabled:true ~selected:"val-1"
            [
              Element.select_option ~value:"val-1" "Value 1";
              Element.select_option ~value:"val-2" "Value 2";
            ];
        ];
    ]

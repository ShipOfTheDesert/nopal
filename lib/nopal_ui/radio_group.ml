module E = Nopal_element.Element

type radio_option = { label : string; value : string; disabled : bool }

type 'msg inputs =
  | Visible_inputs of { on_label_click : (string -> 'msg) option }
  | Hidden_inputs

type 'msg config = {
  label : string;
  options : radio_option list;
  selected : string;
  disabled : bool;
  name : string option;
  on_select : (string -> 'msg) option;
  style : Nopal_style.Style.t option;
  interaction : Nopal_style.Interaction.t option;
  attrs : (string * string) list;
  id : string option;
  visible_label : bool option;
  label_style : Nopal_style.Style.t option;
  group_style : Nopal_style.Style.t option;
  options_style : Nopal_style.Style.t option;
  option_label_style : Nopal_style.Style.t option;
  option_row_style : Nopal_style.Style.t option;
  option_row_interaction : Nopal_style.Interaction.t option;
  inputs : 'msg inputs;
}

let radio_option ?(disabled = false) ~value label = { label; value; disabled }

let make ~label ~options ~selected =
  {
    label;
    options;
    selected;
    disabled = false;
    name = None;
    on_select = None;
    style = None;
    interaction = None;
    attrs = [];
    id = None;
    visible_label = None;
    label_style = None;
    group_style = None;
    options_style = None;
    option_label_style = None;
    option_row_style = None;
    option_row_interaction = None;
    inputs = Visible_inputs { on_label_click = None };
  }

let with_id id config = { config with id = Some id }

let with_visible_label visible config =
  { config with visible_label = Some visible }

let with_label_style style config = { config with label_style = Some style }
let with_group_style style config = { config with group_style = Some style }
let with_options_style style config = { config with options_style = Some style }

let with_option_label_style style config =
  { config with option_label_style = Some style }

let with_option_row_style style config =
  { config with option_row_style = Some style }

let with_option_row_interaction interaction config =
  { config with option_row_interaction = Some interaction }

let with_hidden_inputs config = { config with inputs = Hidden_inputs }

let with_on_label_click f config =
  match config.inputs with
  | Visible_inputs _ ->
      { config with inputs = Visible_inputs { on_label_click = Some f } }
  | Hidden_inputs -> config

let semantics config =
  Radio_semantics.make ~id:config.id ~label:config.label ~name:config.name

let control_id config = Radio_semantics.control_id (semantics config)

let option_id config ~value =
  Radio_semantics.option_id (semantics config) ~value

let view config =
  let group = semantics config in
  let render_option (opt : radio_option) =
    let disabled = config.disabled || opt.disabled in
    let label_text =
      [ Text_node.of_style ~style:config.option_label_style opt.label ]
    in
    let presentation, label =
      match config.inputs with
      | Visible_inputs { on_label_click } ->
          ( Nopal_style.Presentation.Visible,
            E.box ?style:config.option_label_style
              ~attrs:
                [
                  ("id", Radio_semantics.option_label_id group ~value:opt.value);
                ]
              ?on_pointer_down:
                (Option.map (fun f _event -> f opt.value) on_label_click)
              label_text )
      | Hidden_inputs ->
          ( Nopal_style.Presentation.Visually_hidden,
            Radio_semantics.option_label ?style:config.option_label_style group
              ~value:opt.value label_text )
    in
    let radio =
      Radio_semantics.option_radio ?style:config.style
        ?interaction:config.interaction group ~value:opt.value
        ~selected:config.selected ~disabled ~presentation
        ~on_select:config.on_select
    in
    E.row ?style:config.option_row_style
      ?interaction:config.option_row_interaction [ radio; label ]
  in
  let options_box =
    E.box ?style:config.options_style (List.map render_option config.options)
  in
  let naming, children =
    match config.visible_label with
    | Some true ->
        let group_label =
          E.box ?style:config.label_style
            ~attrs:[ ("id", Radio_semantics.group_label_id group) ]
            [ Text_node.of_style ~style:config.label_style config.label ]
        in
        (Radio_semantics.Named_by_visible_label, [ group_label; options_box ])
    | Some false
    | None ->
        (Radio_semantics.Named_by_aria_label, [ options_box ])
  in
  E.box ?style:config.group_style
    ~attrs:(Radio_semantics.group_attrs group ~naming ~attrs:config.attrs)
    children

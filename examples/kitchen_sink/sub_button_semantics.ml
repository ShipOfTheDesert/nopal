open Nopal_element
open Nopal_style
module Button = Nopal_ui.Button

type field_set = Text | Password | Text_text | Text_password

type button_state =
  | Submit_enabled
  | Submit_disabled
  | Push_enabled
  | No_button
  | Disabled_submit_before_enabled_submit

let equal_field_set a b =
  match (a, b) with
  | Text, Text
  | Password, Password
  | Text_text, Text_text
  | Text_password, Text_password ->
      true
  | (Text | Password | Text_text | Text_password), _ -> false

let equal_button_state a b =
  match (a, b) with
  | Submit_enabled, Submit_enabled
  | Submit_disabled, Submit_disabled
  | Push_enabled, Push_enabled
  | No_button, No_button
  | Disabled_submit_before_enabled_submit, Disabled_submit_before_enabled_submit
    ->
      true
  | ( ( Submit_enabled | Submit_disabled | Push_enabled | No_button
      | Disabled_submit_before_enabled_submit ),
      _ ) ->
      false

let field_sets = [ Text; Password; Text_text; Text_password ]

let button_states =
  [
    Submit_enabled;
    Submit_disabled;
    Push_enabled;
    No_button;
    Disabled_submit_before_enabled_submit;
  ]

let field_set_to_string = function
  | Text -> "text"
  | Password -> "password"
  | Text_text -> "text-text"
  | Text_password -> "text-password"

let button_state_to_string = function
  | Submit_enabled -> "submit-enabled"
  | Submit_disabled -> "submit-disabled"
  | Push_enabled -> "push-enabled"
  | No_button -> "none"
  | Disabled_submit_before_enabled_submit ->
      "disabled-submit-before-enabled-submit"

type dispatch = Button_1_clicked | Button_2_clicked | Submitted

let dispatch_token = function
  | Button_1_clicked -> "C1"
  | Button_2_clicked -> "C2"
  | Submitted -> "S"

type msg =
  | Field_set_selected of field_set
  | Button_state_selected of button_state
  | Dispatched of dispatch
  | Save_clicked
  | Save_submitted

type model = {
  field_set : field_set;
  button_state : button_state;
  dispatched : dispatch list;
  saving : bool;
}

let init () =
  ( {
      field_set = Text;
      button_state = Submit_enabled;
      dispatched = [];
      saving = false;
    },
    Nopal_mvu.Cmd.none )

let update model msg =
  match msg with
  | Field_set_selected field_set ->
      ({ model with field_set; dispatched = [] }, Nopal_mvu.Cmd.none)
  | Button_state_selected button_state ->
      ({ model with button_state; dispatched = [] }, Nopal_mvu.Cmd.none)
  | Dispatched dispatch ->
      ( { model with dispatched = dispatch :: model.dispatched },
        Nopal_mvu.Cmd.none )
  | Save_clicked -> (model, Nopal_mvu.Cmd.none)
  | Save_submitted -> ({ model with saving = true }, Nopal_mvu.Cmd.none)

let testid suffix = ("data-testid", "button-semantics-" ^ suffix)

(* Layout fields are all options, so starting from the default layout inherits
   no opinion about anything but the gap and wrapping named here. *)
let column_style gap =
  Style.default |> Style.with_layout (fun l -> { l with gap = Some gap })

let row_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = Some 8.0; cross_align = Some Center; wrap = Some true })

let selector ~testid_suffix ~label ~current msg =
  Element.button
    ~attrs:[ testid testid_suffix; ("aria-pressed", Bool.to_string current) ]
    ~button_type:Element.Push ~on_click:msg (Element.text label)

let selector_row ~label values ~to_string ~prefix ~current ~selected =
  Element.row ~style:row_style
    (Element.text label
    :: List.map
         (fun value ->
           selector
             ~testid_suffix:(prefix ^ to_string value)
             ~label:(to_string value) ~current:(current value) (selected value))
         values)

let field ~index input_type =
  let name = Printf.sprintf "field-%d" index in
  Element.input
    ~attrs:[ testid name; ("aria-label", Printf.sprintf "Field %d" index) ]
    ~input_type ""

let fields field_set =
  match field_set with
  | Text -> [ field ~index:1 Element.Plain ]
  | Password -> [ field ~index:1 Element.Password ]
  | Text_text -> [ field ~index:1 Element.Plain; field ~index:2 Element.Plain ]
  | Text_password ->
      [ field ~index:1 Element.Plain; field ~index:2 Element.Password ]

(* Every behavioural field of the component's config is set here rather than
   inherited from its default, so the button is exactly the one its state
   names. *)
let form_button ~index ~label ~disabled ~button_type dispatch =
  Button.view
    ({
       (Button.default Button.Primary) with
       disabled;
       loading = false;
       on_click = Some (Dispatched dispatch);
       attrs = [ testid (Printf.sprintf "button-%d" index) ];
     }
    |> Button.with_button_type button_type)
    (Element.text label)

let buttons button_state =
  match button_state with
  | Submit_enabled ->
      [
        form_button ~index:1 ~label:"Submit" ~disabled:false
          ~button_type:Element.Submit Button_1_clicked;
      ]
  | Submit_disabled ->
      [
        form_button ~index:1 ~label:"Submit (disabled)" ~disabled:true
          ~button_type:Element.Submit Button_1_clicked;
      ]
  | Push_enabled ->
      [
        form_button ~index:1 ~label:"Push" ~disabled:false
          ~button_type:Element.Push Button_1_clicked;
      ]
  | No_button -> []
  | Disabled_submit_before_enabled_submit ->
      [
        form_button ~index:1 ~label:"Submit (disabled)" ~disabled:true
          ~button_type:Element.Submit Button_1_clicked;
        form_button ~index:2 ~label:"Submit" ~disabled:false
          ~button_type:Element.Submit Button_2_clicked;
      ]

let dispatched_text dispatched =
  match List.rev_map dispatch_token dispatched with
  | [] -> "Dispatched since the last selection: nothing"
  | tokens ->
      "Dispatched since the last selection: " ^ String.concat ", " tokens

let save_form saving =
  Element.form ~style:(column_style 8.0)
    ~attrs:[ testid "save-form"; ("aria-label", "Save") ]
    ~on_submit:Save_submitted
    [
      Element.text
        "A save button that disables itself: submitting starts a save that \
         never ends, and a pending save disables the button.";
      Button.view
        ({
           (Button.default Button.Primary) with
           disabled = saving;
           loading = false;
           on_click = Some Save_clicked;
           attrs = [ testid "save-button" ];
         }
        |> Button.with_button_type Element.Submit)
        (Element.text "Save");
    ]

let view _vp model =
  Element.column ~style:(column_style 12.0)
    [
      Element.text
        "Choose the form's fields and buttons, then click a button or press \
         Enter in a field. C1 and C2 are the on_click of button 1 and button \
         2, and S is the form's on_submit.";
      selector_row ~label:"Fields" field_sets ~to_string:field_set_to_string
        ~prefix:"fields-"
        ~current:(fun field_set -> equal_field_set field_set model.field_set)
        ~selected:(fun field_set -> Field_set_selected field_set);
      selector_row ~label:"Buttons" button_states
        ~to_string:button_state_to_string ~prefix:"buttons-"
        ~current:(fun button_state ->
          equal_button_state button_state model.button_state)
        ~selected:(fun button_state -> Button_state_selected button_state);
      (* The accessible name travels as an attribute pair: a form is exposed
         as a landmark only once it has one, and no typed field carries it. *)
      Element.form ~style:(column_style 8.0)
        ~attrs:[ testid "form"; ("aria-label", "Button semantics") ]
        ~on_submit:(Dispatched Submitted)
        (fields model.field_set @ buttons model.button_state);
      Element.box
        ~attrs:[ testid "dispatched" ]
        [ Element.text (dispatched_text model.dispatched) ];
      save_form model.saving;
    ]

let serialize_msg msg =
  match msg with
  | Field_set_selected field_set ->
      "ButtonSemantics:fields=" ^ field_set_to_string field_set ^ ";"
  | Button_state_selected button_state ->
      "ButtonSemantics:buttons=" ^ button_state_to_string button_state ^ ";"
  | Dispatched dispatch -> "ButtonSemantics:" ^ dispatch_token dispatch ^ ";"
  | Save_clicked -> "ButtonSemantics:save=C;"
  | Save_submitted -> "ButtonSemantics:save=S;"

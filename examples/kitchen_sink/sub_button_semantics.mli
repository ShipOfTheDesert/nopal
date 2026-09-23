(** What a button inside a form dispatches — kitchen sink subapp.

    The section is one form whose fields and buttons are chosen by two rows of
    selectors outside it, so every combination of a field set and a button state
    can be put on the page and then clicked or pressed Enter in. The form's
    buttons are {!Nopal_ui.Button}s, so what the page shows is what a caller of
    that component gets.

    The answers the section gives are the ones the matrix in
    [test/e2e/fixtures/button-submit-matrix.tsv] states, and that file's
    vocabulary is the section's: each field set and button state is named there
    by its {!field_set_to_string} and {!button_state_to_string}, and each
    dispatch by the token {!serialize_msg} carries — [C1] and [C2] for the
    [on_click] of button 1 and button 2, [S] for the form's [on_submit].

    The selectors are push buttons outside the form, so choosing a cell never
    submits anything. Below the form, the section lists what the form has
    dispatched since the last selection.

    Apart from the matrix, a second form holds a save button that disables
    itself: submitting the form starts a save that stays pending, and a pending
    save renders the button disabled. It is the case of a button disabled by its
    own activation, which must keep focus. *)

(** The form's fields, in tree order. Every field is an input, and so every
    field counts toward the rule that a form with several fields and no submit
    button ignores Enter. *)
type field_set =
  | Text  (** One text field. *)
  | Password  (** One password field. *)
  | Text_text  (** Two text fields. *)
  | Text_password  (** A text field, then a password field. *)

(** The form's buttons. Button 1 is the form's first button. *)
type button_state =
  | Submit_enabled  (** Button 1 submits the form. *)
  | Submit_disabled  (** Button 1 submits the form, and is disabled. *)
  | Push_enabled  (** Button 1 does only what its [on_click] says. *)
  | No_button  (** The form has no button. *)
  | Disabled_submit_before_enabled_submit
      (** Button 1 submits the form and is disabled, and button 2, after it,
          submits the form and is enabled. *)

val field_sets : field_set list
(** Every field set, in the order the selectors show them. *)

val button_states : button_state list
(** Every button state, in the order the selectors show them. *)

val field_set_to_string : field_set -> string
(** The matrix's name for a field set: [text], [password], [text-text] or
    [text-password]. *)

val button_state_to_string : button_state -> string
(** The matrix's name for a button state: [submit-enabled], [submit-disabled],
    [push-enabled], [none] or [disabled-submit-before-enabled-submit]. *)

(** What the form dispatches. *)
type dispatch =
  | Button_1_clicked  (** Button 1's [on_click]. *)
  | Button_2_clicked  (** Button 2's [on_click]. *)
  | Submitted  (** The form's [on_submit]. *)

(** The subapp's messages. *)
type msg =
  | Field_set_selected of field_set  (** A field-set selector was pressed. *)
  | Button_state_selected of button_state
      (** A button-state selector was pressed. *)
  | Dispatched of dispatch  (** The form dispatched something. *)
  | Save_clicked  (** The save button's [on_click]. *)
  | Save_submitted  (** The save form's [on_submit]. *)

type model = {
  field_set : field_set;  (** The fields the form renders. *)
  button_state : button_state;  (** The buttons the form renders. *)
  dispatched : dispatch list;
      (** What the form has dispatched since the last selection, newest first. A
          selection empties it. *)
  saving : bool;
      (** Whether the save form has been submitted. Nothing ends a save, so once
          set it stays set. *)
}
(** The subapp model. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** One text field, an enabled submit button, nothing dispatched, no save
    pending. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** A selection switches the form and empties the dispatch list. A form message
    is added to the list. The save form's submission sets [saving], and its
    button's click changes nothing. No command is ever produced. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** Renders the selectors, the form, the dispatch list and the save form. Every
    element a browser case reaches carries a [data-testid] built from the
    matrix's vocabulary: [button-semantics-fields-<field set>] and
    [button-semantics-buttons-<button state>] for the selectors, each with
    [aria-pressed] saying whether it is the current choice;
    [button-semantics-form]; [button-semantics-field-1] and
    [button-semantics-field-2]; [button-semantics-button-1] and
    [button-semantics-button-2]; [button-semantics-dispatched]; and
    [button-semantics-save-form] and [button-semantics-save-button]. A matrix
    action [click-button-N] or [enter-field-N] names its target by the same
    suffix. *)

val serialize_msg : msg -> string
(** Telemetry serializer, prefixed with [ButtonSemantics:] and terminated with
    [;] so one message cannot prefix-alias another. A form message carries the
    matrix's token — [ButtonSemantics:C1;], [ButtonSemantics:C2;] or
    [ButtonSemantics:S;] — and a selection carries the name of what was
    selected, as [ButtonSemantics:fields=<field set>;] or
    [ButtonSemantics:buttons=<button state>;]. The save form's messages are
    [ButtonSemantics:save=C;] and [ButtonSemantics:save=S;]. *)

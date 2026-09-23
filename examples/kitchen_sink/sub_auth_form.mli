(** An auth-shaped form: Enter from any field submits it once — kitchen sink
    subapp.

    {b This is a demo with no authentication.} Nothing is sent anywhere and
    nothing is checked. The password field's value lives in the model like any
    other input's value, which is what an MVU input is; this section is the
    shape of a sign-in form, and it is not a pattern for handling credentials.

    The section is one form holding an email field, a password field, a one-time
    code field and a submit button. The form carries the submit message, so an
    Enter in the email or password field and a press of the button all dispatch
    the same message, once, and the page does not navigate. The fields declare
    what they are through the typed input fields — kind, autofill token and
    whether they are required — rather than through raw attribute pairs, and the
    form carries an accessible name, which is what makes a form a landmark to
    assistive technology.

    The one-time code field is there to show the other half of the submit
    contract: it answers Enter with a message of its own, and an Enter a field
    answers is consumed there and never goes on to submit the form. Every other
    key it declines, so typing into it is unaffected.

    A control outside the form switches the form's validation off and on, so a
    browser can be shown both answers to an empty required field: the submission
    is blocked while validation is on, and goes through while it is off. *)

type model = {
  email : string;  (** The email field's current value. *)
  password : string;
      (** The password field's current value. Held in the model like any other
          input's, and never reported: the telemetry serializer reports only its
          length. *)
  code : string;  (** The one-time code field's current value. *)
  code_confirms : int;
      (** How many Enters the one-time code field has consumed. *)
  submits : int;  (** How many times the form has been submitted. *)
  novalidate : bool;
      (** Whether the form skips the platform's validation. [false] by default,
          so an empty required field blocks a submission. *)
}
(** The subapp model. *)

(** The subapp's messages. *)
type msg =
  | Email_changed of string  (** The email field's new value. *)
  | Password_changed of string  (** The password field's new value. *)
  | Code_changed of string  (** The one-time code field's new value. *)
  | Code_confirmed
      (** Enter in the one-time code field, answered by that field's own keydown
          handler rather than by the form. *)
  | Submitted  (** The form was submitted. *)
  | Novalidate_toggled of bool
      (** The validation control: [true] makes the form skip validation. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** Empty fields, no submissions, validation on. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** Records a field's value, counts a submission or a confirmation, or sets the
    validation flag. No command is ever produced. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** Renders the demo notice, the validation control, the form and the two
    counters. Every element a browser case reaches carries a [data-testid]:
    [auth-form], [auth-email], [auth-password], [auth-code], [auth-submit],
    [auth-novalidate], [auth-submit-count] and [auth-code-count]. *)

val serialize_model : model -> string
(** Telemetry serializer. Each field is prefixed with [auth_] so it cannot
    collide with another section's fragments, and terminated with [;] so a count
    of 1 cannot prefix-alias a count of 12. The password is reported by its
    length only. *)

val serialize_msg : msg -> string
(** Telemetry serializer for the section's messages, also [;]-terminated and
    prefixed with [AuthForm:]. A field's value is not carried: the model
    fragment reports it. Lives here rather than at the entry point so the
    message and model fragments stay described by one module. *)

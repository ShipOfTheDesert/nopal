(** What Chromium dispatches (measured), when a button is clicked, or when an
    Enter in a field is left to the form, inside an
    {!Nopal_element.Element.form}.

    Pure and native: this is the platform's share of a submission, restated over
    an element tree so that the structural renderer answers what Chromium
    answers, as measured. The web renderer does not call it, because there the
    browser itself applies these rules.

    This module lives in the [nopal_test.internal] library: it is not API and
    carries no stability promise.

    Two browser rules are modelled.

    - {b A click on a submit button submits its form.} The button's [on_click]
      is dispatched, and then the form's [on_submit]. A push button dispatches
      its [on_click] alone, and a disabled button dispatches nothing.
    - {b Implicit submission.} An Enter that no handler on the field answered
      clicks the form's default button: the first submit button in tree order,
      disabled or not. That click dispatches exactly what {!click} says, so a
      disabled default button blocks the Enter even when an enabled submit
      button follows it. With no submit button, the form submits only when it
      holds at most one field that blocks implicit submission.

    Known limitations:
    - Every {!Nopal_element.Element.input} counts as a blocking field, whatever
      its [input_type], and no [Checkbox], [Radio], [Select] or [File_input]
      counts. The count reads the typed field only. An input whose type a caller
      overrides through [~attrs] to one the browser does not count, such as
      ["hidden"], is still counted here.
    - A native [disabled] pair set through [~attrs] on a button is outside this
      model: it reads only the typed [disabled] field, so the browser treats
      such a button as disabled while this model answers it as enabled.
    - Constraint validation is not modelled. The browser's own validation
      ([required], [pattern], and the like, on a form without [novalidate]) can
      block a submission that this model reports as dispatched.
    - Keyboard activation of a focused button (Enter or Space on the button
      itself) is not modelled. Only an Enter in a field is.
    - A form nested inside another is not walked into: its controls belong to
      it, not to the outer form. Nested forms are unsupported. *)

val click :
  button_type:Nopal_element.Element.button_type ->
  disabled:bool ->
  on_click:'msg option ->
  form_submit:'msg option ->
  'msg list
(** [click ~button_type ~disabled ~on_click ~form_submit] is every message a
    click on a button dispatches, in dispatch order. [on_click] is the button's
    own handler. [form_submit] is the [on_submit] of the nearest enclosing form,
    and [None] both when no form encloses the button and when the form authors
    none, because either way the form dispatches nothing.

    A disabled button answers [[]]. An enabled [Push] button answers its
    [on_click]. An enabled [Submit] button answers its [on_click] and then
    [form_submit]. An absent handler contributes nothing. *)

val deferred_enter :
  on_submit:'msg option -> 'msg Nopal_element.Element.t list -> 'msg list
(** [deferred_enter ~on_submit children] is every message dispatched, in
    dispatch order, by an Enter in a field that the field's own handlers left to
    a form holding [children] and authoring [on_submit].

    When [children] hold a submit button, the first in tree order is the default
    button and the answer is {!click} on it. Otherwise the answer is [on_submit]
    when [children] hold at most one blocking field, and [[]] when they hold
    more. The rendered rows of a [Virtual_list] are walked, and no other rows
    are. *)

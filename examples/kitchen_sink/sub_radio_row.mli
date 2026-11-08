(** A radio group in a row — kitchen sink section.

    A {!Nopal_ui.Radio_group} built with [make], the setters, and
    [{ config with on_select; attrs }] for the message and the test anchor: a
    visible label above three options laid out side by side. The group's own
    style is a column with a gap between the label and the options, and the
    options' style is a row with a gap between options. The group carries
    [data-testid="radio-row-group"] and the id [radio-row-size], so its options
    are [radio-row-size-small], [radio-row-size-medium] and
    [radio-row-size-large], and its label is [radio-row-size-label].

    The group sits between two buttons that do nothing,
    [data-testid="radio-row-before"] and [data-testid="radio-row-after"], so a
    browser can show that Tab crosses the whole group in one stop. *)

type model
(** The selected option's value. *)

(** The section's messages. *)
type msg = Selected of string  (** The option with this value was selected. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** [medium] selected, so the checked radio is not the group's first. No
    command. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** [Selected value] makes [value] the selected option. No command. *)

val view : model -> msg Nopal_element.Element.t
(** The button before the group, the group, and the button after it. *)

val serialize_msg : msg -> string
(** Telemetry serializer for the section's messages, prefixed with [RadioRow:]
    and terminated with [;] so one fragment cannot prefix-alias another: for
    example [RadioRow:Selected:large;]. *)

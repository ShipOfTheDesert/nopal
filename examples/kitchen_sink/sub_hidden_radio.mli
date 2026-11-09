(** A radio group with hidden inputs and ringed rows — kitchen sink section.

    A {!Nopal_ui.Radio_group} built with [make] and the setters, with
    [{ config with on_select }] for the message: a visible label above three
    options laid out side by side, whose radios are visually hidden
    ({!Nopal_ui.Radio_group.with_hidden_inputs}). Each option's label is a
    native label for its radio, so a pointer press on it selects and focuses
    that radio. Each option row has padding and a 1 px hairline border, and
    shows a 2 px ring while its radio has focus: a [focused_within] style
    ({!Nopal_ui.Radio_group.with_option_row_interaction}) whose shadow has zero
    offset, zero blur, a spread of 2 and the colour [rgba(2, 64, 58, 0.5)],
    which a browser computes as [rgba(2, 64, 58, 0.5) 0px 0px 0px 2px]. A row
    shows no shadow otherwise.

    The group carries the id [hidden-radio-shipping], so its options are
    [hidden-radio-shipping-standard], [hidden-radio-shipping-express] and
    [hidden-radio-shipping-overnight], each option's label is that id followed
    by [-label], and the group's label is [hidden-radio-shipping-label]. The
    group carries no attributes of its own.

    The group sits between two buttons that do nothing,
    [data-testid="hidden-radio-before"] and [data-testid="hidden-radio-after"],
    so a browser can show that Tab crosses the whole group in one stop. *)

type model
(** The selected option's value. *)

(** The section's messages. *)
type msg = Selected of string  (** The option with this value was selected. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** [express] selected, so the checked radio is not the group's first. No
    command. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** [Selected value] makes [value] the selected option. No command. *)

val view : model -> msg Nopal_element.Element.t
(** The button before the group, the group, and the button after it. *)

val serialize_msg : msg -> string
(** Telemetry serializer for the section's messages, prefixed with
    [HiddenRadio:] and terminated with [;] so one fragment cannot prefix-alias
    another: for example [HiddenRadio:Selected:overnight;]. *)

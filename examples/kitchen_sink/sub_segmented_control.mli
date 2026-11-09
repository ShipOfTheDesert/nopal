(** Segmented controls — kitchen sink section.

    Three {!Nopal_ui.Segmented_control}s built with [make] and the setters
    alone, all styled alike:
    - the segments box has a 1 px solid outline of [#948775] with radius 6, and
      lays its segments out in a row;
    - every divider is 1 px wide and filled with [#CFC6B8];
    - every segment is 38 px high and lays its radio and label out in a row; the
      label centres its text and has 12 px of horizontal padding;
    - the selected segment is filled with [#02403A], and its label is coloured
      [#FFFDF9] with weight 500 ([Medium]);
    - every segment shows a 2 px ring while its radio has focus: a
      [focused_within] style whose shadow has zero offset, zero blur, a spread
      of 2 and the colour [rgba(11, 97, 88, 0.35)], which a browser computes as
      [rgba(11, 97, 88, 0.35) 0px 0px 0px 2px]. Its layer is the control's
      default, [z-index] 1.

    Each control's label sits above its segments. The controls, with their ids,
    labels and segments (value, then the text it shows), in order:
    - [segmented-threshold], labelled ["Alert threshold"]: [none] ["None"],
      [15m] ["15 min"], [1h] ["1 hour"], [1d] ["1 day"], [custom] ["Custom"].
      [1h] starts selected.
    - [segmented-window], labelled ["Time window"]: [7d] ["7d"], [30d] ["30d"],
      [90d] ["90d"], [all] ["All"]. [30d] starts selected.
    - [segmented-refusing], labelled ["Refusing control"]: [kept] ["Kept"],
      [refused] ["Refused"]. [kept] starts selected, and its update refuses
      every selection, so it stays on [kept]: pressing ["Refused"] dispatches
      the message, and the control is then drawn and checked on [kept] again.

    Each radio's id is the control's id, a hyphen and the value, for example
    [segmented-threshold-15m]; its label's id is that followed by [-label]; and
    the control's label box is the control's id followed by [-label]. The radios
    of each control share the slugified label as their name: [alert-threshold],
    [time-window] and [refusing-control].

    The controls sit between two buttons that do nothing,
    [data-testid="segmented-control-before"] and
    [data-testid="segmented-control-after"], so a browser can show that Tab
    crosses each control in one stop. *)

type model
(** The selected value of the threshold and of the window selector, and the
    refusing control's value, which never changes. *)

(** The section's messages, one per control. Each carries the value selected. *)
type msg =
  | Threshold_selected of string  (** A threshold segment was selected. *)
  | Window_selected of string  (** A window segment was selected. *)
  | Refusing_selected of string
      (** A segment of the refusing control was selected. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** [1h], [30d] and [kept] selected, so no control's checked radio is its last.
    No command. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** [Threshold_selected value] and [Window_selected value] make [value] that
    control's selection. [Refusing_selected _] returns the model unchanged. No
    command. *)

val view : model -> msg Nopal_element.Element.t
(** The button before the controls, the three controls in the order above, and
    the button after them. *)

val serialize_msg : msg -> string
(** Telemetry serializer for the section's messages: [SegmentedControl:], the
    constructor's name, a colon, the value and [;], so one fragment cannot
    prefix-alias another. For example [SegmentedControl:Threshold_selected:15m;]
    and [SegmentedControl:Refusing_selected:refused;]. *)

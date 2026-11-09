(** Switches — kitchen sink section.

    Three {!Nopal_ui.Switch}es built with [make] and the setters alone, each
    labelled ["Send an alert when it goes silent"]. Their ids and starting
    states, in page order:
    - [switch-starts-on]: on. Its hint, in the box [switch-starts-on-hint], is
      ["Delivering to alerts.example.com"].
    - [switch-starts-off]: off, with no hint.
    - [switch-disabled]: off and disabled. Its reason, in the box
      [switch-disabled-reason], is ["Needs a silence threshold."]. Its hint, in
      the box [switch-disabled-hint], is a row: the text
      ["Off, so alerts are being dropped."] and then a link,
      [data-testid="switch-dropped-alerts-link"], reading
      ["See the dropped alerts"] and pointing at the [Dropped_alerts] route. The
      button is described by the reason and then the hint.

    The switches keep their default track and knob. Each declares its own focus
    ring with {!Nopal_ui.Switch.with_focus_ring}: a [focused] style whose shadow
    has zero offset, zero blur, a spread of 3 and the colour
    [rgba(11, 97, 88, 0.5)], which a browser computes as
    [rgba(11, 97, 88, 0.5) 0px 0px 0px 3px], with a corner radius of 12 so the
    ring follows the track's rounded ends. The reason and the hint are coloured
    [#5C5346] at 14 px.

    Each switch's outer box carries a [data-testid]: the switch's id followed by
    [-row], for example [switch-disabled-row].

    The switches sit between two buttons that do nothing,
    [data-testid="switch-before"] and [data-testid="switch-after"], so a browser
    can show that Tab stops on the disabled switch. *)

(** The section's routes. Both are the kitchen sink's own page, under the
    [/kitchen_sink/] prefix the browser suite and the site serve it from:
    [Start] is [/kitchen_sink/] and [Dropped_alerts] is
    [/kitchen_sink/?switch=dropped-alerts]. They differ only in the query, so
    the page still loads when the address is reloaded. *)
type route = Start | Dropped_alerts

val router :
  (module Nopal_platform.Platform.NAV) -> route Nopal_platform.Router.t
(** [router platform] is the section's router. A platform's path carries no
    query, so its [parse] recognises [Start] only; the section never reads its
    route back from the address. *)

type model
(** Whether each switch is on. *)

(** The section's messages. Each toggle carries the value the switch asked for.
*)
type msg =
  | Starts_on_toggled of bool  (** [switch-starts-on] was pressed. *)
  | Starts_off_toggled of bool  (** [switch-starts-off] was pressed. *)
  | Disabled_toggled of bool
      (** [switch-disabled] was pressed. A disabled switch dispatches nothing,
          so this arrives only if that guarantee breaks. *)
  | Dropped_alerts_followed  (** The hint's link was followed in-app. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** [switch-starts-on] on, the other two off. No command. *)

val update :
  route Nopal_platform.Router.t -> model -> msg -> model * msg Nopal_mvu.Cmd.t
(** Each toggle makes the value it carries its switch's state, with no command.
    [Dropped_alerts_followed] keeps the model and pushes [Dropped_alerts]
    through the router. *)

val view : route Nopal_platform.Router.t -> model -> msg Nopal_element.Element.t
(** The button before the switches, the three switches in the order above, and
    the button after them. A link address the router refuses is shown as an
    error line, [data-testid="switch-dropped-alerts-error"], in the link's
    place. *)

val serialize_msg : msg -> string
(** Telemetry serializer for the section's messages: [Switch:], the
    constructor's name, then for a toggle a colon and the value asked for, and
    [;], so one fragment cannot prefix-alias another. For example
    [Switch:Starts_on_toggled:false;] and [Switch:Dropped_alerts_followed;]. *)

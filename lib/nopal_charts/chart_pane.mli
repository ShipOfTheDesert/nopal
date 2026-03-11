(** Multi-pane synchronized layout container. REQ-F5, REQ-F6.

    Renders vertically stacked chart panes sharing a single X axis domain
    window. Pane heights are proportional to their [height_ratio] values
    (normalized to sum to 1.0). Pan and zoom interactions are emitted as
    semantic messages for the application's update function to handle. *)

type 'msg pane = {
  height_ratio : float;
  chart : Domain_window.t -> 'msg Nopal_element.Element.t;
  y_axis : Axis.config option;
}
(** A single pane in a multi-pane layout. [height_ratio] is relative (e.g., 0.6
    for 60%). [chart] receives the shared domain window and returns the chart
    element. *)

val pane :
  height_ratio:float ->
  ?y_axis:Axis.config ->
  (Domain_window.t -> 'msg Nopal_element.Element.t) ->
  'msg pane
(** Convenience constructor. *)

val view :
  panes:'msg pane list ->
  domain_window:Domain_window.t ->
  width:float ->
  height:float ->
  ?on_pan:(float -> 'msg) ->
  ?on_zoom:(float -> float -> 'msg) ->
  unit ->
  'msg Nopal_element.Element.t
(** Renders vertically stacked chart panes sharing a single X axis. [on_pan x]
    is emitted on pointer move (horizontal drag). [on_zoom center factor] is
    emitted on click (zoom interaction). Each pane's [chart] function receives
    the shared [domain_window]. Pane heights are proportional to [height_ratio]
    values. *)

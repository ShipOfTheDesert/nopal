(** Multi-pane synchronized layout container. REQ-F5, REQ-F6.

    Renders vertically stacked chart panes sharing a single X axis domain
    window. Pane heights are proportional to their [height_ratio] values
    (normalized to sum to 1.0). Pointer events are forwarded to the caller so
    the application's update function can implement pan/zoom logic. *)

type 'msg pane = {
  height_ratio : float;
  chart :
    Domain_window.t ->
    width:float ->
    height:float ->
    'msg Nopal_element.Element.t;
  y_axis : Axis.config option;
}
(** A single pane in a multi-pane layout. [height_ratio] is relative (e.g., 0.6
    for 60%). [chart] receives the shared domain window plus the computed pixel
    width and height for the pane. *)

val pane :
  height_ratio:float ->
  ?y_axis:Axis.config ->
  (Domain_window.t ->
  width:float ->
  height:float ->
  'msg Nopal_element.Element.t) ->
  'msg pane
(** Convenience constructor. *)

val view :
  panes:'msg pane list ->
  domain_window:Domain_window.t ->
  width:float ->
  height:float ->
  ?on_pointer_down:(Nopal_element.Element.pointer_event -> 'msg) ->
  ?on_pointer_move:(Nopal_element.Element.pointer_event -> 'msg) ->
  ?on_pointer_up:(Nopal_element.Element.pointer_event -> 'msg) ->
  ?on_pointer_leave:'msg ->
  ?on_wheel:(Nopal_element.Element.wheel_event -> 'msg) ->
  unit ->
  'msg Nopal_element.Element.t
(** Renders vertically stacked chart panes sharing a single X axis. Raw pointer
    events are forwarded so the caller can implement pan and zoom semantics
    (e.g. track drag state, compute deltas, zoom on click). Each pane's [chart]
    function receives the shared [domain_window]. Pane heights are proportional
    to [height_ratio] values. *)

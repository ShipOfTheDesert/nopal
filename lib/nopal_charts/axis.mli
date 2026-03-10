(** Axis tick computation and rendering.

    Computes nice tick positions from data extents, supports explicit domain
    overrides, and renders axis lines/ticks/labels as scene nodes. REQ-F12. *)

type tick = { value : float; label : string }

type config = {
  label : string option;
  min : float option;
  max : float option;
  tick_count : int;
  format_tick : float -> string;
}

val default_config : config
(** [{label = None; min = None; max = None; tick_count = 5; format_tick =
     string_of_float}] *)

val compute_ticks : config -> data_min:float -> data_max:float -> tick list
(** Computes tick positions and labels. Uses explicit min/max if set, otherwise
    computes nice bounds from data extents. *)

val compute_domain : config -> data_min:float -> data_max:float -> float * float
(** Returns the effective (min, max) domain, applying explicit overrides or
    computing nice bounds. *)

val render_x :
  config ->
  ticks:tick list ->
  scale:Nopal_draw.Scale.t ->
  chart_x:float ->
  chart_y:float ->
  chart_width:float ->
  Nopal_draw.Scene.t list
(** Renders X axis line, tick marks, tick labels, and optional axis label as
    scene nodes. When [config.label] is [Some], a centered label is rendered
    below the tick labels. *)

val render_y :
  config ->
  ticks:tick list ->
  scale:Nopal_draw.Scale.t ->
  chart_x:float ->
  chart_y:float ->
  chart_height:float ->
  Nopal_draw.Scene.t list
(** Renders Y axis line, tick marks, tick labels, and optional axis label as
    scene nodes. When [config.label] is [Some], a centered label is rendered to
    the left of the tick labels. *)

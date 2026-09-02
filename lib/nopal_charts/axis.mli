(** Axis tick computation and rendering.

    Computes nice tick positions from data extents, supports explicit domain
    overrides, and renders axis lines/ticks/labels as scene nodes. *)

type tick = { value : float; label : string }

type appearance = {
  line_color : Nopal_draw.Color.t;
      (** Stroke colour of the axis line itself. Defaults to the grey
          [Nopal_draw.Color.rgb ~r:0.2 ~g:0.2 ~b:0.2]. *)
  line_width : float;
      (** Stroke width of the axis line and of every tick mark. The two share
          one width; there is no separate tick width. Defaults to [1.0]. *)
  tick_color : Nopal_draw.Color.t;
      (** Stroke colour of the tick marks. Independent of [line_color] even
          though the two carry the same default, because they split one constant
          this module used to share. Defaults to the grey
          [Nopal_draw.Color.rgb ~r:0.2 ~g:0.2 ~b:0.2]. *)
  tick_length : float;
      (** Length of each tick mark in scene units, measured from the axis line
          away from the plot area: below the line on an X axis, to its left on a
          Y axis. Defaults to [6.0]. The offset that places the tick labels is
          module-private and fixed at [16.0], so a [tick_length] above [16.0]
          drives the tick marks through the tick labels — on both orientations.
          Nothing rejects a larger value; the ceiling is a layout constraint,
          not a validated one. *)
  tick_label_color : Nopal_draw.Color.t;
      (** Fill colour of the per-tick value labels. Defaults to
          [Nopal_draw.Color.black] — the colour a text node takes when no fill
          is given — and deliberately not the axis grey. *)
  tick_label_size : float;
      (** Font size of the per-tick value labels. Defaults to [11.0]. The two
          module-private offsets that place the tick labels ([16.0] from the
          axis line) and the axis label ([32.0]) leave a fixed [16.0] gap
          between them, so on an X axis — where the labels stack vertically and
          the tick labels hang below their baseline — a [tick_label_size] above
          [16.0] overlaps the axis label. Nothing rejects a larger value. *)
  axis_label_color : Nopal_draw.Color.t;
      (** Fill colour of the axis label, the single caption drawn when
          [config.label] is [Some]. Defaults to [Nopal_draw.Color.black], as for
          the tick labels. *)
  axis_label_size : float;
      (** Font size of the axis label. Defaults to [12.0], one unit larger than
          the tick labels. *)
}
(** Paint and metric values for the axis line, tick marks, tick labels and axis
    label. Colours are the float-RGBA scene type, not the integer CSS-authoring
    one. Every field's default is stated on the field above, because
    [{default_appearance with ...}] inherits the seven values the caller did not
    name — paint the call site never states. *)

val default_appearance : appearance
(** The chrome this module has always drawn: a 1.0-wide grey ([rgb 0.2 0.2 0.2])
    line and 6.0-long tick marks in the same grey, black tick labels at 11.0 and
    a black axis label at 12.0. An axis that does not name an appearance carries
    this value and renders exactly as it did before appearance was configurable
    — the same scene nodes in the same order with the same paint, byte for byte
    once serialised. Changing a value here changes every chart in the repository
    that draws an axis. *)

val equal_appearance : appearance -> appearance -> bool
(** Structural equality. Float fields compare with [Float.equal], so two
    appearances holding NaN in the same field are equal. [config] has no
    counterpart because [format_tick] is a function. *)

type config = {
  label : string option;
  min : float option;
  max : float option;
  tick_count : int;
  format_tick : float -> string;
  appearance : appearance;
      (** Paint and metrics for this axis's chrome. Reached through the same
          [?x_axis] / [?y_axis] argument as [label] and [tick_count], never a
          parallel one. *)
}

val default_config : config
(** [{label = None; min = None; max = None; tick_count = 5; format_tick =
     string_of_float; appearance = default_appearance}]. The appearance defaults
    are documented field by field on [appearance]. *)

val compute_ticks : config -> data_min:float -> data_max:float -> tick list
(** Computes tick positions and labels. Uses explicit min/max if set, otherwise
    computes nice bounds from data extents. Ignores [config.appearance], which
    is paint only and never moves a tick. *)

val compute_domain : config -> data_min:float -> data_max:float -> float * float
(** Returns the effective (min, max) domain, applying explicit overrides or
    computing nice bounds. Ignores [config.appearance]. *)

val render_x :
  config ->
  ticks:tick list ->
  scale:Nopal_draw.Scale.t ->
  chart_x:float ->
  chart_y:float ->
  chart_width:float ->
  Nopal_draw.Scene.t list
(** Renders X axis line, tick marks, tick labels, and optional axis label as
    scene nodes, painted with [config.appearance]. When [config.label] is
    [Some], a centered label is rendered below the tick labels. A config
    carrying [default_appearance] produces the output this function produced
    before appearance was configurable. *)

val render_y :
  config ->
  ticks:tick list ->
  scale:Nopal_draw.Scale.t ->
  chart_x:float ->
  chart_y:float ->
  chart_height:float ->
  Nopal_draw.Scene.t list
(** Renders Y axis line, tick marks, tick labels, and optional axis label as
    scene nodes, painted with [config.appearance]. When [config.label] is
    [Some], a centered label is rendered to the left of the tick labels. A
    config carrying [default_appearance] produces the output this function
    produced before appearance was configurable. *)

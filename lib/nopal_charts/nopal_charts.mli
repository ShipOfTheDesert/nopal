(** Nopal Charts — composable, interactive chart library for Nopal.

    {b Warning}: Opening this module will shadow {!Nopal_element.Viewport}. This
    module defines its own [Viewport] submodule which takes precedence. If you
    need the viewport type from Nopal_element, use the qualified name
    [Nopal_element.Viewport] or avoid opening this module. *)

module Area = Area
module Chart_pane = Chart_pane
module Color_scale = Color_scale
module Heat_map = Heat_map
module Domain_window = Domain_window
module Downsample = Downsample
module Viewport = Viewport
module Axis = Axis
module Bar = Bar
module Chart_compose = Chart_compose
module Hit_map = Hit_map
module Hover = Hover
module Legend = Legend
module Line = Line
module Padding = Padding
module Pie = Pie
module Scatter = Scatter
module Snap = Snap
module Sparkline = Sparkline
module Tooltip = Tooltip

(** Trading namespace — trading-specific chart types. *)
module Trading : sig
  module Candlestick = Trading_candlestick
  module Drawdown = Trading_drawdown
end

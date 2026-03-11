(** Candlestick chart — OHLC candles with wicks. REQ-F4.

    Renders candlestick data with vertical wicks (high/low) and colored bodies
    (open/close). Bullish candles (close > open) and bearish candles (close <
    open) use distinct colors. When [domain_window] is provided, data is clipped
    via [Viewport.clip] with [buffer=0]. *)

val view :
  data:'a list ->
  x:('a -> float) ->
  open_:('a -> float) ->
  high:('a -> float) ->
  low:('a -> float) ->
  close:('a -> float) ->
  width:float ->
  height:float ->
  ?padding:Padding.t ->
  ?bullish_color:Nopal_draw.Color.t ->
  ?bearish_color:Nopal_draw.Color.t ->
  ?x_axis:Axis.config ->
  ?y_axis:Axis.config ->
  ?format_tooltip:
    (int -> float -> float -> float -> float -> 'msg Nopal_element.Element.t) ->
  ?on_hover:(Hover.t -> 'msg) ->
  ?on_leave:'msg ->
  ?hover:Hover.t ->
  ?domain_window:Domain_window.t ->
  unit ->
  'msg Nopal_element.Element.t
(** [view ~data ~x ~open_ ~high ~low ~close ~width ~height ()] renders an
    interactive candlestick chart. [format_tooltip] receives the data index and
    OHLC values (open, high, low, close). *)

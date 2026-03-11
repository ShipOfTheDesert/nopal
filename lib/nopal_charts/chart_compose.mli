(** Shared chart composition — combines chart scene with optional tooltip scene
    into a single Draw element. *)

val compose :
  scene:Nopal_draw.Scene.t list ->
  tooltip_scene:Nopal_draw.Scene.t list ->
  width:float ->
  height:float ->
  ?on_pointer_move:(Nopal_element.Element.pointer_event -> 'msg) ->
  ?on_pointer_leave:'msg ->
  ?on_pointer_down:(Nopal_element.Element.pointer_event -> 'msg) ->
  ?on_pointer_up:(Nopal_element.Element.pointer_event -> 'msg) ->
  ?on_wheel:(Nopal_element.Element.wheel_event -> 'msg) ->
  ?cursor:Nopal_style.Cursor.t ->
  unit ->
  'msg Nopal_element.Element.t
(** [compose ~scene ~tooltip_scene ~width ~height ()] merges the chart scene and
    tooltip scene into a single Draw element. Pointer handlers are wired
    directly on the canvas. *)

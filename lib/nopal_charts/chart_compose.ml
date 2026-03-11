let compose ~scene ~tooltip_scene ~width ~height ?on_pointer_move
    ?on_pointer_leave ?on_pointer_down ?on_pointer_up ?on_wheel ?cursor () =
  let all_scene = scene @ tooltip_scene in
  Nopal_element.Element.draw ?on_pointer_move ?on_pointer_leave ?on_pointer_down
    ?on_pointer_up ?on_wheel ?cursor ~width ~height all_scene

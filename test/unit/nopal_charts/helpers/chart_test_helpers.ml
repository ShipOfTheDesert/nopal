open Nopal_element

let extract_draw (el : 'msg Element.t) =
  match el with
  | Box { children; _ } ->
      List.find_map
        (fun (child : 'msg Element.t) ->
          match child with
          | Draw d ->
              Some
                ( d.scene,
                  d.on_pointer_move,
                  d.on_pointer_leave,
                  d.width,
                  d.height )
          | _ -> None)
        children
  | Draw d ->
      Some (d.scene, d.on_pointer_move, d.on_pointer_leave, d.width, d.height)
  | _ -> None

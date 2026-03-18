open Nopal_element
open Nopal_scene

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

let rec count_nodes pred (scene : Scene.t list) =
  List.fold_left
    (fun acc (node : Scene.t) ->
      let acc = if pred node then acc + 1 else acc in
      match node with
      | Clip { children; _ }
      | Group { children; _ } ->
          acc + count_nodes pred children
      | _ -> acc)
    0 scene

let is_polyline (node : Scene.t) =
  match node with
  | Polyline _ -> true
  | _ -> false

let is_path (node : Scene.t) =
  match node with
  | Path _ -> true
  | _ -> false

let is_circle (node : Scene.t) =
  match node with
  | Circle _ -> true
  | _ -> false

let is_rect (node : Scene.t) =
  match node with
  | Rect _ -> true
  | _ -> false

type 'msg pane = {
  height_ratio : float;
  chart : Domain_window.t -> 'msg Nopal_element.Element.t;
  y_axis : Axis.config option;
}

let pane ~height_ratio ?y_axis chart = { height_ratio; chart; y_axis }

let view ~panes ~domain_window ~width ~height ?on_pan ?on_zoom () =
  (* Normalize height ratios to sum to 1.0 *)
  let total_ratio =
    List.fold_left (fun acc p -> acc +. p.height_ratio) 0.0 panes
  in
  let normalized =
    List.map
      (fun p -> { p with height_ratio = p.height_ratio /. total_ratio })
      panes
  in
  (* Compute pixel height per pane; render each chart *)
  let pane_elements =
    List.map
      (fun p ->
        let pane_height = height *. p.height_ratio in
        let style =
          Nopal_style.Style.default
          |> Nopal_style.Style.with_layout (fun l ->
              { l with width = Fixed width; height = Fixed pane_height })
        in
        Nopal_element.Element.box ~style [ p.chart domain_window ])
      normalized
  in
  let column = Nopal_element.Element.column pane_elements in
  (* Add interaction overlay if pan or zoom handlers provided *)
  match (on_pan, on_zoom) with
  | None, None -> column
  | _ ->
      let on_pointer_move =
        match on_pan with
        | Some handler ->
            Some
              (fun (pe : Nopal_element.Element.pointer_event) -> handler pe.x)
        | None -> None
      in
      let on_click =
        match on_zoom with
        | Some handler ->
            Some
              (fun (pe : Nopal_element.Element.pointer_event) ->
                handler pe.x 0.8)
        | None -> None
      in
      let overlay =
        Nopal_element.Element.draw ?on_pointer_move ?on_click
          ~cursor:Nopal_style.Cursor.Grab ~width ~height []
      in
      let outer_style =
        Nopal_style.Style.default
        |> Nopal_style.Style.with_layout (fun l ->
            { l with width = Fixed width; height = Fixed height })
      in
      Nopal_element.Element.box ~style:outer_style [ column; overlay ]

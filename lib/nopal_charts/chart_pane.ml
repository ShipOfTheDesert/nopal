type 'msg pane = {
  height_ratio : float;
  chart :
    Domain_window.t ->
    width:float ->
    height:float ->
    'msg Nopal_element.Element.t;
  y_axis : Axis.config option;
}

let pane ~height_ratio ?y_axis chart = { height_ratio; chart; y_axis }

let view ~panes ~domain_window ~width ~height ?on_pointer_down ?on_pointer_move
    ?on_pointer_up ?on_pointer_leave ?on_wheel () =
  match panes with
  | [] -> Nopal_element.Element.empty
  | panes ->
      (* Normalize height ratios to sum to 1.0, clamping negatives to 0 *)
      let panes =
        List.map
          (fun p -> { p with height_ratio = Float.max 0.0 p.height_ratio })
          panes
      in
      let total_ratio =
        List.fold_left (fun acc p -> acc +. p.height_ratio) 0.0 panes
      in
      if Float.equal total_ratio 0.0 then Nopal_element.Element.empty
      else
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
              Nopal_element.Element.box ~style
                [ p.chart domain_window ~width ~height:pane_height ])
            normalized
        in
        let column = Nopal_element.Element.column pane_elements in
        let outer_style =
          Nopal_style.Style.default
          |> Nopal_style.Style.with_layout (fun l ->
              { l with width = Fixed width; height = Fixed height })
        in
        Nopal_element.Element.box ~style:outer_style ?on_pointer_down
          ?on_pointer_move ?on_pointer_up ?on_pointer_leave ?on_wheel [ column ]

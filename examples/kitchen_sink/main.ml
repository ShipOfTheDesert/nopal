let has_tauri () =
  not (Jv.is_undefined (Jv.get Jv.global "__TAURI_INTERNALS__"))

let tauri_fetch_cmd =
  Nopal_mvu.Cmd.batch
    [
      Nopal_mvu.Cmd.task (fun dispatch ->
          Nopal_tauri.App.get_name (fun s ->
              dispatch (Kitchen_sink_app.GotAppName s)));
      Nopal_mvu.Cmd.task (fun dispatch ->
          Nopal_tauri.App.get_version (fun s ->
              dispatch (Kitchen_sink_app.GotAppVersion s)));
      Nopal_mvu.Cmd.task (fun dispatch ->
          Nopal_tauri.App.get_tauri_version (fun s ->
              dispatch (Kitchen_sink_app.GotTauriVersion s)));
      Nopal_mvu.Cmd.task (fun dispatch ->
          Nopal_tauri.Os.platform (fun p ->
              dispatch
                (Kitchen_sink_app.GotPlatform (Nopal_tauri.Os.to_string p))));
    ]

let tauri_listen_cmd =
  Nopal_mvu.Cmd.task (fun dispatch ->
      Nopal_tauri.Event.listen "nopal:kitchen-sink"
        (fun ev -> dispatch (Kitchen_sink_app.TauriEventReceived ev.payload))
        (fun unlisten -> dispatch (Kitchen_sink_app.GotTauriUnlisten unlisten)))

let init () =
  let model, cmd = Kitchen_sink_app.init () in
  if has_tauri () then
    (model, Nopal_mvu.Cmd.batch [ cmd; tauri_fetch_cmd; tauri_listen_cmd ])
  else (model, cmd)

let update model msg =
  let model', cmd = Kitchen_sink_app.update model msg in
  match msg with
  | Kitchen_sink_app.FetchTauriInfo when has_tauri () ->
      (model', Nopal_mvu.Cmd.batch [ cmd; tauri_fetch_cmd ])
  | Kitchen_sink_app.EmitTauriEvent when has_tauri () ->
      let emit_cmd =
        Nopal_mvu.Cmd.task (fun dispatch ->
            Nopal_tauri.Event.emit "nopal:kitchen-sink" "hello from nopal"
              (fun () -> dispatch Kitchen_sink_app.TauriEventEmitted))
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; emit_cmd ])
  | Kitchen_sink_app.ListenTauriEvents when has_tauri () ->
      (model', Nopal_mvu.Cmd.batch [ cmd; tauri_listen_cmd ])
  | Kitchen_sink_app.UnlistenTauriEvents when has_tauri () ->
      let unlisten_cmd =
        match model.tauri_event_unlisten with
        | Some f -> Nopal_mvu.Cmd.task (fun _dispatch -> f ())
        | None -> Nopal_mvu.Cmd.none
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; unlisten_cmd ])
  | Kitchen_sink_app.SetTauriWindowTitle when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task (fun dispatch ->
            Nopal_tauri.Window.set_title model.tauri_window_title (fun () ->
                dispatch Kitchen_sink_app.TauriWindowTitleSet))
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | Kitchen_sink_app.SetTauriFullscreen flag when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task (fun dispatch ->
            Nopal_tauri.Window.set_fullscreen flag (fun () ->
                dispatch Kitchen_sink_app.TauriFullscreenSet;
                Nopal_tauri.Window.is_fullscreen (fun v ->
                    dispatch (Kitchen_sink_app.GotTauriFullscreen v))))
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | Kitchen_sink_app.QueryTauriFullscreen when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task (fun dispatch ->
            Nopal_tauri.Window.is_fullscreen (fun v ->
                dispatch (Kitchen_sink_app.GotTauriFullscreen v)))
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | Kitchen_sink_app.MinimizeTauriWindow when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task (fun dispatch ->
            Nopal_tauri.Window.minimize (fun () ->
                dispatch Kitchen_sink_app.TauriWindowMinimized))
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | Kitchen_sink_app.MaximizeTauriWindow when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task (fun dispatch ->
            Nopal_tauri.Window.maximize (fun () ->
                dispatch Kitchen_sink_app.TauriWindowMaximized;
                Nopal_tauri.Window.is_maximized (fun v ->
                    dispatch (Kitchen_sink_app.GotTauriMaximized v))))
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | Kitchen_sink_app.UnmaximizeTauriWindow when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task (fun dispatch ->
            Nopal_tauri.Window.unmaximize (fun () ->
                dispatch Kitchen_sink_app.TauriWindowUnmaximized;
                Nopal_tauri.Window.is_maximized (fun v ->
                    dispatch (Kitchen_sink_app.GotTauriMaximized v))))
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | Kitchen_sink_app.QueryTauriMaximized when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task (fun dispatch ->
            Nopal_tauri.Window.is_maximized (fun v ->
                dispatch (Kitchen_sink_app.GotTauriMaximized v)))
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | Kitchen_sink_app.CloseTauriWindow when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task (fun dispatch ->
            Nopal_tauri.Window.close (fun () ->
                dispatch Kitchen_sink_app.TauriWindowClosed))
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | Kitchen_sink_app.SetTauriWindowSize (w, h) when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task (fun dispatch ->
            Nopal_tauri.Window.set_size { width = w; height = h } (fun () ->
                dispatch Kitchen_sink_app.TauriWindowSizeSet))
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | Kitchen_sink_app.QueryTauriInnerSize when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task (fun dispatch ->
            Nopal_tauri.Window.inner_size (fun size ->
                dispatch
                  (Kitchen_sink_app.GotWindowInnerSize (size.width, size.height))))
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | Kitchen_sink_app.ButtonClicked
  | Kitchen_sink_app.InputChanged _
  | Kitchen_sink_app.SubmitInputChanged _
  | Kitchen_sink_app.InputSubmitted
  | Kitchen_sink_app.AddKeyedItem
  | Kitchen_sink_app.RemoveKeyedItem _
  | Kitchen_sink_app.MoveKeyedItemUp _
  | Kitchen_sink_app.ToggleInteraction
  | Kitchen_sink_app.SubCounterMsg _
  | Kitchen_sink_app.DrawPointerMove _
  | Kitchen_sink_app.DrawPointerLeave
  | Kitchen_sink_app.ChartHovered _
  | Kitchen_sink_app.ChartLeft
  | Kitchen_sink_app.PieHovered _
  | Kitchen_sink_app.PieLeft
  | Kitchen_sink_app.ScatterHovered _
  | Kitchen_sink_app.ScatterLeft
  | Kitchen_sink_app.HeatMapHovered _
  | Kitchen_sink_app.HeatMapLeft
  | Kitchen_sink_app.TradingHovered _
  | Kitchen_sink_app.TradingLeft
  | Kitchen_sink_app.PanePointerDown _
  | Kitchen_sink_app.PanePointerMove _
  | Kitchen_sink_app.PanePointerUp
  | Kitchen_sink_app.PanePointerLeave
  | Kitchen_sink_app.LinePointerDown _
  | Kitchen_sink_app.LinePointerMove _
  | Kitchen_sink_app.LinePointerUp
  | Kitchen_sink_app.LinePointerLeave
  | Kitchen_sink_app.LineWheelZoom _
  | Kitchen_sink_app.ZoomIn
  | Kitchen_sink_app.ZoomOut
  | Kitchen_sink_app.FetchClicked
  | Kitchen_sink_app.FetchResult _
  | Kitchen_sink_app.PostClicked
  | Kitchen_sink_app.PostResult _
  | Kitchen_sink_app.PutClicked
  | Kitchen_sink_app.PutResult _
  | Kitchen_sink_app.TimeoutClicked
  | Kitchen_sink_app.TimeoutResult _
  | Kitchen_sink_app.FetchTauriInfo
  | Kitchen_sink_app.GotAppName _
  | Kitchen_sink_app.GotAppVersion _
  | Kitchen_sink_app.GotTauriVersion _
  | Kitchen_sink_app.EmitTauriEvent
  | Kitchen_sink_app.TauriEventReceived _
  | Kitchen_sink_app.TauriEventEmitted
  | Kitchen_sink_app.ListenTauriEvents
  | Kitchen_sink_app.UnlistenTauriEvents
  | Kitchen_sink_app.GotTauriUnlisten _
  | Kitchen_sink_app.SetTauriWindowTitle
  | Kitchen_sink_app.TauriWindowTitleSet
  | Kitchen_sink_app.UpdateTauriWindowTitleInput _
  | Kitchen_sink_app.SetTauriFullscreen _
  | Kitchen_sink_app.TauriFullscreenSet
  | Kitchen_sink_app.QueryTauriFullscreen
  | Kitchen_sink_app.GotTauriFullscreen _
  | Kitchen_sink_app.MinimizeTauriWindow
  | Kitchen_sink_app.TauriWindowMinimized
  | Kitchen_sink_app.MaximizeTauriWindow
  | Kitchen_sink_app.TauriWindowMaximized
  | Kitchen_sink_app.UnmaximizeTauriWindow
  | Kitchen_sink_app.TauriWindowUnmaximized
  | Kitchen_sink_app.QueryTauriMaximized
  | Kitchen_sink_app.GotTauriMaximized _
  | Kitchen_sink_app.CloseTauriWindow
  | Kitchen_sink_app.TauriWindowClosed
  | Kitchen_sink_app.UpdateTauriWindowWidth _
  | Kitchen_sink_app.UpdateTauriWindowHeight _
  | Kitchen_sink_app.SetTauriWindowSize _
  | Kitchen_sink_app.TauriWindowSizeSet
  | Kitchen_sink_app.QueryTauriInnerSize
  | Kitchen_sink_app.GotWindowInnerSize _
  | Kitchen_sink_app.GotPlatform _ ->
      (model', cmd)

let () =
  Nopal_http.register_backend { Nopal_http.send = Nopal_http_web.send };
  let open Brr in
  let target =
    match Document.find_el_by_id G.document (Jstr.v "app") with
    | Some el -> el
    | None ->
        let body = Document.body G.document in
        let div = El.div [] in
        El.append_children body [ div ];
        div
  in
  Nopal_web.mount
    (module struct
      type model = Kitchen_sink_app.model
      type msg = Kitchen_sink_app.msg

      let init = init
      let update = update
      let view = Kitchen_sink_app.view
      let subscriptions = Kitchen_sink_app.subscriptions
    end)
    target

(* The kitchen sink is platform-agnostic; the concrete web platform (and thus
   its IndexedDB-backed storage) is selected here, the only place Brr appears. *)
module App = Kitchen_sink_app.Make (Nopal_web.Platform_web)

(* Component sub-apps, re-exported by [Kitchen_sink_app] so [serialize_msg]
   below can name their message constructors (RFC 0112, Step 5). *)
module Kitchen_sink_ui = Kitchen_sink_app.Kitchen_sink_ui
module Kitchen_sink_form_controls = Kitchen_sink_app.Kitchen_sink_form_controls
module Kitchen_sink_text_input = Kitchen_sink_app.Kitchen_sink_text_input
module Sub_toast = Kitchen_sink_app.Sub_toast
module Sub_data_table = Kitchen_sink_app.Sub_data_table
module Sub_navigation_bar = Kitchen_sink_app.Sub_navigation_bar
module Sub_bottom_tabs = Kitchen_sink_app.Sub_bottom_tabs
module Sub_modal = Kitchen_sink_app.Sub_modal

let has_tauri () =
  not (Jv.is_undefined (Jv.get Jv.global "__TAURI_INTERNALS__"))

let tauri_fetch_cmd =
  Nopal_mvu.Cmd.batch
    [
      Nopal_mvu.Cmd.task
        (let open Nopal_mvu.Task.Syntax in
         let+ s = Nopal_tauri.App.get_name in
         App.GotAppName s);
      Nopal_mvu.Cmd.task
        (let open Nopal_mvu.Task.Syntax in
         let+ s = Nopal_tauri.App.get_version in
         App.GotAppVersion s);
      Nopal_mvu.Cmd.task
        (let open Nopal_mvu.Task.Syntax in
         let+ s = Nopal_tauri.App.get_tauri_version in
         App.GotTauriVersion s);
      Nopal_mvu.Cmd.task
        (let open Nopal_mvu.Task.Syntax in
         let+ p = Nopal_tauri.Os.platform in
         App.GotPlatform (Nopal_tauri.Os.to_string p));
    ]

let tauri_listen_cmd =
  Nopal_mvu.Cmd.perform (fun dispatch ->
      Nopal_tauri.Event.listen "nopal:kitchen-sink"
        (fun ev -> dispatch (App.TauriEventReceived ev.payload))
        (fun unlisten -> dispatch (App.GotTauriUnlisten unlisten)))

let init () =
  let model, cmd = App.init () in
  if has_tauri () then
    (model, Nopal_mvu.Cmd.batch [ cmd; tauri_fetch_cmd; tauri_listen_cmd ])
  else (model, cmd)

let update model msg =
  let model', cmd = App.update model msg in
  match msg with
  | App.FetchTauriInfo when has_tauri () ->
      (model', Nopal_mvu.Cmd.batch [ cmd; tauri_fetch_cmd ])
  | App.EmitTauriEvent when has_tauri () ->
      let emit_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let+ () =
             Nopal_tauri.Event.emit "nopal:kitchen-sink" "hello from nopal"
           in
           App.TauriEventEmitted)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; emit_cmd ])
  | App.ListenTauriEvents when has_tauri () ->
      (model', Nopal_mvu.Cmd.batch [ cmd; tauri_listen_cmd ])
  | App.UnlistenTauriEvents when has_tauri () ->
      let unlisten_cmd =
        match model.tauri_event_unlisten with
        | Some f -> Nopal_mvu.Cmd.perform (fun _dispatch -> f ())
        | None -> Nopal_mvu.Cmd.none
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; unlisten_cmd ])
  | App.SetTauriWindowTitle when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let+ () = Nopal_tauri.Window.set_title model.tauri_window_title in
           App.TauriWindowTitleSet)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | App.SetTauriFullscreen flag when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let* () = Nopal_tauri.Window.set_fullscreen flag in
           let+ v = Nopal_tauri.Window.is_fullscreen in
           App.GotTauriFullscreen v)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | App.QueryTauriFullscreen when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let+ v = Nopal_tauri.Window.is_fullscreen in
           App.GotTauriFullscreen v)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | App.MinimizeTauriWindow when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let+ () = Nopal_tauri.Window.minimize in
           App.TauriWindowMinimized)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | App.MaximizeTauriWindow when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let* () = Nopal_tauri.Window.maximize in
           let+ v = Nopal_tauri.Window.is_maximized in
           App.GotTauriMaximized v)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | App.UnmaximizeTauriWindow when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let* () = Nopal_tauri.Window.unmaximize in
           let+ v = Nopal_tauri.Window.is_maximized in
           App.GotTauriMaximized v)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | App.QueryTauriMaximized when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let+ v = Nopal_tauri.Window.is_maximized in
           App.GotTauriMaximized v)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | App.ShowTauriWindow when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let* () = Nopal_tauri.Window.show in
           let+ v = Nopal_tauri.Window.is_visible in
           App.GotTauriVisible v)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | App.HideTauriWindow when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let* () = Nopal_tauri.Window.hide in
           let+ v = Nopal_tauri.Window.is_visible in
           App.GotTauriVisible v)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | App.QueryTauriVisible when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let+ v = Nopal_tauri.Window.is_visible in
           App.GotTauriVisible v)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | App.SetTauriWindowFocus when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let+ () = Nopal_tauri.Window.set_focus in
           App.TauriWindowFocused)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | App.CenterTauriWindow when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let+ () = Nopal_tauri.Window.center in
           App.TauriWindowCentered)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | App.CloseTauriWindow when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let+ () = Nopal_tauri.Window.close in
           App.TauriWindowClosed)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | App.SetTauriWindowSize (w, h) when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let+ () = Nopal_tauri.Window.set_size { width = w; height = h } in
           App.TauriWindowSizeSet)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | App.QueryTauriInnerSize when has_tauri () ->
      let window_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let+ size = Nopal_tauri.Window.inner_size in
           App.GotWindowInnerSize (size.width, size.height))
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; window_cmd ])
  | App.HideToTray when has_tauri () ->
      let hide_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let+ () = Nopal_tauri.Window.hide in
           App.TrayHidden)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; hide_cmd ])
  | App.TrayClicked when has_tauri () ->
      let restore_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let* () = Nopal_tauri.Window.show in
           let+ () = Nopal_tauri.Window.set_focus in
           App.TrayRestored)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; restore_cmd ])
  | App.SetTrayTooltip when has_tauri () ->
      let tooltip_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let+ () = Nopal_tauri.Tray.set_tooltip model.tray_tooltip_input in
           App.TrayTooltipSet)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; tooltip_cmd ])
  | App.SetTrayIconVisible flag when has_tauri () ->
      let visible_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let+ () = Nopal_tauri.Tray.set_visible flag in
           App.TrayIconVisibleSet)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; visible_cmd ])
  | App.TauriStoreSet when has_tauri () ->
      let store_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let+ r =
             Nopal_tauri.Store.set model.tauri_store_key model.tauri_store_value
           in
           App.TauriStoreSetResult r)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; store_cmd ])
  | App.TauriStoreGet when has_tauri () ->
      let store_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let+ r = Nopal_tauri.Store.get model.tauri_store_key in
           App.TauriStoreGetResult r)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; store_cmd ])
  | App.TauriStoreDelete when has_tauri () ->
      let store_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let+ r = Nopal_tauri.Store.delete model.tauri_store_key in
           App.TauriStoreDeleteResult r)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; store_cmd ])
  | App.TauriStoreClear when has_tauri () ->
      let store_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let+ r = Nopal_tauri.Store.clear () in
           App.TauriStoreClearResult r)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; store_cmd ])
  | App.TauriStoreSave when has_tauri () ->
      let store_cmd =
        Nopal_mvu.Cmd.task
          (let open Nopal_mvu.Task.Syntax in
           let+ r = Nopal_tauri.Store.save () in
           App.TauriStoreSaveResult r)
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; store_cmd ])
  | App.StorageReload ->
      let reload_cmd =
        Nopal_mvu.Cmd.perform (fun _dispatch ->
            let w = Jv.get Jv.global "window" in
            let location = Jv.get w "location" in
            ignore (Jv.call location "reload" [||]))
      in
      (model', Nopal_mvu.Cmd.batch [ cmd; reload_cmd ])
  | App.ButtonClicked
  | App.InputChanged _
  | App.SubmitInputChanged _
  | App.InputSubmitted
  | App.AddKeyedItem
  | App.RemoveKeyedItem _
  | App.MoveKeyedItemUp _
  | App.ToggleInteraction
  | App.TelemetryPing _
  | App.SubCounterMsg _
  | App.DrawPointerMove _
  | App.DrawPointerLeave
  | App.ChartHovered _
  | App.ChartLeft
  | App.PieHovered _
  | App.PieLeft
  | App.ScatterHovered _
  | App.ScatterLeft
  | App.HeatMapHovered _
  | App.HeatMapLeft
  | App.TradingHovered _
  | App.TradingLeft
  | App.PanePointerDown _
  | App.PanePointerMove _
  | App.PanePointerUp
  | App.PanePointerLeave
  | App.LinePointerDown _
  | App.LinePointerMove _
  | App.LinePointerUp
  | App.LinePointerLeave
  | App.LineWheelZoom _
  | App.ZoomIn
  | App.ZoomOut
  | App.FetchClicked
  | App.FetchResult _
  | App.PostClicked
  | App.PostResult _
  | App.PutClicked
  | App.PutResult _
  | App.TimeoutClicked
  | App.TimeoutResult _
  | App.FetchTauriInfo
  | App.GotAppName _
  | App.GotAppVersion _
  | App.GotTauriVersion _
  | App.EmitTauriEvent
  | App.TauriEventReceived _
  | App.TauriEventEmitted
  | App.ListenTauriEvents
  | App.UnlistenTauriEvents
  | App.GotTauriUnlisten _
  | App.SetTauriWindowTitle
  | App.TauriWindowTitleSet
  | App.UpdateTauriWindowTitleInput _
  | App.SetTauriFullscreen _
  | App.QueryTauriFullscreen
  | App.GotTauriFullscreen _
  | App.MinimizeTauriWindow
  | App.TauriWindowMinimized
  | App.MaximizeTauriWindow
  | App.UnmaximizeTauriWindow
  | App.QueryTauriMaximized
  | App.GotTauriMaximized _
  | App.CloseTauriWindow
  | App.TauriWindowClosed
  | App.UpdateTauriWindowWidth _
  | App.UpdateTauriWindowHeight _
  | App.SetTauriWindowSize _
  | App.TauriWindowSizeSet
  | App.QueryTauriInnerSize
  | App.GotWindowInnerSize _
  | App.ShowTauriWindow
  | App.HideTauriWindow
  | App.QueryTauriVisible
  | App.GotTauriVisible _
  | App.SetTauriWindowFocus
  | App.TauriWindowFocused
  | App.CenterTauriWindow
  | App.TauriWindowCentered
  | App.GotPlatform _
  | App.HideToTray
  | App.TrayHidden
  | App.TrayClicked
  | App.TrayRestored
  | App.UpdateTrayTooltipInput _
  | App.SetTrayTooltip
  | App.TrayTooltipSet
  | App.SetTrayIconVisible _
  | App.TrayIconVisibleSet
  | App.StorageKeyChanged _
  | App.StorageValueChanged _
  | App.StorageSet
  | App.StorageSetResult _
  | App.StorageGet
  | App.StorageGetResult _
  | App.StorageDelete
  | App.StorageDeleteResult _
  | App.StorageList
  | App.StorageListResult _
  | App.StorageClear
  | App.StorageClearResult _
  | App.StorageRestored _
  | App.CodecIncrement
  | App.CodecSave
  | App.CodecSaveResult _
  | App.CodecLoad
  | App.CodecLoadResult _
  | App.CodecCorrupt
  | App.CodecCorruptResult _
  | App.TauriStoreKeyChanged _
  | App.TauriStoreValueChanged _
  | App.TauriStoreSet
  | App.TauriStoreSetResult _
  | App.TauriStoreGet
  | App.TauriStoreGetResult _
  | App.TauriStoreDelete
  | App.TauriStoreDeleteResult _
  | App.TauriStoreClear
  | App.TauriStoreClearResult _
  | App.TauriStoreSave
  | App.TauriStoreSaveResult _
  | App.Ui_msg _
  | App.Form_msg _
  | App.Form_controls_msg _
  | App.Text_input_msg _
  | App.Focus_keyboard_msg _
  | App.Toast_msg _
  | App.Data_table_msg _
  | App.Virtual_list_msg _
  | App.Navigation_bar_msg _
  | App.Bottom_tabs_msg _
  | App.Modal_msg _
  | App.SubWizardMsg _ ->
      (model', cmd)

(* Readable serialisers for the telemetry log (RFC 0110). Only the interactive
   messages the E2E telemetry contract asserts on get distinct labels; every
   other message is enumerated explicitly (no catch-all [_]) so a newly added
   constructor forces a compile error here rather than silently collapsing to
   the generic label. *)
let serialize_msg : App.msg -> string = function
  | App.ButtonClicked -> "ButtonClicked"
  | App.InputChanged s -> "InputChanged:" ^ s
  | App.SubmitInputChanged s -> "SubmitInputChanged:" ^ s
  | App.InputSubmitted -> "InputSubmitted"
  | App.AddKeyedItem -> "AddKeyedItem"
  | App.RemoveKeyedItem id -> Printf.sprintf "RemoveKeyedItem:%d" id
  | App.MoveKeyedItemUp id -> Printf.sprintf "MoveKeyedItemUp:%d" id
  | App.ToggleInteraction -> "ToggleInteraction"
  | App.TelemetryPing label -> "TelemetryPing:" ^ label
  (* Component messages the per-component E2E telemetry contract asserts on
     (RFC 0112, Step 5). Each inner match is exhaustive so a newly added sub
     constructor forces a compile error here rather than silently collapsing to
     the generic "<msg>" label below. *)
  | App.Ui_msg (Kitchen_sink_ui.ButtonClicked label) -> "ButtonClicked:" ^ label
  | App.Form_controls_msg (Kitchen_sink_form_controls.Toggle_agree v) ->
      "Toggle_agree:" ^ string_of_bool v
  | App.Form_controls_msg (Kitchen_sink_form_controls.Select_color v) ->
      "Select_color:" ^ v
  | App.Form_controls_msg (Kitchen_sink_form_controls.Change_size v) ->
      "Change_size:" ^ v
  | App.Text_input_msg (Kitchen_sink_text_input.Default_changed v) ->
      "Default_changed:" ^ v
  | App.Text_input_msg Kitchen_sink_text_input.Default_submitted ->
      "Default_submitted"
  | App.Text_input_msg (Kitchen_sink_text_input.Placeholder_changed v) ->
      "Placeholder_changed:" ^ v
  | App.Text_input_msg (Kitchen_sink_text_input.Error_changed v) ->
      "Error_changed:" ^ v
  | App.Toast_msg Sub_toast.ShowInfo -> "Toast:ShowInfo"
  | App.Toast_msg Sub_toast.ShowSuccess -> "Toast:ShowSuccess"
  | App.Toast_msg Sub_toast.ShowWarning -> "Toast:ShowWarning"
  | App.Toast_msg Sub_toast.ShowError -> "Toast:ShowError"
  | App.Toast_msg (Sub_toast.Dismiss id) -> "Toast:Dismiss:" ^ id
  | App.Data_table_msg (Sub_data_table.Sort key) -> "Sort:" ^ key
  | App.Navigation_bar_msg (Sub_navigation_bar.SelectTab id) ->
      "SelectTab:" ^ id
  (* Bottom_tabs per-tab navigation contract (RFC 0114 Task 4): the E2E
     [assertSequence] proves a push then a back, and the preservation spec reads
     each tab's depth from [serialize_model] below. Exhaustive inner match so a
     new [Sub_bottom_tabs.msg] constructor breaks compilation here. *)
  | App.Bottom_tabs_msg (Sub_bottom_tabs.Select id) -> "BottomTabs:Select:" ^ id
  | App.Bottom_tabs_msg (Sub_bottom_tabs.Push _) -> "BottomTabs:Push"
  | App.Bottom_tabs_msg Sub_bottom_tabs.Back -> "BottomTabs:Back"
  | App.Modal_msg Sub_modal.Open -> "Modal:Open"
  | App.Modal_msg Sub_modal.Close -> "Modal:Close"
  | App.Modal_msg (Sub_modal.FocusChanged id) -> "Modal:FocusChanged:" ^ id
  | App.Modal_msg (Sub_modal.TabCycled id) -> "Modal:TabCycled:" ^ id
  (* Storage persistence contract (RFC 0112, Step 6 / REQ-F3): [StorageSet] is
     the write, [StorageRestored] the post-reload re-read. Only the restored
     [Some] case emits a "Restored" fragment so the E2E wait does not trip on a
     fresh-load empty restore. *)
  | App.StorageSet -> "StorageSet"
  | App.StorageSetResult (Ok ()) -> "StorageSetOk"
  | App.StorageSetResult (Error _) -> "StorageSetError"
  | App.StorageRestored (Ok (Some v)) -> "StorageRestored:" ^ v
  | App.StorageRestored (Ok None) -> "StorageRestoreEmpty"
  | App.StorageRestored (Error _) -> "StorageRestoreError"
  (* Tauri window / tray / store messages the REQ-F5 WebdriverIO specs assert on
     via the host-side [get_telemetry] mirror (RFC 0112, Step 7). The store [Get]
     result carries the read-back value so the relaunch-persistence spec can
     prove it via a message fragment. The remaining Tauri messages keep the
     generic "<msg>" label below. *)
  | App.TrayClicked -> "TrayClicked"
  | App.SetTauriWindowTitle -> "SetTauriWindowTitle"
  | App.TauriWindowTitleSet -> "TauriWindowTitleSet"
  | App.ShowTauriWindow -> "ShowTauriWindow"
  | App.HideTauriWindow -> "HideTauriWindow"
  | App.QueryTauriVisible -> "QueryTauriVisible"
  | App.GotTauriVisible v -> "GotTauriVisible:" ^ string_of_bool v
  | App.TauriStoreSet -> "TauriStoreSet"
  | App.TauriStoreSetResult (Ok ()) -> "TauriStoreSetOk"
  | App.TauriStoreSetResult (Error _) -> "TauriStoreSetError"
  | App.TauriStoreSave -> "TauriStoreSave"
  | App.TauriStoreSaveResult (Ok ()) -> "TauriStoreSaveOk"
  | App.TauriStoreSaveResult (Error _) -> "TauriStoreSaveError"
  | App.TauriStoreGet -> "TauriStoreGet"
  | App.TauriStoreGetResult (Ok (Some v)) -> "TauriStoreGetValue:" ^ v
  | App.TauriStoreGetResult (Ok None) -> "TauriStoreGetEmpty"
  | App.TauriStoreGetResult (Error _) -> "TauriStoreGetError"
  | App.SubCounterMsg _
  | App.Form_msg _
  | App.Focus_keyboard_msg _
  | App.Virtual_list_msg _
  | App.DrawPointerMove _
  | App.DrawPointerLeave
  | App.ChartHovered _
  | App.ChartLeft
  | App.PieHovered _
  | App.PieLeft
  | App.ScatterHovered _
  | App.ScatterLeft
  | App.HeatMapHovered _
  | App.HeatMapLeft
  | App.TradingHovered _
  | App.TradingLeft
  | App.PanePointerDown _
  | App.PanePointerMove _
  | App.PanePointerUp
  | App.PanePointerLeave
  | App.LinePointerDown _
  | App.LinePointerMove _
  | App.LinePointerUp
  | App.LinePointerLeave
  | App.LineWheelZoom _
  | App.ZoomIn
  | App.ZoomOut
  | App.FetchClicked
  | App.FetchResult _
  | App.PostClicked
  | App.PostResult _
  | App.PutClicked
  | App.PutResult _
  | App.TimeoutClicked
  | App.TimeoutResult _
  | App.FetchTauriInfo
  | App.GotAppName _
  | App.GotAppVersion _
  | App.GotTauriVersion _
  | App.EmitTauriEvent
  | App.TauriEventReceived _
  | App.TauriEventEmitted
  | App.ListenTauriEvents
  | App.UnlistenTauriEvents
  | App.GotTauriUnlisten _
  | App.UpdateTauriWindowTitleInput _
  | App.SetTauriFullscreen _
  | App.QueryTauriFullscreen
  | App.GotTauriFullscreen _
  | App.MinimizeTauriWindow
  | App.TauriWindowMinimized
  | App.MaximizeTauriWindow
  | App.UnmaximizeTauriWindow
  | App.QueryTauriMaximized
  | App.GotTauriMaximized _
  | App.CloseTauriWindow
  | App.TauriWindowClosed
  | App.UpdateTauriWindowWidth _
  | App.UpdateTauriWindowHeight _
  | App.SetTauriWindowSize _
  | App.TauriWindowSizeSet
  | App.QueryTauriInnerSize
  | App.GotWindowInnerSize _
  | App.SetTauriWindowFocus
  | App.TauriWindowFocused
  | App.CenterTauriWindow
  | App.TauriWindowCentered
  | App.GotPlatform _
  | App.HideToTray
  | App.TrayHidden
  | App.TrayRestored
  | App.UpdateTrayTooltipInput _
  | App.SetTrayTooltip
  | App.TrayTooltipSet
  | App.SetTrayIconVisible _
  | App.TrayIconVisibleSet
  | App.StorageKeyChanged _
  | App.StorageValueChanged _
  | App.StorageGet
  | App.StorageGetResult _
  | App.StorageDelete
  | App.StorageDeleteResult _
  | App.StorageList
  | App.StorageListResult _
  | App.StorageClear
  | App.StorageClearResult _
  | App.StorageReload
  | App.CodecIncrement
  | App.CodecSave
  | App.CodecSaveResult _
  | App.CodecLoad
  | App.CodecLoadResult _
  | App.CodecCorrupt
  | App.CodecCorruptResult _
  | App.TauriStoreKeyChanged _
  | App.TauriStoreValueChanged _
  | App.TauriStoreDelete
  | App.TauriStoreDeleteResult _
  | App.TauriStoreClear
  | App.TauriStoreClearResult _
  | App.SubWizardMsg _ ->
      "<msg>"

let serialize_model (model : App.model) =
  let open App in
  (* The storage value is part of the asserted model surface so the web
     persistence spec can prove a reload-restored value via [assertModelContains]
     (RFC 0112, Step 6 / REQ-F3), not just the message fragment. *)
  let storage =
    match model.storage_state with
    | StorageIdle -> "idle"
    | StorageOk msg -> msg
    | StorageValue v -> v
    | StorageRestoredValue v -> "restored:" ^ v
    | StorageNotFound -> "not-found"
    | StorageKeys keys -> String.concat "," keys
    | StorageError e -> "error:" ^ e
  in
  (* The Tauri window visibility/title and store value are part of the asserted
     model surface so the REQ-F5 WebdriverIO specs (RFC 0112, Step 7) can prove
     a window transition or a relaunch-restored store value via
     [assertModelContains] through the host [get_telemetry] mirror. *)
  let tauri_store =
    match model.tauri_store_state with
    | TauriStoreIdle -> "idle"
    | TauriStoreOk msg -> msg
    | TauriStoreValue v -> v
    | TauriStoreNotFound -> "not-found"
    | TauriStoreError e -> "error:" ^ e
  in
  (* Each tab's stack depth is part of the asserted model surface so the RFC 0114
     preservation spec can prove [profile_depth=2;] survives a tab switch via
     [assertModelContains]. [Sub_bottom_tabs.serialize_model] already terminates
     each [field=value] with ';' (undelimited-telemetry-fragment-aliasing). *)
  Printf.sprintf
    "{pings=%d; clicks=%d; input=%S; storage=%s; win_visible=%b; win_title=%S; \
     tauri_store=%s; bottom_tabs={%s}}"
    model.telemetry_pings model.button_clicks model.input_text storage
    model.tauri_is_visible model.tauri_window_title tauri_store
    (Sub_bottom_tabs.serialize_model model.bottom_tabs)

(* The application owns telemetry policy: telemetry is on by default for the
   kitchen sink (it is the live E2E target), and disabled with [?telemetry=off]
   so the bridge-absent path is exercisable against the same app. *)
let telemetry_enabled () =
  let location = Jv.get (Jv.get Jv.global "window") "location" in
  let params =
    Jv.new' (Jv.get Jv.global "URLSearchParams") [| Jv.get location "search" |]
  in
  let value = Jv.call params "get" [| Jv.of_string "telemetry" |] in
  Jv.is_null value || not (String.equal (Jv.to_string value) "off")

let () =
  Nopal_http.register_backend { Nopal_http.send = Nopal_http_web.send };
  Nopal_http.register_cancellable_backend
    { Nopal_http.send_cancellable = Nopal_http_web.send_cancellable };
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
  let module Mounted = struct
    type model = App.model
    type msg = App.msg

    let init = init
    let update = update
    let view = App.view

    let subscriptions model =
      let base = App.subscriptions model in
      if has_tauri () then
        Nopal_mvu.Sub.batch [ base; Nopal_tauri.Tray.on_click App.TrayClicked ]
      else base
  end in
  if telemetry_enabled () then begin
    let handle : Nopal_runtime.Telemetry.handle =
      Nopal_web.mount_with_telemetry
        (module Mounted)
        ~serialize_msg ~serialize_model target
    in
    (* Feed the Tauri host-side telemetry mirror so the WebdriverIO REQ-F5 specs
       can read events through [Nopal_tauri.Telemetry.get_telemetry] from outside
       the webview (RFC 0112, Step 7). The underlying [plugin:event|emit] IPC is
       absent in a plain browser, so gate on [has_tauri]; the mirror is inert
       until this call (RFC Risk: [get_telemetry] returns [[]] otherwise). *)
    if has_tauri () then Nopal_tauri.Telemetry.expose handle
  end
  else Nopal_web.mount (module Mounted) target

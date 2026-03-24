open Kitchen_sink_app
open Nopal_test.Test_renderer

let pp_selector fmt sel =
  match sel with
  | By_tag t -> Format.fprintf fmt "By_tag %S" t
  | By_text t -> Format.fprintf fmt "By_text %S" t
  | By_attr (k, v) -> Format.fprintf fmt "By_attr (%S, %S)" k v
  | First_child -> Format.fprintf fmt "First_child"
  | Nth_child n -> Format.fprintf fmt "Nth_child %d" n

let error_testable =
  Alcotest.testable
    (fun fmt e ->
      match e with
      | Not_found sel -> Format.fprintf fmt "Not_found (%a)" pp_selector sel
      | No_handler { tag; event } ->
          Format.fprintf fmt "No_handler { tag = %S; event = %S }" tag event)
    ( = )

let msg_pp fmt msg =
  match msg with
  | FetchClicked -> Format.fprintf fmt "FetchClicked"
  | FetchResult _ -> Format.fprintf fmt "FetchResult _"
  | PostClicked -> Format.fprintf fmt "PostClicked"
  | PostResult _ -> Format.fprintf fmt "PostResult _"
  | PutClicked -> Format.fprintf fmt "PutClicked"
  | PutResult _ -> Format.fprintf fmt "PutResult _"
  | TimeoutClicked -> Format.fprintf fmt "TimeoutClicked"
  | TimeoutResult _ -> Format.fprintf fmt "TimeoutResult _"
  | ButtonClicked
  | InputChanged _
  | SubmitInputChanged _
  | InputSubmitted
  | AddKeyedItem
  | RemoveKeyedItem _
  | MoveKeyedItemUp _
  | ToggleInteraction
  | SubCounterMsg _
  | DrawPointerMove _
  | DrawPointerLeave
  | ChartHovered _
  | ChartLeft
  | PieHovered _
  | PieLeft
  | ScatterHovered _
  | ScatterLeft
  | HeatMapHovered _
  | HeatMapLeft
  | TradingHovered _
  | TradingLeft
  | PanePointerDown _
  | PanePointerMove _
  | PanePointerUp
  | PanePointerLeave
  | LinePointerDown _
  | LinePointerMove _
  | LinePointerUp
  | LinePointerLeave
  | LineWheelZoom _
  | ZoomIn
  | ZoomOut
  | FetchTauriInfo
  | GotAppName _
  | GotAppVersion _
  | GotTauriVersion _
  | EmitTauriEvent ->
      Format.fprintf fmt "EmitTauriEvent"
  | TauriEventReceived p -> Format.fprintf fmt "TauriEventReceived(%s)" p
  | TauriEventEmitted -> Format.fprintf fmt "TauriEventEmitted"
  | ListenTauriEvents -> Format.fprintf fmt "ListenTauriEvents"
  | UnlistenTauriEvents -> Format.fprintf fmt "UnlistenTauriEvents"
  | GotTauriUnlisten _ -> Format.fprintf fmt "GotTauriUnlisten(<fn>)"
  | SetTauriWindowTitle -> Format.fprintf fmt "SetTauriWindowTitle"
  | TauriWindowTitleSet -> Format.fprintf fmt "TauriWindowTitleSet"
  | UpdateTauriWindowTitleInput s ->
      Format.fprintf fmt "UpdateTauriWindowTitleInput(%s)" s
  | SetTauriFullscreen b -> Format.fprintf fmt "SetTauriFullscreen(%b)" b
  | QueryTauriFullscreen -> Format.fprintf fmt "QueryTauriFullscreen"
  | GotTauriFullscreen b -> Format.fprintf fmt "GotTauriFullscreen(%b)" b
  | MinimizeTauriWindow -> Format.fprintf fmt "MinimizeTauriWindow"
  | TauriWindowMinimized -> Format.fprintf fmt "TauriWindowMinimized"
  | MaximizeTauriWindow -> Format.fprintf fmt "MaximizeTauriWindow"
  | UnmaximizeTauriWindow -> Format.fprintf fmt "UnmaximizeTauriWindow"
  | QueryTauriMaximized -> Format.fprintf fmt "QueryTauriMaximized"
  | GotTauriMaximized b -> Format.fprintf fmt "GotTauriMaximized(%b)" b
  | CloseTauriWindow -> Format.fprintf fmt "CloseTauriWindow"
  | TauriWindowClosed -> Format.fprintf fmt "TauriWindowClosed"
  | UpdateTauriWindowWidth s ->
      Format.fprintf fmt "UpdateTauriWindowWidth(%s)" s
  | UpdateTauriWindowHeight s ->
      Format.fprintf fmt "UpdateTauriWindowHeight(%s)" s
  | SetTauriWindowSize (w, h) ->
      Format.fprintf fmt "SetTauriWindowSize(%d, %d)" w h
  | TauriWindowSizeSet -> Format.fprintf fmt "TauriWindowSizeSet"
  | QueryTauriInnerSize -> Format.fprintf fmt "QueryTauriInnerSize"
  | GotWindowInnerSize (w, h) ->
      Format.fprintf fmt "GotWindowInnerSize(%d, %d)" w h
  | ShowTauriWindow -> Format.fprintf fmt "ShowTauriWindow"
  | HideTauriWindow -> Format.fprintf fmt "HideTauriWindow"
  | QueryTauriVisible -> Format.fprintf fmt "QueryTauriVisible"
  | GotTauriVisible v -> Format.fprintf fmt "GotTauriVisible(%b)" v
  | SetTauriWindowFocus -> Format.fprintf fmt "SetTauriWindowFocus"
  | TauriWindowFocused -> Format.fprintf fmt "TauriWindowFocused"
  | CenterTauriWindow -> Format.fprintf fmt "CenterTauriWindow"
  | TauriWindowCentered -> Format.fprintf fmt "TauriWindowCentered"
  | GotPlatform s -> Format.fprintf fmt "GotPlatform(%s)" s
  | HideToTray -> Format.fprintf fmt "HideToTray"
  | TrayHidden -> Format.fprintf fmt "TrayHidden"
  | TrayClicked -> Format.fprintf fmt "TrayClicked"
  | TrayRestored -> Format.fprintf fmt "TrayRestored"
  | UpdateTrayTooltipInput s ->
      Format.fprintf fmt "UpdateTrayTooltipInput(%s)" s
  | SetTrayTooltip -> Format.fprintf fmt "SetTrayTooltip"
  | TrayTooltipSet -> Format.fprintf fmt "TrayTooltipSet"
  | SetTrayIconVisible b -> Format.fprintf fmt "SetTrayIconVisible(%b)" b
  | TrayIconVisibleSet -> Format.fprintf fmt "TrayIconVisibleSet"
  | StorageKeyChanged s -> Format.fprintf fmt "StorageKeyChanged(%s)" s
  | StorageValueChanged s -> Format.fprintf fmt "StorageValueChanged(%s)" s
  | StorageSet -> Format.fprintf fmt "StorageSet"
  | StorageGet -> Format.fprintf fmt "StorageGet"
  | StorageRemove -> Format.fprintf fmt "StorageRemove"
  | StorageClear -> Format.fprintf fmt "StorageClear"

let msg_testable = Alcotest.testable msg_pp ( = )

let idle_model () =
  let m, _ = init () in
  { m with http_state = Idle }

(* Parameterised view-state tests for each HTTP section *)
type section_config = {
  label : string;
  view_fn : model -> msg Nopal_element.Element.t;
  set_state : model -> http_state -> model;
  section_attr : string;
  prefix : string;
  btn_testid : string;
  click_msg : msg;
}

let http_section =
  {
    label = "http";
    view_fn = view_http;
    set_state = (fun m s -> { m with http_state = s });
    section_attr = "http";
    prefix = "http";
    btn_testid = "fetch-btn";
    click_msg = FetchClicked;
  }

let post_section =
  {
    label = "http_post";
    view_fn = view_http_post;
    set_state = (fun m s -> { m with post_state = s });
    section_attr = "http-post";
    prefix = "post";
    btn_testid = "post-btn";
    click_msg = PostClicked;
  }

let put_section =
  {
    label = "http_put";
    view_fn = view_http_put;
    set_state = (fun m s -> { m with put_state = s });
    section_attr = "http-put";
    prefix = "put";
    btn_testid = "put-btn";
    click_msg = PutClicked;
  }

let timeout_section =
  {
    label = "http_timeout";
    view_fn = view_http_timeout;
    set_state = (fun m s -> { m with timeout_state = s });
    section_attr = "http-timeout";
    prefix = "timeout";
    btn_testid = "timeout-btn";
    click_msg = TimeoutClicked;
  }

let test_idle cfg () =
  let model = cfg.set_state (idle_model ()) Idle in
  let r = render (cfg.view_fn model) in
  let t = tree r in
  let section = find (By_attr ("data-section", cfg.section_attr)) t in
  Alcotest.(check bool) "section exists" true (Option.is_some section);
  let btn = find (By_attr ("data-testid", cfg.btn_testid)) t in
  Alcotest.(check bool) "button exists" true (Option.is_some btn);
  let idle = find (By_attr ("data-testid", cfg.prefix ^ "-idle")) t in
  Alcotest.(check bool) "idle placeholder exists" true (Option.is_some idle);
  let loading = find (By_text "Loading") t in
  Alcotest.(check bool) "no loading text" true (Option.is_none loading)

let test_loading cfg () =
  let model = cfg.set_state (idle_model ()) Loading in
  let r = render (cfg.view_fn model) in
  let t = tree r in
  let loading = find (By_attr ("data-testid", cfg.prefix ^ "-status")) t in
  Alcotest.(check bool) "status element exists" true (Option.is_some loading);
  let status_text =
    match loading with
    | Some node -> text_content node
    | None -> ""
  in
  Alcotest.(check string) "shows loading" "Loading\u{2026}" status_text

let test_success cfg () =
  let model = cfg.set_state (idle_model ()) (Success "response body here") in
  let r = render (cfg.view_fn model) in
  let t = tree r in
  let result = find (By_attr ("data-testid", cfg.prefix ^ "-result")) t in
  Alcotest.(check bool) "result element exists" true (Option.is_some result);
  let result_text =
    match result with
    | Some node -> text_content node
    | None -> ""
  in
  Alcotest.(check string) "shows response body" "response body here" result_text

let test_error cfg () =
  let model = cfg.set_state (idle_model ()) (Errored "connection refused") in
  let r = render (cfg.view_fn model) in
  let t = tree r in
  let err = find (By_attr ("data-testid", cfg.prefix ^ "-error")) t in
  Alcotest.(check bool) "error element exists" true (Option.is_some err);
  let err_text =
    match err with
    | Some node -> text_content node
    | None -> ""
  in
  Alcotest.(check string) "shows error" "connection refused" err_text

let test_click cfg () =
  let model = idle_model () in
  let r = render (cfg.view_fn model) in
  let result = click (By_attr ("data-testid", cfg.btn_testid)) r in
  Alcotest.(check (result unit error_testable)) "click succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    ("dispatches " ^ cfg.label)
    [ cfg.click_msg ] (messages r)

let section_tests cfg =
  ( cfg.label ^ "_section",
    [
      Alcotest.test_case "idle state" `Quick (test_idle cfg);
      Alcotest.test_case "loading state" `Quick (test_loading cfg);
      Alcotest.test_case "success state" `Quick (test_success cfg);
      Alcotest.test_case "error state" `Quick (test_error cfg);
      Alcotest.test_case "click dispatches msg" `Quick (test_click cfg);
    ] )

let test_view_http_put_shows_headers () =
  let model =
    {
      (idle_model ()) with
      put_state = Success "body";
      resp_headers =
        [ ("content-type", "application/json"); ("x-request-id", "abc-123") ];
    }
  in
  let r = render (view_http_put model) in
  let t = tree r in
  let headers_el = find (By_attr ("data-testid", "resp-headers")) t in
  Alcotest.(check bool)
    "headers element exists" true
    (Option.is_some headers_el);
  let headers_text =
    match headers_el with
    | Some node -> text_content node
    | None -> ""
  in
  Alcotest.(check bool)
    "shows content-type header" true
    (Test_util.string_contains headers_text ~sub:"application/json")

let test_tauri_event_received_prepends () =
  let model = idle_model () in
  let model = { model with tauri_events = [ "first" ] } in
  let model', _ = update model (TauriEventReceived "second") in
  Alcotest.(check (list string))
    "prepends new event" [ "second"; "first" ] model'.tauri_events

let test_tauri_event_received_caps_at_20 () =
  let model = idle_model () in
  let events = List.init 20 (fun i -> "event-" ^ string_of_int i) in
  let model = { model with tauri_events = events } in
  let model', _ = update model (TauriEventReceived "overflow") in
  Alcotest.(check int) "capped at 20" 20 (List.length model'.tauri_events);
  Alcotest.(check string)
    "newest is first" "overflow"
    (List.hd model'.tauri_events)

let test_got_tauri_unlisten_stores () =
  let model = idle_model () in
  let called = ref false in
  let f () = called := true in
  let model', _ = update model (GotTauriUnlisten f) in
  Alcotest.(check bool)
    "unlisten stored" true
    (Option.is_some model'.tauri_event_unlisten);
  (match model'.tauri_event_unlisten with
  | Some g -> g ()
  | None -> ());
  Alcotest.(check bool) "stored function is the one we passed" true !called

let test_unlisten_tauri_events_clears () =
  let f () = () in
  let model = idle_model () in
  let model = { model with tauri_event_unlisten = Some f } in
  let model', _ = update model UnlistenTauriEvents in
  Alcotest.(check bool)
    "unlisten cleared" true
    (Option.is_none model'.tauri_event_unlisten)

let test_unlisten_tauri_events_noop_when_none () =
  let model = idle_model () in
  let model', _ = update model UnlistenTauriEvents in
  Alcotest.(check bool)
    "remains None" true
    (Option.is_none model'.tauri_event_unlisten)

let test_view_tauri_events_shows_emit_button () =
  let model = idle_model () in
  let r = render (view_tauri_events model) in
  let t = tree r in
  let btn = find (By_text "Emit Event") t in
  Alcotest.(check bool) "emit button exists" true (Option.is_some btn)

let test_view_tauri_events_shows_start_listening () =
  let model = idle_model () in
  let r = render (view_tauri_events model) in
  let t = tree r in
  let btn = find (By_text "Start Listening") t in
  Alcotest.(check bool)
    "start listening button exists" true (Option.is_some btn)

let test_view_tauri_events_shows_stop_listening () =
  let model = idle_model () in
  let r = render (view_tauri_events model) in
  let t = tree r in
  let btn = find (By_text "Stop Listening") t in
  Alcotest.(check bool) "stop listening button exists" true (Option.is_some btn)

let test_view_tauri_events_status_not_listening () =
  let model = idle_model () in
  let r = render (view_tauri_events model) in
  let t = tree r in
  let status = find (By_text "Status: Not listening") t in
  Alcotest.(check bool) "shows not listening" true (Option.is_some status)

let test_view_tauri_events_status_listening () =
  let model = idle_model () in
  let model = { model with tauri_event_unlisten = Some (fun () -> ()) } in
  let r = render (view_tauri_events model) in
  let t = tree r in
  let status = find (By_text "Status: Listening") t in
  Alcotest.(check bool) "shows listening" true (Option.is_some status)

let () =
  Alcotest.run "kitchen_sink_http"
    [
      section_tests http_section;
      section_tests post_section;
      section_tests put_section;
      section_tests timeout_section;
      ( "http_put_extras",
        [
          Alcotest.test_case "put shows response headers" `Quick
            test_view_http_put_shows_headers;
        ] );
      ( "tauri_events",
        [
          Alcotest.test_case "received prepends to list" `Quick
            test_tauri_event_received_prepends;
          Alcotest.test_case "received caps at 20" `Quick
            test_tauri_event_received_caps_at_20;
          Alcotest.test_case "GotTauriUnlisten stores function" `Quick
            test_got_tauri_unlisten_stores;
          Alcotest.test_case "UnlistenTauriEvents clears" `Quick
            test_unlisten_tauri_events_clears;
          Alcotest.test_case "UnlistenTauriEvents noop when None" `Quick
            test_unlisten_tauri_events_noop_when_none;
          Alcotest.test_case "view has Emit Event button" `Quick
            test_view_tauri_events_shows_emit_button;
          Alcotest.test_case "view has Start Listening button" `Quick
            test_view_tauri_events_shows_start_listening;
          Alcotest.test_case "view has Stop Listening button" `Quick
            test_view_tauri_events_shows_stop_listening;
          Alcotest.test_case "view shows Not listening status" `Quick
            test_view_tauri_events_status_not_listening;
          Alcotest.test_case "view shows Listening status" `Quick
            test_view_tauri_events_status_listening;
        ] );
    ]

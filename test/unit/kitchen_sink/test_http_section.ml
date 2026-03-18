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
  | ZoomOut ->
      Format.fprintf fmt "<other>"

let msg_testable = Alcotest.testable msg_pp ( = )

let idle_model () =
  let m, _ = init () in
  { m with http_state = Idle }

let test_view_http_idle () =
  let model = idle_model () in
  let r = render (view_http model) in
  let t = tree r in
  (* Section has data-section="http" *)
  let section = find (By_attr ("data-section", "http")) t in
  Alcotest.(check bool) "http section exists" true (Option.is_some section);
  (* Has a fetch button *)
  let btn = find (By_attr ("data-testid", "fetch-btn")) t in
  Alcotest.(check bool) "fetch button exists" true (Option.is_some btn);
  (* Idle placeholder text *)
  let idle = find (By_attr ("data-testid", "http-idle")) t in
  Alcotest.(check bool) "idle placeholder exists" true (Option.is_some idle);
  (* No loading or result text in idle *)
  let loading = find (By_text "Loading") t in
  Alcotest.(check bool) "no loading text" true (Option.is_none loading)

let test_view_http_loading () =
  let model = { (idle_model ()) with http_state = Loading } in
  let r = render (view_http model) in
  let t = tree r in
  let loading = find (By_attr ("data-testid", "http-status")) t in
  Alcotest.(check bool) "status element exists" true (Option.is_some loading);
  let status_text =
    match loading with
    | Some node -> text_content node
    | None -> ""
  in
  Alcotest.(check string) "shows loading" "Loading…" status_text

let test_view_http_success () =
  let model =
    { (idle_model ()) with http_state = Success "response body here" }
  in
  let r = render (view_http model) in
  let t = tree r in
  let result = find (By_attr ("data-testid", "http-result")) t in
  Alcotest.(check bool) "result element exists" true (Option.is_some result);
  let result_text =
    match result with
    | Some node -> text_content node
    | None -> ""
  in
  Alcotest.(check string) "shows response body" "response body here" result_text

let test_view_http_error () =
  let model =
    { (idle_model ()) with http_state = Errored "connection refused" }
  in
  let r = render (view_http model) in
  let t = tree r in
  let err = find (By_attr ("data-testid", "http-error")) t in
  Alcotest.(check bool) "error element exists" true (Option.is_some err);
  let err_text =
    match err with
    | Some node -> text_content node
    | None -> ""
  in
  Alcotest.(check string) "shows error" "connection refused" err_text

let test_click_fetch_dispatches_msg () =
  let model = idle_model () in
  let r = render (view_http model) in
  let result = click (By_attr ("data-testid", "fetch-btn")) r in
  Alcotest.(check (result unit error_testable)) "click succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "dispatches FetchClicked" [ FetchClicked ] (messages r)

let () =
  Alcotest.run "kitchen_sink_http"
    [
      ( "http_section",
        [
          Alcotest.test_case "idle state" `Quick test_view_http_idle;
          Alcotest.test_case "loading state" `Quick test_view_http_loading;
          Alcotest.test_case "success state" `Quick test_view_http_success;
          Alcotest.test_case "error state" `Quick test_view_http_error;
          Alcotest.test_case "click dispatches FetchClicked" `Quick
            test_click_fetch_dispatches_msg;
        ] );
    ]

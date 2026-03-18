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

(* Parameterised view-state tests for each HTTP section *)
type section_config = {
  label : string;
  view_fn : model -> msg Nopal_element.Element.t;
  set_state : model -> http_state -> model;
  section_attr : string;
  prefix : string;
  click_msg : msg;
}

let http_section =
  {
    label = "http";
    view_fn = view_http;
    set_state = (fun m s -> { m with http_state = s });
    section_attr = "http";
    prefix = "http";
    click_msg = FetchClicked;
  }

let post_section =
  {
    label = "http_post";
    view_fn = view_http_post;
    set_state = (fun m s -> { m with post_state = s });
    section_attr = "http-post";
    prefix = "post";
    click_msg = PostClicked;
  }

let put_section =
  {
    label = "http_put";
    view_fn = view_http_put;
    set_state = (fun m s -> { m with put_state = s });
    section_attr = "http-put";
    prefix = "put";
    click_msg = PutClicked;
  }

let test_idle cfg () =
  let model = cfg.set_state (idle_model ()) Idle in
  let r = render (cfg.view_fn model) in
  let t = tree r in
  let section = find (By_attr ("data-section", cfg.section_attr)) t in
  Alcotest.(check bool) "section exists" true (Option.is_some section);
  let btn_id = cfg.prefix ^ "-btn" in
  let btn =
    match cfg.prefix with
    | "http" -> find (By_attr ("data-testid", "fetch-btn")) t
    | _ -> find (By_attr ("data-testid", btn_id)) t
  in
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
  let btn_id =
    match cfg.prefix with
    | "http" -> "fetch-btn"
    | _ -> cfg.prefix ^ "-btn"
  in
  let result = click (By_attr ("data-testid", btn_id)) r in
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
  let contains_substr s sub =
    let slen = String.length s in
    let sublen = String.length sub in
    if sublen > slen then false
    else
      let found = ref false in
      for i = 0 to slen - sublen do
        if String.sub s i sublen = sub then found := true
      done;
      !found
  in
  Alcotest.(check bool)
    "shows content-type header" true
    (contains_substr headers_text "application/json")

let () =
  Alcotest.run "kitchen_sink_http"
    [
      section_tests http_section;
      section_tests post_section;
      section_tests put_section;
      ( "http_put_extras",
        [
          Alcotest.test_case "put shows response headers" `Quick
            test_view_http_put_shows_headers;
        ] );
    ]

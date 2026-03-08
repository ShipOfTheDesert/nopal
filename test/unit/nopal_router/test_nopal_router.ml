type route = Home | About | Item of int | NotFound

let parse = function
  | "/" -> Some Home
  | "/about" -> Some About
  | path -> (
      match String.split_on_char '/' path with
      | [ ""; "items"; id ] -> (
          match int_of_string_opt id with
          | Some n -> Some (Item n)
          | None -> None)
      | [ ""; "" ]
      | [] ->
          Some Home
      | _ -> None)

let to_path = function
  | Home -> "/"
  | About -> "/about"
  | Item id -> "/items/" ^ string_of_int id
  | NotFound -> "/not-found"

let route_equal a b =
  match (a, b) with
  | Home, Home -> true
  | About, About -> true
  | Item a, Item b -> a = b
  | NotFound, NotFound -> true
  | Home, _
  | About, _
  | Item _, _
  | NotFound, _ ->
      false

let route_to_string = function
  | Home -> "Home"
  | About -> "About"
  | Item id -> "Item " ^ string_of_int id
  | NotFound -> "NotFound"

let route_testable =
  Alcotest.testable (Fmt.of_to_string route_to_string) route_equal

(* Fields used by later tasks for navigation command testing *)
type mock_controls = {
  get_path : unit -> string;
  history : unit -> string list;
  simulate_popstate : string -> unit;
}

let make_mock_platform initial_path =
  let current = ref initial_path in
  let hist = ref [ initial_path ] in
  let hist_index = ref 0 in
  let popstate_listener : (string -> unit) option ref = ref None in
  let platform =
    (module struct
      let current_path () = !current

      let push_state path =
        let before = List.filteri (fun i _ -> i <= !hist_index) !hist in
        hist := before @ [ path ];
        hist_index := List.length !hist - 1;
        current := path

      let replace_state path =
        hist := List.mapi (fun i p -> if i = !hist_index then path else p) !hist;
        current := path

      let back () =
        if !hist_index > 0 then (
          hist_index := !hist_index - 1;
          let path = List.nth !hist !hist_index in
          current := path;
          match !popstate_listener with
          | Some f -> f path
          | None -> ())

      let on_popstate callback =
        popstate_listener := Some callback;
        fun () -> popstate_listener := None
    end : Nopal_router.Platform.S)
  in
  let controls =
    {
      get_path = (fun () -> !current);
      history = (fun () -> !hist);
      simulate_popstate =
        (fun path ->
          current := path;
          match !popstate_listener with
          | Some f -> f path
          | None -> ());
    }
  in
  (platform, controls)

let make_router platform =
  Nopal_router.Router.create ~platform ~parse ~to_path ~not_found:NotFound

let test_current_returns_parsed_route () =
  let platform, _controls = make_mock_platform "/" in
  let router = make_router platform in
  Alcotest.check route_testable "current is Home" Home
    (Nopal_router.Router.current router)

let test_current_unknown_path_returns_not_found () =
  let platform, _controls = make_mock_platform "/unknown" in
  let router = make_router platform in
  Alcotest.check route_testable "current is NotFound" NotFound
    (Nopal_router.Router.current router)

let test_roundtrip_static_routes () =
  let check route =
    let path = to_path route in
    let parsed = parse path in
    Alcotest.check
      (Alcotest.option route_testable)
      ("roundtrip " ^ route_to_string route)
      (Some route) parsed
  in
  check Home;
  check About

let test_roundtrip_dynamic_segment () =
  let route = Item 42 in
  let path = to_path route in
  let parsed = parse path in
  Alcotest.check
    (Alcotest.option route_testable)
    "roundtrip Item 42" (Some (Item 42)) parsed

let test_push_updates_platform_path () =
  let platform, controls = make_mock_platform "/" in
  let router = make_router platform in
  let cmd = Nopal_router.Router.push router About in
  Nopal_mvu.Cmd.execute ignore cmd;
  Alcotest.(check string) "path is /about" "/about" (controls.get_path ())

let test_push_adds_history_entry () =
  let platform, controls = make_mock_platform "/" in
  let router = make_router platform in
  let cmd = Nopal_router.Router.push router About in
  Nopal_mvu.Cmd.execute ignore cmd;
  Alcotest.(check int)
    "history has 2 entries" 2
    (List.length (controls.history ()))

let test_replace_updates_platform_path () =
  let platform, controls = make_mock_platform "/" in
  let router = make_router platform in
  let cmd = Nopal_router.Router.replace router About in
  Nopal_mvu.Cmd.execute ignore cmd;
  Alcotest.(check string) "path is /about" "/about" (controls.get_path ())

let test_replace_no_new_history_entry () =
  let platform, controls = make_mock_platform "/" in
  let router = make_router platform in
  let cmd = Nopal_router.Router.replace router About in
  Nopal_mvu.Cmd.execute ignore cmd;
  Alcotest.(check int)
    "history still has 1 entry" 1
    (List.length (controls.history ()))

let test_back_navigates_previous () =
  let platform, controls = make_mock_platform "/" in
  let router = make_router platform in
  let push_cmd = Nopal_router.Router.push router About in
  Nopal_mvu.Cmd.execute ignore push_cmd;
  let back_cmd = Nopal_router.Router.back router in
  Nopal_mvu.Cmd.execute ignore back_cmd;
  Alcotest.(check string) "path is /" "/" (controls.get_path ())

let test_current_after_push () =
  let platform, _controls = make_mock_platform "/" in
  let router = make_router platform in
  let cmd = Nopal_router.Router.push router (Item 7) in
  Nopal_mvu.Cmd.execute ignore cmd;
  Alcotest.check route_testable "current is Item 7 after push" (Item 7)
    (Nopal_router.Router.current router)

let test_on_navigate_dispatches_on_popstate () =
  let platform, controls = make_mock_platform "/" in
  let router = make_router platform in
  let received = ref None in
  let sub = Nopal_router.Router.on_navigate router (fun route -> route) in
  let setup = Option.get (Nopal_mvu.Sub.extract_custom sub) in
  let cleanup = setup (fun msg -> received := Some msg) in
  controls.simulate_popstate "/about";
  Alcotest.check
    (Alcotest.option route_testable)
    "dispatched About" (Some About) !received;
  cleanup ()

let test_on_navigate_unknown_returns_not_found () =
  let platform, controls = make_mock_platform "/" in
  let router = make_router platform in
  let received = ref None in
  let sub = Nopal_router.Router.on_navigate router (fun route -> route) in
  let setup = Option.get (Nopal_mvu.Sub.extract_custom sub) in
  let cleanup = setup (fun msg -> received := Some msg) in
  controls.simulate_popstate "/unknown/path";
  Alcotest.check
    (Alcotest.option route_testable)
    "dispatched NotFound" (Some NotFound) !received;
  cleanup ()

let test_on_navigate_dynamic_segment () =
  let platform, controls = make_mock_platform "/" in
  let router = make_router platform in
  let received = ref None in
  let sub = Nopal_router.Router.on_navigate router (fun route -> route) in
  let setup = Option.get (Nopal_mvu.Sub.extract_custom sub) in
  let cleanup = setup (fun msg -> received := Some msg) in
  controls.simulate_popstate "/items/99";
  Alcotest.check
    (Alcotest.option route_testable)
    "dispatched Item 99" (Some (Item 99)) !received;
  cleanup ()

let test_on_navigate_cleanup_stops_listener () =
  let platform, controls = make_mock_platform "/" in
  let router = make_router platform in
  let received = ref None in
  let sub = Nopal_router.Router.on_navigate router (fun route -> route) in
  let setup = Option.get (Nopal_mvu.Sub.extract_custom sub) in
  let cleanup = setup (fun msg -> received := Some msg) in
  cleanup ();
  controls.simulate_popstate "/about";
  Alcotest.check
    (Alcotest.option route_testable)
    "no dispatch after cleanup" None !received

let () =
  Alcotest.run "nopal_router"
    [
      ( "current",
        [
          Alcotest.test_case "returns parsed route" `Quick
            test_current_returns_parsed_route;
          Alcotest.test_case "unknown path returns not_found" `Quick
            test_current_unknown_path_returns_not_found;
        ] );
      ( "roundtrip",
        [
          Alcotest.test_case "static routes" `Quick test_roundtrip_static_routes;
          Alcotest.test_case "dynamic segment" `Quick
            test_roundtrip_dynamic_segment;
        ] );
      ( "navigation",
        [
          Alcotest.test_case "push updates platform path" `Quick
            test_push_updates_platform_path;
          Alcotest.test_case "push adds history entry" `Quick
            test_push_adds_history_entry;
          Alcotest.test_case "replace updates platform path" `Quick
            test_replace_updates_platform_path;
          Alcotest.test_case "replace no new history entry" `Quick
            test_replace_no_new_history_entry;
          Alcotest.test_case "back navigates previous" `Quick
            test_back_navigates_previous;
          Alcotest.test_case "current after push" `Quick test_current_after_push;
        ] );
      ( "on_navigate",
        [
          Alcotest.test_case "dispatches on popstate" `Quick
            test_on_navigate_dispatches_on_popstate;
          Alcotest.test_case "unknown returns not_found" `Quick
            test_on_navigate_unknown_returns_not_found;
          Alcotest.test_case "dynamic segment" `Quick
            test_on_navigate_dynamic_segment;
          Alcotest.test_case "cleanup stops listener" `Quick
            test_on_navigate_cleanup_stops_listener;
        ] );
    ]

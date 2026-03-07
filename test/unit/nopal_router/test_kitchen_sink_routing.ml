open Nopal_test.Test_renderer
module E = Nopal_element.Element

type route = Home | About | Item of int | NotFound

module Kitchen_sink_routing = struct
  type model = { current_route : route }
  type msg = Navigate_to of route | Route_changed of route

  let init () = ({ current_route = Home }, Nopal_mvu.Cmd.none)

  let update _model = function
    | Navigate_to route -> ({ current_route = route }, Nopal_mvu.Cmd.none)
    | Route_changed route -> ({ current_route = route }, Nopal_mvu.Cmd.none)

  let view_for_route = function
    | Home ->
        E.column
          [
            E.text "Home Page";
            E.button ~on_click:(Navigate_to About) (E.text "Go to About");
            E.button ~on_click:(Navigate_to (Item 1)) (E.text "Go to Item 1");
          ]
    | About ->
        E.column
          [
            E.text "About Page";
            E.button ~on_click:(Navigate_to Home) (E.text "Go Home");
          ]
    | Item id ->
        E.column
          [
            E.text ("Item " ^ string_of_int id);
            E.button ~on_click:(Navigate_to Home) (E.text "Go Home");
          ]
    | NotFound ->
        E.column
          [
            E.text "Page Not Found";
            E.button ~on_click:(Navigate_to Home) (E.text "Go Home");
          ]

  let view model =
    E.column
      [
        E.text "Routing Demo";
        E.row
          [
            E.button ~on_click:(Navigate_to Home) (E.text "Home");
            E.button ~on_click:(Navigate_to About) (E.text "About");
            E.button ~on_click:(Navigate_to (Item 42)) (E.text "Item 42");
          ];
        view_for_route model.current_route;
      ]
end

let test_home_view () =
  let _model, rendered =
    run_app ~init:Kitchen_sink_routing.init ~update:Kitchen_sink_routing.update
      ~view:Kitchen_sink_routing.view []
  in
  let t = tree rendered in
  let home_text = find (By_text "Home Page") t in
  Alcotest.(check bool) "home page text present" true (Option.is_some home_text);
  let nav_about = find (By_text "Go to About") t in
  Alcotest.(check bool) "nav to about present" true (Option.is_some nav_about)

let test_about_view () =
  let _model, rendered =
    run_app ~init:Kitchen_sink_routing.init ~update:Kitchen_sink_routing.update
      ~view:Kitchen_sink_routing.view
      [ Kitchen_sink_routing.Navigate_to About ]
  in
  let t = tree rendered in
  let about_text = find (By_text "About Page") t in
  Alcotest.(check bool)
    "about page text present" true
    (Option.is_some about_text);
  let go_home = find (By_text "Go Home") t in
  Alcotest.(check bool) "go home button present" true (Option.is_some go_home)

let test_item_view () =
  let _model, rendered =
    run_app ~init:Kitchen_sink_routing.init ~update:Kitchen_sink_routing.update
      ~view:Kitchen_sink_routing.view
      [ Kitchen_sink_routing.Navigate_to (Item 7) ]
  in
  let t = tree rendered in
  let item_text = find (By_text "Item 7") t in
  Alcotest.(check bool) "item 7 text present" true (Option.is_some item_text)

let test_not_found_view () =
  let _model, rendered =
    run_app ~init:Kitchen_sink_routing.init ~update:Kitchen_sink_routing.update
      ~view:Kitchen_sink_routing.view
      [ Kitchen_sink_routing.Route_changed NotFound ]
  in
  let t = tree rendered in
  let nf_text = find (By_text "Page Not Found") t in
  Alcotest.(check bool) "not found text present" true (Option.is_some nf_text)

let test_nav_bar_present () =
  let _model, rendered =
    run_app ~init:Kitchen_sink_routing.init ~update:Kitchen_sink_routing.update
      ~view:Kitchen_sink_routing.view []
  in
  let t = tree rendered in
  let title = find (By_text "Routing Demo") t in
  Alcotest.(check bool) "routing demo title present" true (Option.is_some title);
  let home_btn = find (By_text "Home") t in
  Alcotest.(check bool) "home nav button present" true (Option.is_some home_btn);
  let about_btn = find (By_text "About") t in
  Alcotest.(check bool)
    "about nav button present" true (Option.is_some about_btn);
  let item_btn = find (By_text "Item 42") t in
  Alcotest.(check bool)
    "item 42 nav button present" true (Option.is_some item_btn)

let test_navigation_updates_view () =
  let model, _rendered =
    run_app ~init:Kitchen_sink_routing.init ~update:Kitchen_sink_routing.update
      ~view:Kitchen_sink_routing.view
      [
        Kitchen_sink_routing.Navigate_to About;
        Kitchen_sink_routing.Navigate_to (Item 3);
      ]
  in
  Alcotest.(check bool)
    "model ends on Item 3" true
    (match model.current_route with
    | Item 3 -> true
    | _ -> false)

let test_subscriptions_returns_on_navigate () =
  let platform, _controls =
    let current = ref "/" in
    let popstate_listener : (string -> unit) option ref = ref None in
    let p =
      (module struct
        let current_path () = !current
        let push_state path = current := path
        let replace_state path = current := path
        let back () = ()

        let on_popstate callback =
          popstate_listener := Some callback;
          fun () -> popstate_listener := None
      end : Nopal_router.Platform.S)
    in
    (p, ())
  in
  let router =
    Nopal_router.Router.create ~platform
      ~parse:(function
        | "/" -> Some Home
        | "/about" -> Some About
        | _ -> None)
      ~to_path:(function
        | Home -> "/"
        | About -> "/about"
        | Item _ -> "/items/0"
        | NotFound -> "/not-found")
      ~not_found:NotFound
  in
  let sub =
    Nopal_router.Router.on_navigate router (fun route ->
        Kitchen_sink_routing.Route_changed route)
  in
  let extracted = Nopal_mvu.Sub.extract_custom sub in
  Alcotest.(check bool)
    "on_navigate returns a custom subscription" true (Option.is_some extracted)

let () =
  Alcotest.run "kitchen_sink_routing"
    [
      ( "view",
        [
          Alcotest.test_case "home view" `Quick test_home_view;
          Alcotest.test_case "about view" `Quick test_about_view;
          Alcotest.test_case "item view" `Quick test_item_view;
          Alcotest.test_case "not found view" `Quick test_not_found_view;
          Alcotest.test_case "nav bar present" `Quick test_nav_bar_present;
          Alcotest.test_case "navigation updates view" `Quick
            test_navigation_updates_view;
        ] );
      ( "subscriptions",
        [
          Alcotest.test_case "on_navigate returns subscription" `Quick
            test_subscriptions_returns_on_navigate;
        ] );
    ]

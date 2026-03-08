open Nopal_test.Test_renderer
open Kitchen_sink_app

let make_test_router () =
  let platform =
    (module struct
      let current_path () = "/"
      let push_state _ = ()
      let replace_state _ = ()
      let back () = ()
      let on_popstate _ = fun () -> ()
    end : Nopal_router.Platform.S)
  in
  Nopal_router.Router.create ~platform ~parse ~to_path ~not_found:NotFound

let router = make_test_router ()
let test_init = init router
let test_update = update
let test_view = view

let test_home_view () =
  let _model, rendered =
    run_app ~init:test_init ~update:test_update ~view:test_view []
  in
  let t = tree rendered in
  let home_text = find (By_text "Home Page") t in
  Alcotest.(check bool) "home page text present" true (Option.is_some home_text);
  let nav_about = find (By_text "Go to About") t in
  Alcotest.(check bool) "nav to about present" true (Option.is_some nav_about)

let test_about_view () =
  let _model, rendered =
    run_app ~init:test_init ~update:test_update ~view:test_view
      [ Navigate_to About ]
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
    run_app ~init:test_init ~update:test_update ~view:test_view
      [ Navigate_to (Item 7) ]
  in
  let t = tree rendered in
  let item_text = find (By_text "Item 7") t in
  Alcotest.(check bool) "item 7 text present" true (Option.is_some item_text)

let test_not_found_view () =
  let _model, rendered =
    run_app ~init:test_init ~update:test_update ~view:test_view
      [ Route_changed NotFound ]
  in
  let t = tree rendered in
  let nf_text = find (By_text "Page Not Found") t in
  Alcotest.(check bool) "not found text present" true (Option.is_some nf_text)

let test_nav_bar_present () =
  let _model, rendered =
    run_app ~init:test_init ~update:test_update ~view:test_view []
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
    run_app ~init:test_init ~update:test_update ~view:test_view
      [ Navigate_to About; Navigate_to (Item 3) ]
  in
  Alcotest.(check bool)
    "model ends on Item 3" true
    (match model.current_route with
    | Item 3 -> true
    | Home
    | About
    | Item _
    | NotFound ->
        false)

let test_subscriptions_returns_on_navigate () =
  let sub =
    Nopal_router.Router.on_navigate router (fun route -> Route_changed route)
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

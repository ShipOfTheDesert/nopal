(* Structural clicks on [Element.link]: the action [Link.decide] answers for the
   host, button and modifiers given, and the message appended only when that
   action dispatches one. *)

open Nopal_element
module TR = Nopal_test.Test_renderer

type msg = Followed | Open_failed

let path_text = "/inbox"
let url_text = "https://nopal-test-7Q2.example/"

let route_path =
  match Route_path.of_string path_text with
  | Ok path -> path
  | Error
      ( Route_path.Not_absolute _ | Route_path.Protocol_relative _
      | Route_path.Control_character _ ) ->
      Alcotest.fail "fixture path is refused"

let url =
  match Url.of_string url_text with
  | Ok url -> url
  | Error
      (Url.Missing_scheme _ | Url.Unsupported_scheme _ | Url.Control_character _)
    ->
      Alcotest.fail "fixture URL is refused"

let route_link () =
  Element.link
    (Link.Route { path = route_path; on_follow = Followed })
    (Element.text "Inbox")

let external_link () =
  Element.link
    (Link.External { url; on_open_failed = (fun _ -> Open_failed) })
    (Element.text "Docs")

let plain_primary =
  {
    Link.button = Link.Primary;
    ctrl = false;
    meta = false;
    shift = false;
    alt = false;
  }

let ctrl_primary =
  {
    Link.button = Link.Primary;
    ctrl = true;
    meta = false;
    shift = false;
    alt = false;
  }

let pp_msg fmt = function
  | Followed -> Format.pp_print_string fmt "Followed"
  | Open_failed -> Format.pp_print_string fmt "Open_failed"

let msg_t = Alcotest.testable pp_msg ( = )

let pp_action fmt = function
  | Link.Navigate m -> Format.fprintf fmt "Navigate %a" pp_msg m
  | Link.Leave_to_platform -> Format.pp_print_string fmt "Leave_to_platform"
  | Link.Open_externally { url = u; _ } ->
      Format.fprintf fmt "Open_externally %s" (Url.to_string u)

let equal_action a b =
  match (a, b) with
  | Link.Navigate x, Link.Navigate y -> x = y
  | Link.Leave_to_platform, Link.Leave_to_platform -> true
  | Link.Open_externally { url = x; _ }, Link.Open_externally { url = y; _ } ->
      String.equal (Url.to_string x) (Url.to_string y)
  | (Link.Navigate _ | Link.Leave_to_platform | Link.Open_externally _), _ ->
      false

let pp_error fmt = function
  | TR.Not_found _ -> Format.pp_print_string fmt "Not_found"
  | TR.No_handler { tag; event } ->
      Format.fprintf fmt "No_handler { tag = %s; event = %s }" tag event

let result_t =
  Alcotest.result
    (Alcotest.testable pp_action equal_action)
    (Alcotest.testable pp_error ( = ))

let test_click_link_navigate_appends_msg () =
  let r = TR.render (route_link ()) in
  Alcotest.check result_t "a plain primary click in a browser navigates"
    (Ok (Link.Navigate Followed))
    (TR.click_link ~host:Link.Browser plain_primary (TR.By_tag "a") r);
  Alcotest.(check (list msg_t))
    "the on_follow message is appended once" [ Followed ] (TR.messages r)

let test_click_link_leave_appends_nothing () =
  let r = TR.render (route_link ()) in
  Alcotest.check result_t "a Ctrl+primary click in a browser is left to it"
    (Ok Link.Leave_to_platform)
    (TR.click_link ~host:Link.Browser ctrl_primary (TR.By_tag "a") r);
  Alcotest.(check (list msg_t)) "nothing is appended" [] (TR.messages r);
  Alcotest.(check (option string))
    "the anchor still carries its href for the browser to follow"
    (Some path_text)
    (TR.attr "href" (TR.tree r))

let test_click_link_webview_external_reports_open () =
  let r = TR.render (external_link ()) in
  Alcotest.check result_t
    "a primary click on an External link in a webview opens it"
    (Ok (Link.Open_externally { url; on_open_failed = (fun _ -> Open_failed) }))
    (TR.click_link ~host:Link.Webview plain_primary (TR.By_tag "a") r);
  Alcotest.(check (list msg_t)) "nothing is appended" [] (TR.messages r)

let test_click_link_not_a_link_is_error () =
  let r =
    TR.render
      (Element.column
         [
           Element.button ~on_click:Followed (Element.text "Go"); route_link ();
         ])
  in
  Alcotest.check result_t "a button is not a link"
    (Error (TR.No_handler { tag = "button"; event = "click" }))
    (TR.click_link ~host:Link.Browser plain_primary (TR.By_tag "button") r);
  Alcotest.(check (list msg_t))
    "the refused click appends nothing" [] (TR.messages r);
  Alcotest.check result_t "the link beside it on the same tree is clickable"
    (Ok (Link.Navigate Followed))
    (TR.click_link ~host:Link.Browser plain_primary (TR.By_tag "a") r);
  Alcotest.(check (list msg_t))
    "and its click appends its message" [ Followed ] (TR.messages r)

let () =
  Alcotest.run "Test_renderer.click_link"
    [
      ( "click_link",
        [
          Alcotest.test_case "click_link_navigate_appends_msg" `Quick
            test_click_link_navigate_appends_msg;
          Alcotest.test_case "click_link_leave_appends_nothing" `Quick
            test_click_link_leave_appends_nothing;
          Alcotest.test_case "click_link_webview_external_reports_open" `Quick
            test_click_link_webview_external_reports_open;
          Alcotest.test_case "click_link_not_a_link_is_error" `Quick
            test_click_link_not_a_link_is_error;
        ] );
    ]

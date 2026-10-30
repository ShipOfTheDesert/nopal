(** Tests for [Nopal_element.Link] — which clicks a link intercepts, dispatches
    or opens, decided once by [Link.decide].

    The expected action for every combination of host, button, modifiers and
    destination comes from [table], the contract written as data. [decide] is
    only ever the value under test, never the source of an expectation. *)

open Nopal_element

type msg = Followed | Open_failed of Link.open_error

let url_text = "https://nopal-test-7Q2.example/"
let path_text = "/inbox"
let new_tab_text = "/api/invoices/7/photo"

let url =
  match Url.of_string url_text with
  | Ok url -> url
  | Error
      (Url.Missing_scheme _ | Url.Unsupported_scheme _ | Url.Control_character _)
    ->
      Alcotest.fail "fixture URL is refused"

let path =
  match Route_path.of_string path_text with
  | Ok path -> path
  | Error
      ( Route_path.Not_absolute _ | Route_path.Protocol_relative _
      | Route_path.Control_character _ ) ->
      Alcotest.fail "fixture path is refused"

let new_tab_path =
  match Route_path.of_string new_tab_text with
  | Ok path -> path
  | Error
      ( Route_path.Not_absolute _ | Route_path.Protocol_relative _
      | Route_path.Control_character _ ) ->
      Alcotest.fail "fixture new-tab path is refused"

let route = Link.Route { path; on_follow = Followed }
let new_tab : msg Link.destination = Link.New_tab { path = new_tab_path }

let external_ =
  Link.External { url; on_open_failed = (fun error -> Open_failed error) }

let pp_open_error ppf (error : Link.open_error) =
  match error with
  | Link.Not_permitted -> Format.fprintf ppf "Not_permitted"
  | Link.Failed reason -> Format.fprintf ppf "Failed %S" reason

let pp_msg ppf = function
  | Followed -> Format.fprintf ppf "Followed"
  | Open_failed error ->
      Format.fprintf ppf "Open_failed (%a)" pp_open_error error

let pp_action ppf (action : msg Link.action) =
  match action with
  | Link.Navigate msg -> Format.fprintf ppf "Navigate (%a)" pp_msg msg
  | Link.Leave_to_platform -> Format.fprintf ppf "Leave_to_platform"
  | Link.Open_externally { url; on_open_failed = _ } ->
      Format.fprintf ppf "Open_externally %S" (Url.to_string url)

let equal_open_error (a : Link.open_error) (b : Link.open_error) =
  match (a, b) with
  | Link.Not_permitted, Link.Not_permitted -> true
  | Link.Failed r1, Link.Failed r2 -> String.equal r1 r2
  | (Link.Not_permitted | Link.Failed _), _ -> false

let equal_msg a b =
  match (a, b) with
  | Followed, Followed -> true
  | Open_failed e1, Open_failed e2 -> equal_open_error e1 e2
  | (Followed | Open_failed _), _ -> false

let equal_action (a : msg Link.action) (b : msg Link.action) =
  match (a, b) with
  | Link.Navigate m1, Link.Navigate m2 -> equal_msg m1 m2
  | Link.Leave_to_platform, Link.Leave_to_platform -> true
  | Link.Open_externally { url = u1; _ }, Link.Open_externally { url = u2; _ }
    ->
      String.equal (Url.to_string u1) (Url.to_string u2)
  | (Link.Navigate _ | Link.Leave_to_platform | Link.Open_externally _), _ ->
      false

let action = Alcotest.testable pp_action equal_action

type expected = Navigates | Leaves | Opens
type kind = To_route | To_external | To_new_tab

(** The contract, one row per host, button and destination kind:
    [(host, button, kind, unmodified click, modified click)]. A modified click
    is any of the fifteen combinations with at least one of Ctrl, Meta, Shift or
    Alt held. *)
let table : (Link.host * Link.button * kind * expected * expected) list =
  [
    (Link.Browser, Link.Primary, To_route, Navigates, Leaves);
    (Link.Browser, Link.Primary, To_external, Leaves, Leaves);
    (Link.Browser, Link.Middle, To_route, Leaves, Leaves);
    (Link.Browser, Link.Middle, To_external, Leaves, Leaves);
    (Link.Browser, Link.Other, To_route, Leaves, Leaves);
    (Link.Browser, Link.Other, To_external, Leaves, Leaves);
    (Link.Browser, Link.Primary, To_new_tab, Leaves, Leaves);
    (Link.Browser, Link.Middle, To_new_tab, Leaves, Leaves);
    (Link.Browser, Link.Other, To_new_tab, Leaves, Leaves);
    (Link.Webview, Link.Primary, To_route, Navigates, Navigates);
    (Link.Webview, Link.Primary, To_external, Opens, Opens);
    (Link.Webview, Link.Middle, To_route, Navigates, Navigates);
    (Link.Webview, Link.Middle, To_external, Opens, Opens);
    (Link.Webview, Link.Other, To_route, Leaves, Leaves);
    (Link.Webview, Link.Other, To_external, Leaves, Leaves);
    (Link.Webview, Link.Primary, To_new_tab, Leaves, Leaves);
    (Link.Webview, Link.Middle, To_new_tab, Leaves, Leaves);
    (Link.Webview, Link.Other, To_new_tab, Leaves, Leaves);
  ]

let hosts = [ Link.Browser; Link.Webview ]
let buttons = [ Link.Primary; Link.Middle; Link.Other ]
let kinds = [ To_route; To_external; To_new_tab ]

let destination_of = function
  | To_route -> route
  | To_external -> external_
  | To_new_tab -> new_tab

let action_of = function
  | Navigates -> Link.Navigate Followed
  | Leaves -> Link.Leave_to_platform
  | Opens -> Link.Open_externally { url; on_open_failed = (fun _ -> Followed) }

let host_name = function
  | Link.Browser -> "Browser"
  | Link.Webview -> "Webview"

let button_name = function
  | Link.Primary -> "Primary"
  | Link.Middle -> "Middle"
  | Link.Other -> "Other"

let kind_name = function
  | To_route -> "Route"
  | To_external -> "External"
  | To_new_tab -> "New_tab"

(** All sixteen modifier combinations, as clicks of [button]. *)
let clicks button =
  List.init 16 (fun bits ->
      ({
         Link.button;
         ctrl = bits land 1 <> 0;
         meta = bits land 2 <> 0;
         shift = bits land 4 <> 0;
         alt = bits land 8 <> 0;
       }
        : Link.click))

let is_modified ({ button = _; ctrl; meta; shift; alt } : Link.click) =
  ctrl || meta || shift || alt

let row_for host button kind =
  match
    List.filter
      (fun (h, b, k, _, _) -> h = host && b = button && k = kind)
      table
  with
  | [ (_, _, _, unmodified, modified) ] -> (unmodified, modified)
  | rows ->
      Alcotest.failf "table has %d rows for %s %s %s, expected 1"
        (List.length rows) (host_name host) (button_name button)
        (kind_name kind)

let test_decide_exhaustive () =
  (* mutable: counts the combinations the nested iteration visits, to prove the
     loops covered all of them. *)
  let checked = ref 0 in
  List.iter
    (fun host ->
      List.iter
        (fun button ->
          List.iter
            (fun kind ->
              let unmodified, modified = row_for host button kind in
              List.iter
                (fun (click : Link.click) ->
                  let expected =
                    match is_modified click with
                    | false -> unmodified
                    | true -> modified
                  in
                  incr checked;
                  Alcotest.check action
                    (Printf.sprintf "%s %s %s ctrl=%b meta=%b shift=%b alt=%b"
                       (host_name host) (button_name button) (kind_name kind)
                       click.ctrl click.meta click.shift click.alt)
                    (action_of expected)
                    (Link.decide ~host click (destination_of kind)))
                (clicks button))
            kinds)
        buttons)
    hosts;
  Alcotest.(check int) "every combination is checked" 288 !checked

(* The table above holds this too; it is spelled out on its own because it is
   the whole of what a new-tab link is for: the browser opens the tab, so no
   click on one — of any button, under any modifiers — is taken over. *)
let test_decide_leaves_new_tab_to_browser () =
  List.iter
    (fun button ->
      List.iter
        (fun (click : Link.click) ->
          Alcotest.check action
            (Printf.sprintf "%s ctrl=%b meta=%b shift=%b alt=%b"
               (button_name button) click.ctrl click.meta click.shift click.alt)
            Link.Leave_to_platform
            (Link.decide ~host:Link.Browser click new_tab))
        (clicks button))
    buttons

(* A new-tab link carries a [Route_path.t], so the only way to one is
   [Route_path.of_string]; the strings below are the ones a same-origin path
   could plausibly be mistyped as, each of which names something other than a
   path on this origin. *)
let test_new_tab_path_refused_unless_single_slash () =
  let refused =
    [
      "api/invoices/7/photo";
      "./api/invoices/7/photo";
      "";
      "//cdn.example/photo";
      "/\\cdn.example/photo";
      "https://cdn.example/photo";
      " /api/invoices/7/photo";
    ]
  in
  List.iter
    (fun input ->
      Alcotest.(check bool)
        (Printf.sprintf "%S is refused" input)
        true
        (Result.is_error (Route_path.of_string input)))
    refused;
  (* The affirmative arm: the check refuses those, not everything. *)
  match Route_path.of_string new_tab_text with
  | Ok path ->
      Alcotest.(check string)
        "a single-slash path is accepted unchanged" new_tab_text
        (Route_path.to_string path)
  | Error
      ( Route_path.Not_absolute _ | Route_path.Protocol_relative _
      | Route_path.Control_character _ ) ->
      Alcotest.fail "a single-slash path is refused"

let test_enter_shape_is_plain_primary () =
  let enter =
    {
      Link.button = Link.Primary;
      ctrl = false;
      meta = false;
      shift = false;
      alt = false;
    }
  in
  Alcotest.check action "Enter on a browser route link navigates in-app"
    (Link.Navigate Followed)
    (Link.decide ~host:Link.Browser enter route)

let describe = function
  | Followed -> "followed"
  | Open_failed Link.Not_permitted -> "open_failed:not_permitted"
  | Open_failed (Link.Failed reason) -> "open_failed:" ^ reason

let test_map_destination_maps_every_arm () =
  (match Link.map_destination describe route with
  | Link.Route { path; on_follow } ->
      Alcotest.(check string)
        "path is unchanged" path_text
        (Route_path.to_string path);
      Alcotest.(check string) "on_follow is mapped" "followed" on_follow
  | Link.External _
  | Link.New_tab _ ->
      Alcotest.fail "a mapped Route changed kind");
  (match Link.map_destination describe external_ with
  | Link.External { url; on_open_failed } ->
      Alcotest.(check string) "url is unchanged" url_text (Url.to_string url);
      Alcotest.(check string)
        "Not_permitted is mapped" "open_failed:not_permitted"
        (on_open_failed Link.Not_permitted);
      Alcotest.(check string)
        "Failed is mapped with its reason" "open_failed:boom"
        (on_open_failed (Link.Failed "boom"))
  | Link.Route _
  | Link.New_tab _ ->
      Alcotest.fail "a mapped External changed kind");
  match Link.map_destination describe new_tab with
  | Link.New_tab { path } ->
      Alcotest.(check string)
        "a New_tab path is unchanged" new_tab_text
        (Route_path.to_string path)
  | Link.Route _
  | Link.External _ ->
      Alcotest.fail "a mapped New_tab changed kind"

let test_button_of_index () =
  let check label expected n =
    Alcotest.(check string)
      label (button_name expected)
      (button_name (Link.button_of_index n))
  in
  check "0 is Primary" Link.Primary 0;
  check "1 is Middle" Link.Middle 1;
  check "2 is Other" Link.Other 2;
  check "3 is Other" Link.Other 3;
  check "-1 is Other" Link.Other (-1)

let () =
  Alcotest.run "Link"
    [
      ( "link",
        [
          Alcotest.test_case "decide_exhaustive" `Quick test_decide_exhaustive;
          Alcotest.test_case
            "decide leaves every click on a new-tab link to the browser" `Quick
            test_decide_leaves_new_tab_to_browser;
          Alcotest.test_case
            "a new-tab path is refused unless it starts with a single /" `Quick
            test_new_tab_path_refused_unless_single_slash;
          Alcotest.test_case "enter_shape_is_plain_primary" `Quick
            test_enter_shape_is_plain_primary;
          Alcotest.test_case "button_of_index" `Quick test_button_of_index;
          Alcotest.test_case "map_destination_maps_every_arm" `Quick
            test_map_destination_maps_every_arm;
        ] );
    ]

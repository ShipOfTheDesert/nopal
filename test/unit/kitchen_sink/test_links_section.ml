(* The links kitchen-sink section, read structurally through the whole kitchen
   sink so the section's registration is under test too.

   What this file can see is the rendered anchors, the message a click asks for,
   and the navigation [update] answers it with, run against a platform that
   records what is pushed. What it cannot see is a browser following, or
   declining to follow, an anchor — that is the browser spec's job. *)

open Nopal_test.Test_renderer
module Link = Nopal_element.Link
module Text = Nopal_style.Text
module Sub = Kitchen_sink_app.Sub_links

(* mutable: the recording platform stub appends each path the router pushes;
   a test reads it back after the click. *)
let pushed = ref []

module Recording_platform : Nopal_platform.Platform.S = struct
  let current_path () = "/kitchen_sink/"
  let push_state path = pushed := !pushed @ [ path ]
  let replace_state (_ : string) = ()
  let back () = ()
  let on_popstate (_ : string -> unit) () = ()

  module Store = Nopal_storage.In_memory ()

  let storage = (module Store : Nopal_storage.S)
end

module K = Kitchen_sink_app.Make (Recording_platform)

let vp = Nopal_element.Viewport.desktop
let section = By_attr ("data-testid", "links-section")
let route_link = By_attr ("data-testid", "links-route-link")
let external_link = By_attr ("data-testid", "links-external-link")
let new_tab_link = By_attr ("data-testid", "links-new-tab-link")
let current_route = By_attr ("data-testid", "links-current-route")
let open_status = By_attr ("data-testid", "links-open-status")

let plain_primary =
  {
    Link.button = Link.Primary;
    ctrl = false;
    meta = false;
    shift = false;
    alt = false;
  }

let model0 () = fst (K.init ())

let node_in label selector node =
  match find selector node with
  | Some found -> found
  | None -> Alcotest.fail (label ^ ": no such element")

let section_of model =
  node_in "the links section" section (tree (render (K.view vp model)))

let tag_of label node =
  match node with
  | Element { tag; _ } -> tag
  | Empty
  | Text _ ->
      Alcotest.fail (label ^ " is not an element")

let route_readout model =
  attr "data-route" (node_in "the route line" current_route (section_of model))

let status_readout model =
  let node = node_in "the opener line" open_status (section_of model) in
  (attr "data-status" node, text_content node)

let test_links_section_has_route_and_external () =
  let s = section_of (model0 ()) in
  let route = node_in "the route link" route_link s in
  let ext = node_in "the external link" external_link s in
  Alcotest.(check (list string))
    "both links are anchors" [ "a"; "a" ]
    [ tag_of "the route link" route; tag_of "the external link" ext ];
  Alcotest.(check (option string))
    "the route link's address is its route's path"
    (Some "/kitchen_sink/?links=target") (attr "href" route);
  Alcotest.(check (option string))
    "the external link's address is its URL" (Some "https://ocaml.org/")
    (attr "href" ext);
  Alcotest.(check (option string))
    "the external link cannot reach back to this page"
    (Some "noopener noreferrer") (attr "rel" ext);
  Alcotest.(check (option string))
    "the route link carries no rel" None (attr "rel" route)

(* The click alone pushes nothing — the push is [update]'s answer to the
   message — and the same fixture then pushes exactly the link's address. *)
let test_links_route_click_follows_via_router () =
  pushed := [];
  let model = model0 () in
  Alcotest.(check (option string))
    "the section starts at its start route" (Some "start") (route_readout model);
  let rendered = render (K.view vp model) in
  (match click_link ~host:Link.Browser plain_primary route_link rendered with
  | Ok (Link.Navigate _) -> ()
  | Ok Link.Leave_to_platform ->
      Alcotest.fail "a plain click on the route link was left to the browser"
  | Ok (Link.Open_externally _) ->
      Alcotest.fail "a plain click on the route link opened externally"
  | Error (Not_found _) -> Alcotest.fail "the route link is missing"
  | Error (No_handler { tag; event }) ->
      Alcotest.failf "the route link is a %s with no %s" tag event);
  let followed =
    match messages rendered with
    | [ K.Links_msg msg ] -> msg
    | msgs ->
        Alcotest.failf "the click dispatched %d messages, expected one link msg"
          (List.length msgs)
  in
  Alcotest.(check string)
    "the click dispatches the follow message" "Links:Followed:Target;"
    (Sub.serialize_msg followed);
  Alcotest.(check (list string)) "the click itself pushes nothing" [] !pushed;
  let model, cmd = K.update model (K.Links_msg followed) in
  Nopal_mvu.Cmd.execute (fun (_ : K.msg) -> ()) cmd;
  Alcotest.(check (list string))
    "update pushes the link's address"
    [ "/kitchen_sink/?links=target" ]
    !pushed;
  Alcotest.(check (option string))
    "the model holds the followed route" (Some "target") (route_readout model)

(* The new-tab link is the browser's to open: its anchor says so, and a plain
   primary click — the one a route link takes over — asks for nothing. *)
let test_links_new_tab_link_left_to_browser () =
  let model = model0 () in
  let rendered = render (K.view vp model) in
  let link =
    node_in "the new-tab link" new_tab_link
      (node_in "the links section" section (tree rendered))
  in
  Alcotest.(check (list (option string)))
    "the new-tab link's address, target and rel"
    [
      Some "/kitchen_sink/?links=new-tab";
      Some "_blank";
      Some "noopener noreferrer";
    ]
    [ attr "href" link; attr "target" link; attr "rel" link ];
  (match click_link ~host:Link.Browser plain_primary new_tab_link rendered with
  | Ok Link.Leave_to_platform -> ()
  | Ok (Link.Navigate _) ->
      Alcotest.fail "a plain click on the new-tab link was taken over"
  | Ok (Link.Open_externally _) ->
      Alcotest.fail "a plain click on the new-tab link opened externally"
  | Error (Not_found _) -> Alcotest.fail "the new-tab link is missing"
  | Error (No_handler { tag; event }) ->
      Alcotest.failf "the new-tab link is a %s with no %s" tag event);
  Alcotest.(check int)
    "the click dispatches nothing" 0
    (List.length (messages rendered))

(* Each failure is fed back through the section's own message, as the opener's
   callback would deliver it. *)
let test_open_failure_shows_status () =
  let after error =
    status_readout
      (fst (K.update (model0 ()) (K.Links_msg (Sub.Open_failed error))))
  in
  let status = Alcotest.(pair (option string) string) in
  Alcotest.check status "nothing is reported before a failure"
    (Some "idle", "No external link has failed to open")
    (status_readout (model0 ()));
  Alcotest.check status "a refusal says so"
    (Some "not-permitted", "Not opened: the platform refused to open the link")
    (after Link.Not_permitted);
  Alcotest.check status "any other failure shows the platform's reason"
    (Some "failed", "Not opened: no browser installed")
    (after (Link.Failed "no browser installed"))

let hover_text label node =
  match interaction node with
  | Some { Nopal_style.Interaction.hover = Some hover; _ } ->
      hover.Nopal_style.Style.text
  | Some { Nopal_style.Interaction.hover = None; _ }
  | None ->
      Alcotest.fail (label ^ " has no hover style")

(* Both links underline on hover, so the offset is the one thing that tells
   them apart; reading the underline on the plain link too is what keeps its
   absent offset from passing for a link that lost its hover style. *)
let test_offset_link_and_plain_link () =
  let s = section_of (model0 ()) in
  let offset =
    hover_text "the route link" (node_in "the route link" route_link s)
  in
  let plain =
    hover_text "the external link" (node_in "the external link" external_link s)
  in
  let decoration =
    Alcotest.testable
      (fun ppf (d : Text.text_decoration) ->
        Format.pp_print_string ppf
          (match d with
          | Underline -> "Underline"
          | Line_through -> "Line_through"
          | Overline -> "Overline"
          | No_decoration -> "No_decoration"))
      Text.equal_text_decoration
  in
  let px = Alcotest.testable Format.pp_print_float Float.equal in
  Alcotest.(check (option decoration))
    "the route link underlines on hover" (Some Text.Underline)
    offset.Text.text_decoration;
  Alcotest.(check (option px))
    "the route link's underline sits 3px from the text" (Some 3.)
    offset.Text.underline_offset;
  Alcotest.(check (option decoration))
    "the external link underlines on hover" (Some Text.Underline)
    plain.Text.text_decoration;
  Alcotest.(check (option px))
    "the external link's underline carries no offset" None
    plain.Text.underline_offset

let () =
  Alcotest.run "kitchen_sink_links_section"
    [
      ( "links",
        [
          Alcotest.test_case "links_section_has_route_and_external" `Quick
            test_links_section_has_route_and_external;
          Alcotest.test_case "links_route_click_follows_via_router" `Quick
            test_links_route_click_follows_via_router;
          Alcotest.test_case "links_new_tab_link_left_to_browser" `Quick
            test_links_new_tab_link_left_to_browser;
          Alcotest.test_case "open_failure_shows_status" `Quick
            test_open_failure_shows_status;
          Alcotest.test_case "offset_link_and_plain_link" `Quick
            test_offset_link_and_plain_link;
        ] );
    ]

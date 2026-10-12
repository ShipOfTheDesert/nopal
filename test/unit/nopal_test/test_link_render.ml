(* Structural rendering of [Element.link]: the anchor node, the [href] and [rel]
   it derives from its destination, and the precedence of those two over the
   view's own [attrs]. *)

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

let route_link ?(attrs = []) () =
  Element.link ~attrs
    (Link.Route { path = route_path; on_follow = Followed })
    (Element.text "Inbox")

let external_link ?(attrs = []) () =
  Element.link ~attrs
    (Link.External { url; on_open_failed = (fun _ -> Open_failed) })
    (Element.text "Docs")

let tag_of node =
  match node with
  | TR.Element { tag; _ } -> tag
  | TR.Text _ -> "text"
  | TR.Empty -> "empty"

let check_opt = Alcotest.(check (option string))

let test_link_renders_a_with_href_and_rel () =
  let route = TR.tree (TR.render (route_link ())) in
  Alcotest.(check string) "a Route link is an anchor" "a" (tag_of route);
  check_opt "a Route link's href is its path" (Some path_text)
    (TR.attr "href" route);
  check_opt "a Route link carries no rel" None (TR.attr "rel" route);
  Alcotest.(check string)
    "a Route link renders its child" "Inbox" (TR.text_content route);
  let external_ = TR.tree (TR.render (external_link ())) in
  Alcotest.(check string) "an External link is an anchor" "a" (tag_of external_);
  check_opt "an External link's href is its URL" (Some url_text)
    (TR.attr "href" external_);
  check_opt "an External link keeps the opened page from its opener"
    (Some "noopener noreferrer") (TR.attr "rel" external_);
  Alcotest.(check string)
    "an External link renders its child" "Docs"
    (TR.text_content external_)

let test_link_href_and_rel_outrank_attrs () =
  let attrs = [ ("href", "/x"); ("rel", "opener"); ("data-testid", "link") ] in
  let external_ = TR.tree (TR.render (external_link ~attrs ())) in
  check_opt "an External link's URL outranks an href in attrs" (Some url_text)
    (TR.attr "href" external_);
  check_opt "an External link's rel outranks a rel in attrs"
    (Some "noopener noreferrer") (TR.attr "rel" external_);
  check_opt "a key the link does not derive keeps the caller's value"
    (Some "link")
    (TR.attr "data-testid" external_);
  let route = TR.tree (TR.render (route_link ~attrs ())) in
  check_opt "a Route link's path outranks an href in attrs" (Some path_text)
    (TR.attr "href" route);
  (* A Route link derives no [rel], and a derivation that is absent uncovers
     the caller's pair rather than erasing it. *)
  check_opt "a Route link leaves a caller's rel standing" (Some "opener")
    (TR.attr "rel" route)

let () =
  Alcotest.run "nopal_test link render"
    [
      ( "link",
        [
          Alcotest.test_case "link_renders_a_with_href_and_rel" `Quick
            test_link_renders_a_with_href_and_rel;
          Alcotest.test_case "link_href_and_rel_outrank_attrs" `Quick
            test_link_href_and_rel_outrank_attrs;
        ] );
    ]

(* The web renderer's anchor for [Element.link], read beside the structural
   renderer's on the same element: the tag, the [href] and [rel] derived from
   the destination, and the child's text must be the same in both. *)

open Nopal_element
module TR = Nopal_test.Test_renderer

type msg = Followed | Open_failed of Link.open_error

let dispatch (_ : msg) = ()
let path_text = "/inbox"
let url_text = "https://nopal-test-7Q2.example/"

let route_path text =
  match Route_path.of_string text with
  | Ok path -> path
  | Error
      ( Route_path.Not_absolute _ | Route_path.Protocol_relative _
      | Route_path.Control_character _ ) ->
      Alcotest.fail ("fixture path is refused: " ^ text)

let url =
  match Url.of_string url_text with
  | Ok url -> url
  | Error
      (Url.Missing_scheme _ | Url.Unsupported_scheme _ | Url.Control_character _)
    ->
      Alcotest.fail "fixture URL is refused"

let route_link ?(attrs = []) ?(path = path_text) () =
  Element.link ~attrs
    (Link.Route { path = route_path path; on_follow = Followed })
    (Element.text "Inbox")

let external_link ?(attrs = []) () =
  Element.link ~attrs
    (Link.External { url; on_open_failed = (fun error -> Open_failed error) })
    (Element.text "Docs")

let fresh_parent () = Brr.El.v (Jstr.v "div") []

let dom_attr node name =
  let v = Jv.call node "getAttribute" [| Jv.of_string name |] in
  if Jv.is_null v then None else Some (Jv.to_string v)

(* What one renderer shows of an anchor: its tag, [href], [rel] and text. *)
type anchor = {
  tag : string;
  href : string option;
  rel : string option;
  text : string;
}

let anchor_t =
  Alcotest.testable
    (fun ppf { tag; href; rel; text } ->
      let opt = Option.value ~default:"<none>" in
      Format.fprintf ppf "{ tag = %S; href = %s; rel = %s; text = %S }" tag
        (opt href) (opt rel) text)
    (fun a b ->
      String.equal a.tag b.tag
      && Option.equal String.equal a.href b.href
      && Option.equal String.equal a.rel b.rel
      && String.equal a.text b.text)

let dom_anchor node =
  {
    tag = String.lowercase_ascii (Jv.to_string (Jv.get node "tagName"));
    href = dom_attr node "href";
    rel = dom_attr node "rel";
    text = Jv.to_string (Jv.get node "textContent");
  }

let web_anchor element =
  let handle =
    Nopal_web.Renderer.create ~dispatch ~parent:(fresh_parent ()) element
  in
  dom_anchor (Nopal_web.Renderer.dom_node handle)

let structural_anchor element =
  let node = TR.tree (TR.render element) in
  {
    tag =
      (match node with
      | TR.Element { tag; _ } -> tag
      | TR.Text _ -> "text"
      | TR.Empty -> "empty");
    href = TR.attr "href" node;
    rel = TR.attr "rel" node;
    text = TR.text_content node;
  }

let route_anchor =
  { tag = "a"; href = Some path_text; rel = None; text = "Inbox" }

let external_anchor =
  {
    tag = "a";
    href = Some url_text;
    rel = Some "noopener noreferrer";
    text = "Docs";
  }

let check_both label expected element =
  Alcotest.check anchor_t ("structural: " ^ label) expected
    (structural_anchor element);
  Alcotest.check anchor_t ("web: " ^ label) expected (web_anchor element)

let test_link_dom_anchor_matches_structural () =
  check_both "a Route link" route_anchor (route_link ());
  check_both "an External link" external_anchor (external_link ())

(* The web renderer applies the declared list before it writes the derived
   keys, so the derivation is what stands; a Route link derives no [rel] and
   leaves the caller's standing, as the structural renderer does. *)
let test_link_dom_href_and_rel_outrank_attrs () =
  let attrs = [ ("href", "/x"); ("rel", "opener") ] in
  check_both "an External link over colliding attrs" external_anchor
    (external_link ~attrs ());
  check_both "a Route link over colliding attrs"
    { route_anchor with rel = Some "opener" }
    (route_link ~attrs ())

(* One anchor node carried across frames: each frame is a freshly built link,
   so a reconcile that skipped work by identity rather than by value would leave
   the previous frame's keys on the node. *)
let test_link_dom_reconcile_rewrites_href_and_rel () =
  let handle =
    Nopal_web.Renderer.create ~dispatch ~parent:(fresh_parent ())
      (route_link ())
  in
  let node () = Nopal_web.Renderer.dom_node handle in
  let first = node () in
  let frame label expected element =
    Nopal_web.Renderer.update ~dispatch handle element;
    Alcotest.check anchor_t label expected (dom_anchor (node ()))
  in
  let writes () = Jv.to_int (Jv.get first "setAttributeCalls") in
  let before = writes () in
  frame "an unchanged Route link keeps its keys" route_anchor (route_link ());
  Alcotest.(check int) "an unchanged link is not rewritten" before (writes ());
  frame "a new path rewrites href"
    { route_anchor with href = Some "/outbox" }
    (route_link ~path:"/outbox" ());
  frame "becoming External writes the URL and rel" external_anchor
    (external_link ());
  frame "becoming a Route link again removes the derived rel" route_anchor
    (route_link ());
  Alcotest.(check bool)
    "every frame patched the same anchor node" true
    (Jv.equal first (node ()))

(* Clicks. Each case renders one link, dispatches a cancelable mouse event on
   its anchor as a user's click would arrive, and reads back whether the
   platform default was prevented and every message dispatched, in order. *)

let show_open_error = function
  | Link.Not_permitted -> "Not_permitted"
  | Link.Failed reason -> Printf.sprintf "Failed %S" reason

let show_msg = function
  | Followed -> "Followed"
  | Open_failed error -> "Open_failed (" ^ show_open_error error ^ ")"

let msg_t =
  Alcotest.testable (fun ppf m -> Format.pp_print_string ppf (show_msg m)) ( = )

(* A rendered link, the messages its renderer dispatched, and the opener's
   calls. The opener answers nothing while it is called: it parks each
   resolver, so a case settles it after the click's listener has returned, as a
   host's opener does. *)
type clicked = {
  handle : msg Nopal_web.Renderer.t;
  record : msg -> unit;
  anchor : Jv.t;
  dispatched : msg list ref;
  opened : string list ref;
  resolvers : ((unit, Link.open_error) result -> unit) list ref;
}

let render_clicked ~webview element =
  (* mutable: the renderer reports each dispatch only through this callback. *)
  let dispatched = ref [] in
  (* mutable: the opener reports each call only through this callback. *)
  let opened = ref [] in
  (* mutable: each parked resolver waits here until the case settles it. *)
  let resolvers = ref [] in
  let open_external url resolve =
    opened := !opened @ [ Url.to_string url ];
    resolvers := !resolvers @ [ resolve ]
  in
  let link_host =
    match webview with
    | true -> Nopal_web.Renderer.Webview { open_external }
    | false -> Nopal_web.Renderer.Browser
  in
  let record m = dispatched := !dispatched @ [ m ] in
  let handle =
    Nopal_web.Renderer.create ~link_host ~dispatch:record
      ~parent:(fresh_parent ()) element
  in
  {
    handle;
    record;
    anchor = Nopal_web.Renderer.dom_node handle;
    dispatched;
    opened;
    resolvers;
  }

(* Dispatch a [kind] mouse event on the anchor and answer whether its default
   was prevented. *)
let mouse ?(button = 0) ?(ctrl = false) kind anchor =
  let ev =
    Jv.new'
      (Jv.get Jv.global "MouseEvent")
      [|
        Jv.of_string kind;
        Jv.obj
          [|
            ("cancelable", Jv.true');
            ("bubbles", Jv.true');
            ("button", Jv.of_int button);
            ("ctrlKey", Jv.of_bool ctrl);
          |];
      |]
  in
  ignore (Jv.call anchor "dispatchEvent" [| ev |]);
  Jv.to_bool (Jv.get ev "defaultPrevented")

let check_prevented label expected actual =
  Alcotest.(check bool) ("defaultPrevented: " ^ label) expected actual

let check_dispatched label expected clicked =
  Alcotest.(check (list msg_t))
    ("dispatched: " ^ label) expected !(clicked.dispatched)

let test_link_plain_click_route_prevents_and_dispatches () =
  let c = render_clicked ~webview:false (route_link ()) in
  check_prevented "a plain primary click on a Route link" true
    (mouse "click" c.anchor);
  check_dispatched "a plain primary click on a Route link" [ Followed ] c

(* The plain click on the same anchor afterwards is the affirmative arm: the
   listener is live and dispatches on this fixture, so the empty list before it
   is the modifier's doing. *)
let test_link_ctrl_click_route_left_to_browser () =
  let c = render_clicked ~webview:false (route_link ()) in
  check_prevented "a Ctrl-click on a Route link" false
    (mouse ~ctrl:true "click" c.anchor);
  check_dispatched "a Ctrl-click on a Route link" [] c;
  check_prevented "then a plain click" true (mouse "click" c.anchor);
  check_dispatched "then a plain click" [ Followed ] c

let test_link_middle_click_handled_on_auxclick () =
  let c = render_clicked ~webview:true (route_link ()) in
  check_prevented "a middle auxclick on a webview Route link" true
    (mouse ~button:1 "auxclick" c.anchor);
  check_dispatched "a middle auxclick on a webview Route link" [ Followed ] c

(* The second click, whose opener answers [Error], is the affirmative arm: the
   same fixture dispatches when the opener fails, so the empty list after [Ok]
   is the success's doing. *)
let test_link_webview_external_calls_opener_once () =
  let c = render_clicked ~webview:true (external_link ()) in
  check_prevented "a primary click on a webview External link" true
    (mouse "click" c.anchor);
  Alcotest.(check (list string))
    "the opener is called once, with the URL" [ url_text ] !(c.opened);
  check_dispatched "nothing before the opener answers" [] c;
  List.iter (fun resolve -> resolve (Ok ())) !(c.resolvers);
  check_dispatched "nothing when the opener succeeds" [] c;
  c.resolvers := [];
  check_prevented "a second primary click on a webview External link" true
    (mouse "click" c.anchor);
  List.iter (fun resolve -> resolve (Error Link.Not_permitted)) !(c.resolvers);
  check_dispatched "the failure of a second click"
    [ Open_failed Link.Not_permitted ]
    c

let test_link_webview_external_failure_dispatches_on_open_failed () =
  let c = render_clicked ~webview:true (external_link ()) in
  check_prevented "a primary click on a webview External link" true
    (mouse "click" c.anchor);
  check_dispatched "nothing before the opener answers" [] c;
  let resolve =
    match !(c.resolvers) with
    | [ resolve ] -> resolve
    | resolvers ->
        Alcotest.failf "expected one parked resolver, got %d"
          (List.length resolvers)
  in
  resolve (Error Link.Not_permitted);
  check_dispatched "the opener's failure" [ Open_failed Link.Not_permitted ] c;
  resolve (Error (Link.Failed "again"));
  resolve (Ok ());
  check_dispatched "a second and third answer are absorbed"
    [ Open_failed Link.Not_permitted ]
    c

(* A patched anchor answers a click for the destination it now carries, and
   only that one: a listener left over from the previous frame would follow the
   Route link it was wired for. *)
let test_link_click_after_reconcile_follows_new_destination () =
  let c = render_clicked ~webview:true (route_link ()) in
  check_prevented "a click on the Route link" true (mouse "click" c.anchor);
  check_dispatched "a click on the Route link" [ Followed ] c;
  Nopal_web.Renderer.update ~dispatch:c.record c.handle (external_link ());
  Alcotest.(check bool)
    "the update patched the same anchor" true
    (Jv.equal c.anchor (Nopal_web.Renderer.dom_node c.handle));
  check_prevented "a click on the anchor, now External" true
    (mouse "click" c.anchor);
  Alcotest.(check (list string))
    "the opener is called once, with the URL" [ url_text ] !(c.opened);
  check_dispatched "the Route link is not followed again" [ Followed ] c

(* A browser leaves an External link to itself, and a button other than the
   primary and middle ones is left to the platform on either host: nothing is
   prevented and nothing is dispatched or opened. *)
let test_link_left_to_platform_clicks () =
  let c = render_clicked ~webview:false (external_link ()) in
  check_prevented "a plain click on a browser External link" false
    (mouse "click" c.anchor);
  check_dispatched "a plain click on a browser External link" [] c;
  Alcotest.(check (list string)) "nothing is opened" [] !(c.opened);
  List.iter
    (fun webview ->
      let host = if webview then "webview" else "browser" in
      List.iter
        (fun button ->
          let c = render_clicked ~webview (route_link ()) in
          let label = Printf.sprintf "auxclick button %d on a %s" button host in
          check_prevented label false (mouse ~button "auxclick" c.anchor);
          check_dispatched label [] c;
          Alcotest.(check (list string))
            (label ^ " opens nothing") [] !(c.opened))
        [ 2; 3 ])
    [ false; true ]

(* An opener that raises before answering is a failure the link reports, and
   the exception's text, which here carries the URL, does not reach the
   reason. *)
let test_link_webview_opener_raise_fails_without_url () =
  (* mutable: the renderer reports each dispatch only through this callback. *)
  let dispatched = ref [] in
  let open_external url _resolve =
    failwith ("cannot open " ^ Url.to_string url)
  in
  let handle =
    Nopal_web.Renderer.create
      ~link_host:(Nopal_web.Renderer.Webview { open_external })
      ~dispatch:(fun m -> dispatched := !dispatched @ [ m ])
      ~parent:(fresh_parent ()) (external_link ())
  in
  check_prevented "a click whose opener raises" true
    (mouse "click" (Nopal_web.Renderer.dom_node handle));
  match !dispatched with
  | [ Open_failed (Link.Failed reason) ] ->
      Alcotest.(check bool)
        (Printf.sprintf "the reason %S does not carry the URL" reason)
        false
        (Test_util.string_contains reason ~sub:"nopal-test-7Q2")
  | other ->
      Alcotest.failf "expected one Open_failed (Failed _), got [%s]"
        (String.concat "; " (List.map show_msg other))

let () =
  Alcotest.run "nopal_web link render"
    [
      ( "link",
        [
          Alcotest.test_case "link_dom_anchor_matches_structural" `Quick
            test_link_dom_anchor_matches_structural;
          Alcotest.test_case "link_dom_href_and_rel_outrank_attrs" `Quick
            test_link_dom_href_and_rel_outrank_attrs;
          Alcotest.test_case "link_dom_reconcile_rewrites_href_and_rel" `Quick
            test_link_dom_reconcile_rewrites_href_and_rel;
        ] );
      ( "click",
        [
          Alcotest.test_case "link_plain_click_route_prevents_and_dispatches"
            `Quick test_link_plain_click_route_prevents_and_dispatches;
          Alcotest.test_case "link_ctrl_click_route_left_to_browser" `Quick
            test_link_ctrl_click_route_left_to_browser;
          Alcotest.test_case "link_middle_click_handled_on_auxclick" `Quick
            test_link_middle_click_handled_on_auxclick;
          Alcotest.test_case "link_webview_external_calls_opener_once" `Quick
            test_link_webview_external_calls_opener_once;
          Alcotest.test_case
            "link_webview_external_failure_dispatches_on_open_failed" `Quick
            test_link_webview_external_failure_dispatches_on_open_failed;
          Alcotest.test_case
            "link_click_after_reconcile_follows_new_destination" `Quick
            test_link_click_after_reconcile_follows_new_destination;
          Alcotest.test_case "link_left_to_platform_clicks" `Quick
            test_link_left_to_platform_clicks;
          Alcotest.test_case "link_webview_opener_raise_fails_without_url"
            `Quick test_link_webview_opener_raise_fails_without_url;
        ] );
    ]

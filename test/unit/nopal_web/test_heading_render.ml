(* The web renderer's node for [Element.heading]: the level's own tag, its
   child inside it, and what a reconcile does to that node when the level or
   the text changes. *)

module E = Nopal_element.Element

let dispatch (_ : unit) = ()
let fresh_parent () = Brr.El.v (Jstr.v "div") []
let tag_of node = String.lowercase_ascii (Jv.to_string (Jv.get node "nodeName"))

let mount element =
  Nopal_web.Renderer.create ~dispatch ~parent:(fresh_parent ()) element

let levels =
  [
    (E.H1, "h1");
    (E.H2, "h2");
    (E.H3, "h3");
    (E.H4, "h4");
    (E.H5, "h5");
    (E.H6, "h6");
  ]

let heading_renders_level_tag () =
  List.iter
    (fun (level, tag) ->
      let node =
        Nopal_web.Renderer.dom_node (mount (E.heading level (E.text "Title")))
      in
      Alcotest.(check string) ("tag of " ^ tag) tag (tag_of node);
      let child = Jv.get node "firstChild" in
      Alcotest.(check string) ("child of " ^ tag) "span" (tag_of child);
      Alcotest.(check string)
        ("text of " ^ tag) "Title"
        (Jv.to_string (Jv.get child "textContent")))
    levels

(* Each frame is a freshly built heading, as a view rebuilds it. *)
let heading_level_change_replaces_node () =
  let handle = mount (E.heading E.H1 (E.text "Title")) in
  let before = Nopal_web.Renderer.dom_node handle in
  Nopal_web.Renderer.update ~dispatch handle (E.heading E.H2 (E.text "Title"));
  let after = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check string) "the node is an h2" "h2" (tag_of after);
  Alcotest.(check bool) "a new node" false (before == after)

let heading_text_change_patches_in_place () =
  let handle = mount (E.heading E.H2 (E.text "a")) in
  let before = Nopal_web.Renderer.dom_node handle in
  Nopal_web.Renderer.update ~dispatch handle (E.heading E.H2 (E.text "b"));
  let after = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check bool) "the same h2 node" true (before == after);
  Alcotest.(check string)
    "the text is patched" "b"
    (Jv.to_string (Jv.get after "textContent"))

let heading_style_and_interaction_reconcile () =
  let styled =
    Nopal_style.Style.default
    |> Nopal_style.Style.with_paint (fun p ->
        { p with background = Some (Nopal_style.Style.hex "#123456") })
  in
  let hover = { Nopal_style.Interaction.default with hover = Some styled } in
  let handle = mount (E.heading E.H2 (E.text "t")) in
  let before = Nopal_web.Renderer.dom_node handle in
  let classes node =
    Jv.to_string (Jv.call (Jv.get node "classList") "toString" [||])
  in
  let inline node =
    Jv.Jstr.get (Jv.get node "style") "background-color" |> Jstr.to_string
  in
  let style0 = inline before in
  Nopal_web.Renderer.update ~dispatch handle
    (E.heading ~style:styled E.H2 (E.text "t"));
  let mid = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check bool) "same node after style" true (before == mid);
  let style1 = inline mid in
  let class1 = classes mid in
  Alcotest.(check bool)
    "style changed" true
    ((not (String.equal style0 style1)) || not (String.equal "" class1));
  Nopal_web.Renderer.update ~dispatch handle
    (E.heading ~style:styled ~interaction:hover E.H2 (E.text "t"));
  let after = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check bool) "same node after interaction" true (before == after);
  Alcotest.(check bool)
    "class changed by interaction" true
    (not (String.equal class1 (classes after)))

let () =
  Alcotest.run "heading render"
    [
      ( "heading",
        [
          Alcotest.test_case "heading_renders_level_tag" `Quick
            heading_renders_level_tag;
          Alcotest.test_case "heading_level_change_replaces_node" `Quick
            heading_level_change_replaces_node;
          Alcotest.test_case "heading_text_change_patches_in_place" `Quick
            heading_text_change_patches_in_place;
          Alcotest.test_case "heading_style_and_interaction_reconcile" `Quick
            heading_style_and_interaction_reconcile;
        ] );
    ]

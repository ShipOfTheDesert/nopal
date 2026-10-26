(* The kitchen sink's headings section, read structurally: every level from the
   section's own H2 down to H6 in order, an unstyled heading next to plain text,
   and a heading whose base style sets a size while it also carries interaction
   states.

   What this file cannot see is what a browser makes of them — whether the
   unstyled heading really looks like its neighbour, or whether the styled one's
   size survives the heading reset. Those are computed styles, and the browser
   spec reads them from the data-testids pinned here. *)

open Nopal_test.Test_renderer
module Element = Nopal_element.Element
module Style = Nopal_style.Style
module Interaction = Nopal_style.Interaction

module Test_platform : Nopal_platform.Platform.S = struct
  let current_path () = "/"
  let push_state (_ : string) = ()
  let replace_state (_ : string) = ()
  let back () = ()
  let on_popstate (_ : string -> unit) () = ()

  module Store = Nopal_storage.In_memory ()

  let storage = (module Store : Nopal_storage.S)
end

module K = Kitchen_sink_app.Make (Test_platform)

let vp = Nopal_element.Viewport.desktop

let section () =
  let page = tree (render (K.view vp (fst (K.init ())))) in
  match find (By_attr ("data-testid", "headings-section")) page with
  | Some node -> node
  | None -> Alcotest.fail "the page renders no headings section"

let node_in label testid parent =
  match find (By_attr ("data-testid", testid)) parent with
  | Some node -> node
  | None -> Alcotest.failf "%s: the section renders no %S" label testid

let heading_in level text parent =
  match find_heading level text parent with
  | Some node -> node
  | None ->
      Alcotest.failf "no H%d reading %S in the section"
        (Element.heading_level_to_int level)
        text

(* Every node of the subtree in document order, so a heading's position can be
   read off the node [find_heading] returned rather than off its tag. *)
let document_order root =
  let rec walk acc node =
    match node with
    | Empty
    | Text _ ->
        node :: acc
    | Element { children; _ } -> List.fold_left walk (node :: acc) children
  in
  List.rev (walk [] root)

let position_of target nodes =
  let rec go index nodes =
    match nodes with
    | [] -> None
    | node :: rest -> (
        match node == target with
        | true -> Some index
        | false -> go (index + 1) rest)
  in
  go 0 nodes

let test_chain_in_order () =
  let root = section () in
  let order = document_order root in
  let chain =
    [
      (Element.H2, "Headings");
      (Element.H3, "Heading level three");
      (Element.H4, "Heading level four");
      (Element.H5, "Heading level five");
      (Element.H6, "Heading level six");
    ]
  in
  let positions =
    List.map
      (fun (level, text) ->
        match position_of (heading_in level text root) order with
        | Some index -> index
        | None -> Alcotest.failf "%S is not a node of the section" text)
      chain
  in
  Alcotest.(check (list int))
    "the H2 title comes first, then H3 to H6 in document order"
    (List.sort compare positions)
    positions;
  Alcotest.(check int)
    "five distinct headings" 5
    (List.length (List.sort_uniq compare positions))

let test_unstyled_heading_beside_plain_text () =
  let root = section () in
  let pair = node_in "the unstyled pair" "headings-unstyled-pair" root in
  let heading = node_in "the unstyled heading" "headings-unstyled" pair in
  let plain = node_in "the plain text" "headings-plain-text" pair in
  Alcotest.(check bool)
    "the unstyled heading is an H3 reading its text" true
    (heading_in Element.H3 "An unstyled heading" pair == heading);
  Alcotest.(check bool)
    "the heading carries no style at all" true
    (match style heading with
    | Some s -> Style.equal s Style.default
    | None -> false);
  Alcotest.(check bool)
    "the heading carries no interaction states" false
    (match interaction heading with
    | Some i -> Interaction.has_any i
    | None -> true);
  Alcotest.(check string)
    "the sibling reads as plain text" "Plain text beside it"
    (text_content plain);
  Alcotest.(check bool)
    "the sibling is no heading" true
    (Option.is_none (find_heading Element.H3 "Plain text beside it" pair))

let test_styled_heading_with_interaction () =
  let root = section () in
  let heading = node_in "the styled heading" "headings-styled" root in
  Alcotest.(check bool)
    "the styled heading is an H3 reading its text" true
    (heading_in Element.H3 "A styled heading" root == heading);
  Alcotest.(check bool)
    "it carries interaction states" true
    (match interaction heading with
    | Some i -> Interaction.has_any i
    | None -> false);
  Alcotest.(check (option (float 0.0)))
    "its base style sets a 1.5rem font size" (Some 1.5)
    (match style heading with
    | Some s -> s.Style.text.font_size
    | None -> None)

let () =
  Alcotest.run "kitchen_sink_headings_section"
    [
      ( "headings_section",
        [
          Alcotest.test_case "headings_section_chain_in_order" `Quick
            test_chain_in_order;
          Alcotest.test_case "unstyled_heading_beside_plain_text" `Quick
            test_unstyled_heading_beside_plain_text;
          Alcotest.test_case "styled_heading_with_interaction" `Quick
            test_styled_heading_with_interaction;
        ] );
    ]

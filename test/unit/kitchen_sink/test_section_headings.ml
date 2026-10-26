(* The kitchen sink's outline, read structurally through the whole page: the
   page title is the one H1, every section title is an H2, and every H3 comes
   after at least one H2. The levels deeper than H3 belong to the
   headings section alone, which shows every level on purpose.

   What this file cannot see is how a browser exposes the outline or whether a
   heading looks like the text around it — that is the browser spec's job. *)

open Nopal_test.Test_renderer
module Element = Nopal_element.Element

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
let page () = tree (render (K.view vp (fst (K.init ()))))
let headings_section_testid = "headings-section"

let level_of_tag tag =
  match tag with
  | "h1" -> Some 1
  | "h2" -> Some 2
  | "h3" -> Some 3
  | "h4" -> Some 4
  | "h5" -> Some 5
  | "h6" -> Some 6
  | _ -> None

(* Every heading in document order, as its level, its text, and whether it sits
   inside the headings section. *)
let outline root =
  let rec walk ~in_section acc node =
    match node with
    | Empty
    | Text _ ->
        acc
    | Element { tag; attrs; children; _ } ->
        let in_section =
          in_section
          || List.exists
               (fun (k, v) ->
                 String.equal k "data-testid"
                 && String.equal v headings_section_testid)
               attrs
        in
        let acc =
          match level_of_tag tag with
          | Some level -> (level, text_content node, in_section) :: acc
          | None -> acc
        in
        List.fold_left (walk ~in_section) acc children
  in
  List.rev (walk ~in_section:false [] root)

(* The text of every H3 that appears before any H2 has been seen. *)
let h3s_without_a_preceding_h2 headings =
  let _seen_h2, orphans =
    List.fold_left
      (fun (seen_h2, orphans) (level, text, _) ->
        match level with
        | 2 -> (true, orphans)
        | 3 when not seen_h2 -> (seen_h2, text :: orphans)
        | _ -> (seen_h2, orphans))
      (false, []) headings
  in
  List.rev orphans

let expect_heading level text root =
  match find_heading level text root with
  | Some _ -> ()
  | None ->
      Alcotest.failf "no H%d reading %S on the page"
        (Element.heading_level_to_int level)
        text

let test_page_title_is_h1 () =
  let root = page () in
  expect_heading Element.H1 "Kitchen Sink" root;
  Alcotest.(check int)
    "the page has exactly one H1" 1
    (List.length (List.filter (fun (l, _, _) -> l = 1) (outline root)))

let test_section_titles_are_h2 () =
  let root = page () in
  List.iter
    (fun title -> expect_heading Element.H2 title root)
    [
      "Typography";
      "Layout";
      "Buttons";
      "Telemetry";
      "2D Drawing";
      "Charts";
      "Chart Extensions";
      "UI Components";
      "Mobile Signals";
    ]

let test_in_section_titles_are_h3_under_an_h2 () =
  let root = page () in
  List.iter
    (fun title -> expect_heading Element.H3 title root)
    [ "Responsive typography"; "Viewport Info"; "Safe Area Insets" ];
  let headings = outline root in
  Alcotest.(check (list string))
    "no H3 comes before the first H2" []
    (h3s_without_a_preceding_h2 headings);
  Alcotest.(check (list string))
    "the check reports an H3 that comes first" [ "x" ]
    (h3s_without_a_preceding_h2 [ (3, "x", false); (2, "y", false) ]);
  List.iter
    (fun (level, text, in_section) ->
      match level >= 4 && not in_section with
      | true ->
          Alcotest.failf "H%d %S sits outside the headings section" level text
      | false -> ())
    headings;
  (* The same walk reports a deep heading when there is one, so the absence
     above is the page's and not the walk's. *)
  let deep =
    outline
      (tree
         (render
            (Element.column [ Element.heading Element.H4 (Element.text "x") ])))
  in
  Alcotest.(check (list (triple int string bool)))
    "the walk sees an H4 outside the section"
    [ (4, "x", false) ]
    deep

let () =
  Alcotest.run "kitchen_sink_section_headings"
    [
      ( "section_headings",
        [
          Alcotest.test_case "page_title_is_h1" `Quick test_page_title_is_h1;
          Alcotest.test_case "section_titles_are_h2" `Quick
            test_section_titles_are_h2;
          Alcotest.test_case "in_section_titles_are_h3_under_an_h2" `Quick
            test_in_section_titles_are_h3_under_an_h2;
        ] );
    ]

open Nopal_element
open Nopal_test.Test_renderer

let phone_view vp =
  Element.responsive vp
    ~compact:
      (Element.column [ Element.text "phone nav"; Element.text "content" ])
    ~expanded:(Element.row [ Element.text "sidebar"; Element.text "content" ])
    ()

let test_responsive_phone_layout () =
  let el = phone_view Viewport.phone in
  let r = render el in
  let t = tree r in
  let tag =
    match t with
    | Element { tag; _ } -> tag
    | _ -> "unknown"
  in
  Alcotest.(check string) "phone layout is column" "column" tag;
  let nav_text = text_content (Option.get (find First_child t)) in
  Alcotest.(check string) "first child is phone nav" "phone nav" nav_text

let test_responsive_desktop_layout () =
  let el = phone_view Viewport.desktop in
  let r = render el in
  let t = tree r in
  let tag =
    match t with
    | Element { tag; _ } -> tag
    | _ -> "unknown"
  in
  Alcotest.(check string) "desktop layout is row" "row" tag;
  let sidebar_text = text_content (Option.get (find First_child t)) in
  Alcotest.(check string) "first child is sidebar" "sidebar" sidebar_text

let test_responsive_renders_correct_subtree () =
  let el =
    Element.responsive Viewport.phone
      ~compact:(Element.text "I am compact")
      ~expanded:(Element.text "I am expanded")
      ()
  in
  let r = render el in
  let content = text_content (tree r) in
  Alcotest.(check string) "renders compact subtree" "I am compact" content

let () =
  Alcotest.run "Responsive Structural"
    [
      ( "structural",
        [
          Alcotest.test_case "phone layout" `Quick test_responsive_phone_layout;
          Alcotest.test_case "desktop layout" `Quick
            test_responsive_desktop_layout;
          Alcotest.test_case "renders correct subtree" `Quick
            test_responsive_renders_correct_subtree;
        ] );
    ]

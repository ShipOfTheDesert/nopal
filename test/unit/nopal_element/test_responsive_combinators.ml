open Nopal_element

let compact_vp = Viewport.phone
let medium_vp = Viewport.tablet
let expanded_vp = Viewport.desktop
let compact_el = Element.text "compact"
let medium_el = Element.text "medium"
let expanded_el = Element.text "expanded"

let compact_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (Nopal_style.Style.padding_all 4.0)

let medium_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (Nopal_style.Style.padding_all 8.0)

let expanded_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (Nopal_style.Style.padding_all 16.0)

let element_testable =
  Alcotest.testable (fun fmt _ -> Format.fprintf fmt "<element>") Element.equal

let style_testable =
  Alcotest.testable
    (fun fmt _ -> Format.fprintf fmt "<style>")
    Nopal_style.Style.equal

let test_responsive_compact_selects_compact () =
  let result =
    Element.responsive compact_vp ~compact:compact_el ~expanded:expanded_el ()
  in
  Alcotest.(check element_testable) "compact branch selected" compact_el result

let test_responsive_medium_selects_medium () =
  let result =
    Element.responsive medium_vp ~compact:compact_el ~medium:medium_el
      ~expanded:expanded_el ()
  in
  Alcotest.(check element_testable) "medium branch selected" medium_el result

let test_responsive_expanded_selects_expanded () =
  let result =
    Element.responsive expanded_vp ~compact:compact_el ~expanded:expanded_el ()
  in
  Alcotest.(check element_testable)
    "expanded branch selected" expanded_el result

let test_responsive_medium_fallback_to_compact () =
  let result =
    Element.responsive medium_vp ~compact:compact_el ~expanded:expanded_el ()
  in
  Alcotest.(check element_testable)
    "medium falls back to compact" compact_el result

let test_responsive_style_compact () =
  let result =
    Element.responsive_style compact_vp ~compact:compact_style
      ~expanded:expanded_style ()
  in
  Alcotest.(check style_testable) "compact style selected" compact_style result

let test_responsive_style_medium () =
  let result =
    Element.responsive_style medium_vp ~compact:compact_style
      ~medium:medium_style ~expanded:expanded_style ()
  in
  Alcotest.(check style_testable) "medium style selected" medium_style result

let test_responsive_style_expanded () =
  let result =
    Element.responsive_style expanded_vp ~compact:compact_style
      ~expanded:expanded_style ()
  in
  Alcotest.(check style_testable)
    "expanded style selected" expanded_style result

let test_responsive_style_medium_fallback () =
  let result =
    Element.responsive_style medium_vp ~compact:compact_style
      ~expanded:expanded_style ()
  in
  Alcotest.(check style_testable)
    "medium falls back to compact style" compact_style result

let () =
  Alcotest.run "Responsive Combinators"
    [
      ( "responsive",
        [
          Alcotest.test_case "compact selects compact" `Quick
            test_responsive_compact_selects_compact;
          Alcotest.test_case "medium selects medium" `Quick
            test_responsive_medium_selects_medium;
          Alcotest.test_case "expanded selects expanded" `Quick
            test_responsive_expanded_selects_expanded;
          Alcotest.test_case "medium fallback to compact" `Quick
            test_responsive_medium_fallback_to_compact;
        ] );
      ( "responsive_style",
        [
          Alcotest.test_case "compact style" `Quick
            test_responsive_style_compact;
          Alcotest.test_case "medium style" `Quick test_responsive_style_medium;
          Alcotest.test_case "expanded style" `Quick
            test_responsive_style_expanded;
          Alcotest.test_case "medium fallback style" `Quick
            test_responsive_style_medium_fallback;
        ] );
    ]

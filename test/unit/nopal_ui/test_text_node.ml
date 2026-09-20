open Nopal_test.Test_renderer
module TN = Nopal_ui.Text_node

let text_style_testable = Test_util.text_style_testable

let bold =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_text (fun t ->
      { t with Nopal_style.Text.font_weight = Some Nopal_style.Font.Bold })

let layout_only =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (fun l ->
      { l with Nopal_style.Style.gap = Some 8.0 })

(* [unit] is the message type: no case in this suite dispatches. *)
let render_node el = tree (render (el : unit Nopal_element.Element.t))

let test_no_style_is_a_plain_text_node () =
  let node = render_node (TN.of_style ~style:None "Email") in
  Alcotest.(check string) "content" "Email" (text_content node);
  Alcotest.(check (option text_style_testable))
    "a plain text node carries no text style" None (text_style node)

let test_the_styles_text_component_reaches_the_node () =
  let node = render_node (TN.of_style ~style:(Some bold) "Email") in
  Alcotest.(check string) "content" "Email" (text_content node);
  Alcotest.(check (option text_style_testable))
    "the style's text component, not the style"
    (Some bold.Nopal_style.Style.text) (text_style node)

let test_a_style_with_no_text_component_still_styles_the_node () =
  let node = render_node (TN.of_style ~style:(Some layout_only) "Email") in
  Alcotest.(check (option text_style_testable))
    "the arm is chosen by the option, never by the text component's contents"
    (Some layout_only.Nopal_style.Style.text) (text_style node)

let test_of_text_style_takes_the_component_directly () =
  let node =
    render_node
      (TN.of_text_style ~text_style:(Some bold.Nopal_style.Style.text) "Email")
  in
  Alcotest.(check string) "content" "Email" (text_content node);
  Alcotest.(check (option text_style_testable))
    "the component reaches the node" (Some bold.Nopal_style.Style.text)
    (text_style node);
  Alcotest.(check (option text_style_testable))
    "and [None] is still a plain text node" None
    (text_style (render_node (TN.of_text_style ~text_style:None "Email")))

let () =
  Alcotest.run "nopal_ui_text_node"
    [
      ( "of_style",
        [
          Alcotest.test_case "no style is a plain text node" `Quick
            test_no_style_is_a_plain_text_node;
          Alcotest.test_case "the style's text component reaches the node"
            `Quick test_the_styles_text_component_reaches_the_node;
          Alcotest.test_case "a style with no text component still styles"
            `Quick test_a_style_with_no_text_component_still_styles_the_node;
        ] );
      ( "of_text_style",
        [
          Alcotest.test_case "the component reaches the node directly" `Quick
            test_of_text_style_takes_the_component_directly;
        ] );
    ]

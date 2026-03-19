open Nopal_element

type msg = Click | Submit | Changed of string

let test_empty_builder () =
  Alcotest.(check bool)
    "empty is Empty" true
    (match Element.empty with
    | Element.Empty -> true
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_text_builder () =
  Alcotest.(check bool)
    "text produces Text" true
    (match Element.text "hello" with
    | Element.Text { content = "hello"; _ } -> true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_default_styles () =
  let check_style label el =
    let style =
      match el with
      | Element.Box { style; _ } -> style
      | Element.Row { style; _ } -> style
      | Element.Column { style; _ } -> style
      | Element.Image { style; _ } -> style
      | Element.Scroll { style; _ } -> style
      | Element.Empty
      | Element.Text _
      | Element.Button _
      | Element.Input _
      | Element.Keyed _
      | Element.Draw _ ->
          Alcotest.fail (label ^ ": unexpected variant")
    in
    Alcotest.(check bool)
      (label ^ " defaults to Style.empty")
      true
      (Nopal_style.Style.equal style Nopal_style.Style.empty)
  in
  check_style "box" (Element.box []);
  check_style "row" (Element.row []);
  check_style "column" (Element.column []);
  check_style "image" (Element.image ~src:"a.png" ~alt:"pic" ());
  check_style "scroll" (Element.scroll Element.empty)

let test_box_preserves_children () =
  let a = Element.text "a" in
  let b = Element.text "b" in
  let c = Element.text "c" in
  Alcotest.(check bool)
    "box preserves children in order" true
    (match Element.box [ a; b; c ] with
    | Element.Box { children; _ } -> (
        match children with
        | [
         Element.Text { content = "a"; _ };
         Element.Text { content = "b"; _ };
         Element.Text { content = "c"; _ };
        ] ->
            true
        | _ -> false)
    | Element.Empty
    | Element.Text _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_button_no_handler () =
  Alcotest.(check bool)
    "button without handlers has None" true
    (match Element.button (Element.text "ok") with
    | Element.Button { on_click = None; on_dblclick = None; _ } -> true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_button_with_handler () =
  Alcotest.(check bool)
    "button with on_click has Some" true
    (match Element.button ~on_click:Click (Element.text "ok") with
    | Element.Button { on_click = Some Click; _ } -> true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_button_child () =
  let child = Element.text "label" in
  Alcotest.(check bool)
    "button wraps given child" true
    (match Element.button child with
    | Element.Button { child = Element.Text { content = "label"; _ }; _ } ->
        true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_input_defaults () =
  Alcotest.(check bool)
    "input defaults" true
    (match Element.input "val" with
    | Element.Input
        {
          value = "val";
          placeholder = "";
          on_change = None;
          on_submit = None;
          on_blur = None;
          on_keydown = None;
          _;
        } ->
        true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_input_placeholder () =
  Alcotest.(check bool)
    "input placeholder" true
    (match Element.input ~placeholder:"type here" "" with
    | Element.Input { placeholder = "type here"; _ } -> true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_input_on_change () =
  let handler s = Changed s in
  Alcotest.(check bool)
    "input on_change" true
    (match Element.input ~on_change:handler "x" with
    | Element.Input { on_change = Some f; _ } -> (
        match f "abc" with
        | Changed "abc" -> true
        | Click
        | Submit
        | Changed _ ->
            false)
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_input_on_submit () =
  Alcotest.(check bool)
    "input on_submit" true
    (match Element.input ~on_submit:Submit "" with
    | Element.Input { on_submit = Some Submit; _ } -> true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_image_required_fields () =
  Alcotest.(check bool)
    "image required fields" true
    (match Element.image ~src:"a.png" ~alt:"pic" () with
    | Element.Image { src = "a.png"; alt = "pic"; _ } -> true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_scroll_child () =
  Alcotest.(check bool)
    "scroll wraps child" true
    (match Element.scroll (Element.text "inner") with
    | Element.Scroll { child = Element.Text { content = "inner"; _ }; _ } ->
        true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_keyed_preserves_key () =
  Alcotest.(check bool)
    "keyed preserves key" true
    (match Element.keyed "k1" Element.empty with
    | Element.Keyed { key = "k1"; _ } -> true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_keyed_preserves_child () =
  Alcotest.(check bool)
    "keyed preserves child" true
    (match Element.keyed "k1" (Element.text "x") with
    | Element.Keyed { child = Element.Text { content = "x"; _ }; _ } -> true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

type wrapper = Wrapped of msg

let test_map_transforms_click () =
  let el = Element.button ~on_click:Click (Element.text "ok") in
  let mapped = Element.map (fun m -> Wrapped m) el in
  Alcotest.(check bool)
    "map transforms on_click" true
    (match mapped with
    | Element.Button { on_click = Some (Wrapped Click); _ } -> true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_map_transforms_input () =
  let handler s = Changed s in
  let el = Element.input ~on_change:handler ~on_submit:Submit "v" in
  let mapped = Element.map (fun m -> Wrapped m) el in
  Alcotest.(check bool)
    "map transforms input handlers" true
    (match mapped with
    | Element.Input { on_change = Some f; on_submit = Some (Wrapped Submit); _ }
      -> (
        match f "x" with
        | Wrapped (Changed "x") -> true
        | Wrapped (Click | Submit | Changed _) -> false)
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_map_recursive () =
  let el =
    Element.box
      [
        Element.button ~on_click:Click (Element.text "a");
        Element.row [ Element.button ~on_click:Submit (Element.text "b") ];
      ]
  in
  let mapped = Element.map (fun m -> Wrapped m) el in
  Alcotest.(check bool)
    "map recurses into children" true
    (match mapped with
    | Element.Box
        {
          children =
            [
              Element.Button { on_click = Some (Wrapped Click); _ };
              Element.Row
                {
                  children =
                    [ Element.Button { on_click = Some (Wrapped Submit); _ } ];
                  _;
                };
            ];
          _;
        } ->
        true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_map_column () =
  let el =
    Element.column [ Element.button ~on_click:Click (Element.text "c") ]
  in
  let mapped = Element.map (fun m -> Wrapped m) el in
  Alcotest.(check bool)
    "map transforms column children" true
    (match mapped with
    | Element.Column
        {
          children = [ Element.Button { on_click = Some (Wrapped Click); _ } ];
          _;
        } ->
        true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_map_image () =
  let el = Element.image ~src:"a.png" ~alt:"pic" () in
  let mapped = Element.map (fun m -> Wrapped m) el in
  Alcotest.(check bool)
    "map preserves image fields" true
    (match mapped with
    | Element.Image { src = "a.png"; alt = "pic"; _ } -> true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_map_scroll () =
  let el = Element.scroll (Element.button ~on_click:Click (Element.text "s")) in
  let mapped = Element.map (fun m -> Wrapped m) el in
  Alcotest.(check bool)
    "map transforms scroll child" true
    (match mapped with
    | Element.Scroll
        { child = Element.Button { on_click = Some (Wrapped Click); _ }; _ } ->
        true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_map_keyed () =
  let el =
    Element.keyed "k" (Element.button ~on_click:Click (Element.text "k"))
  in
  let mapped = Element.map (fun m -> Wrapped m) el in
  Alcotest.(check bool)
    "map transforms keyed child" true
    (match mapped with
    | Element.Keyed
        {
          key = "k";
          child = Element.Button { on_click = Some (Wrapped Click); _ };
        } ->
        true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_map_empty_noop () =
  let mapped = Element.map (fun m -> Wrapped m) Element.empty in
  Alcotest.(check bool)
    "map on Empty returns Empty" true
    (match mapped with
    | Element.Empty -> true
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_map_text_noop () =
  let mapped = Element.map (fun m -> Wrapped m) (Element.text "hi") in
  Alcotest.(check bool)
    "map on Text returns same Text" true
    (match mapped with
    | Element.Text { content = "hi"; _ } -> true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_equal_text_same () =
  Alcotest.(check bool)
    "same Text equals" true
    (Element.equal (Element.text "hi") (Element.text "hi"))

let test_equal_text_different () =
  Alcotest.(check bool)
    "different Text not equal" false
    (Element.equal (Element.text "hi") (Element.text "bye"))

let test_equal_deep_nesting () =
  let tree =
    Element.box [ Element.row [ Element.column [ Element.text "deep" ] ] ]
  in
  Alcotest.(check bool)
    "identical deep trees are equal" true (Element.equal tree tree)

let test_equal_deep_nesting_distinct () =
  let make () =
    Element.box [ Element.row [ Element.column [ Element.text "deep" ] ] ]
  in
  Alcotest.(check bool)
    "separately constructed deep trees are equal" true
    (Element.equal (make ()) (make ()))

let test_equal_different_structure () =
  let a = Element.box [ Element.text "a" ] in
  let b = Element.row [ Element.text "a" ] in
  Alcotest.(check bool) "Box vs Row not equal" false (Element.equal a b)

let test_equal_different_children_count () =
  let a = Element.box [ Element.text "a" ] in
  let b = Element.box [ Element.text "a"; Element.text "b" ] in
  Alcotest.(check bool)
    "different children count not equal" false (Element.equal a b)

let test_equal_button_distinct () =
  let make () = Element.button ~on_click:Click (Element.text "ok") in
  Alcotest.(check bool)
    "separately constructed buttons are equal" true
    (Element.equal (make ()) (make ()))

let test_equal_button_different_click () =
  let a = Element.button ~on_click:Click (Element.text "ok") in
  let b = Element.button ~on_click:Submit (Element.text "ok") in
  Alcotest.(check bool) "different on_click not equal" false (Element.equal a b)

let test_equal_input_distinct () =
  let make () = Element.input ~on_submit:Submit ~placeholder:"p" "v" in
  Alcotest.(check bool)
    "separately constructed inputs are equal" true
    (Element.equal (make ()) (make ()))

let test_equal_input_different_value () =
  let a = Element.input "a" in
  let b = Element.input "b" in
  Alcotest.(check bool)
    "different input value not equal" false (Element.equal a b)

let test_equal_input_different_placeholder () =
  let a = Element.input ~placeholder:"x" "" in
  let b = Element.input ~placeholder:"y" "" in
  Alcotest.(check bool)
    "different placeholder not equal" false (Element.equal a b)

let test_equal_image_distinct () =
  let make () = Element.image ~src:"a.png" ~alt:"pic" () in
  Alcotest.(check bool)
    "separately constructed images are equal" true
    (Element.equal (make ()) (make ()))

let test_equal_image_different_src () =
  let a = Element.image ~src:"a.png" ~alt:"pic" () in
  let b = Element.image ~src:"b.png" ~alt:"pic" () in
  Alcotest.(check bool) "different src not equal" false (Element.equal a b)

let test_equal_image_different_alt () =
  let a = Element.image ~src:"a.png" ~alt:"pic" () in
  let b = Element.image ~src:"a.png" ~alt:"photo" () in
  Alcotest.(check bool) "different alt not equal" false (Element.equal a b)

let test_equal_scroll_distinct () =
  let make () = Element.scroll (Element.text "inner") in
  Alcotest.(check bool)
    "separately constructed scrolls are equal" true
    (Element.equal (make ()) (make ()))

let test_equal_scroll_different_child () =
  let a = Element.scroll (Element.text "a") in
  let b = Element.scroll (Element.text "b") in
  Alcotest.(check bool)
    "different scroll child not equal" false (Element.equal a b)

let test_equal_keyed_distinct () =
  let make () = Element.keyed "k" (Element.text "x") in
  Alcotest.(check bool)
    "separately constructed keyeds are equal" true
    (Element.equal (make ()) (make ()))

let test_equal_keyed_different_key () =
  let a = Element.keyed "k1" (Element.text "x") in
  let b = Element.keyed "k2" (Element.text "x") in
  Alcotest.(check bool) "different key not equal" false (Element.equal a b)

let test_equal_keyed_different_child () =
  let a = Element.keyed "k" (Element.text "a") in
  let b = Element.keyed "k" (Element.text "b") in
  Alcotest.(check bool)
    "different keyed child not equal" false (Element.equal a b)

let test_box_default_interaction () =
  Alcotest.(check bool)
    "box defaults to Interaction.default" true
    (match Element.box [] with
    | Element.Box { interaction; _ } ->
        Nopal_style.Interaction.equal interaction
          Nopal_style.Interaction.default
    | Element.Empty
    | Element.Text _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let hover_style = Nopal_style.Style.empty

let test_interaction =
  { Nopal_style.Interaction.default with hover = Some hover_style }

let test_button_with_interaction () =
  let ix = test_interaction in
  Alcotest.(check bool)
    "button accepts interaction" true
    (match Element.button ~interaction:ix (Element.text "ok") with
    | Element.Button { interaction; _ } ->
        Nopal_style.Interaction.equal interaction ix
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_input_with_interaction () =
  let ix = test_interaction in
  Alcotest.(check bool)
    "input accepts interaction" true
    (match Element.input ~interaction:ix "val" with
    | Element.Input { interaction; _ } ->
        Nopal_style.Interaction.equal interaction ix
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_map_preserves_interaction () =
  let ix = test_interaction in
  let check_one label el =
    let interaction =
      match el with
      | Element.Button { interaction; _ } -> interaction
      | Element.Box { interaction; _ } -> interaction
      | Element.Row { interaction; _ } -> interaction
      | Element.Column { interaction; _ } -> interaction
      | Element.Input { interaction; _ } -> interaction
      | Element.Empty
      | Element.Text _
      | Element.Image _
      | Element.Scroll _
      | Element.Keyed _
      | Element.Draw _ ->
          Alcotest.fail (label ^ ": unexpected variant")
    in
    Alcotest.(check bool)
      ("map preserves interaction on " ^ label)
      true
      (Nopal_style.Interaction.equal interaction ix)
  in
  check_one "button"
    (Element.map
       (fun _m -> ())
       (Element.button ~interaction:ix ~on_click:Click (Element.text "ok")));
  check_one "box"
    (Element.map
       (fun _m -> ())
       (Element.box ~interaction:ix [ Element.text "child" ]));
  check_one "row"
    (Element.map
       (fun _m -> ())
       (Element.row ~interaction:ix [ Element.text "child" ]));
  check_one "column"
    (Element.map
       (fun _m -> ())
       (Element.column ~interaction:ix [ Element.text "child" ]));
  check_one "input"
    (Element.map (fun _m -> ()) (Element.input ~interaction:ix "val"))

let test_equal_different_interaction () =
  let ix = test_interaction in
  let a = Element.box ~interaction:ix [] in
  let b = Element.box [] in
  Alcotest.(check bool)
    "different interaction not equal" false (Element.equal a b)

let test_styled_text_carries_style () =
  let ts =
    Nopal_style.Text.default
    |> Nopal_style.Text.font_size 16.0
    |> Nopal_style.Text.font_weight Nopal_style.Font.Bold
  in
  Alcotest.(check bool)
    "styled_text carries text_style" true
    (match Element.styled_text ~text_style:ts "hello" with
    | Element.Text { content = "hello"; text_style = Some ts' } ->
        Nopal_style.Text.equal ts ts'
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_styled_text_with_default_is_some () =
  Alcotest.(check bool)
    "styled_text with default text style is Some" true
    (match Element.styled_text ~text_style:Nopal_style.Text.default "hi" with
    | Element.Text { content = "hi"; text_style = Some ts } ->
        Nopal_style.Text.equal ts Nopal_style.Text.default
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let () =
  Alcotest.run "nopal_element"
    [
      ( "builders",
        [
          Alcotest.test_case "empty_builder" `Quick test_empty_builder;
          Alcotest.test_case "text_builder" `Quick test_text_builder;
          Alcotest.test_case "default_styles" `Quick test_default_styles;
          Alcotest.test_case "box_preserves_children" `Quick
            test_box_preserves_children;
          Alcotest.test_case "button_no_handler" `Quick test_button_no_handler;
          Alcotest.test_case "button_with_handler" `Quick
            test_button_with_handler;
          Alcotest.test_case "button_child" `Quick test_button_child;
          Alcotest.test_case "input_defaults" `Quick test_input_defaults;
          Alcotest.test_case "input_placeholder" `Quick test_input_placeholder;
          Alcotest.test_case "input_on_change" `Quick test_input_on_change;
          Alcotest.test_case "input_on_submit" `Quick test_input_on_submit;
          Alcotest.test_case "image_required_fields" `Quick
            test_image_required_fields;
          Alcotest.test_case "scroll_child" `Quick test_scroll_child;
          Alcotest.test_case "keyed_preserves_key" `Quick
            test_keyed_preserves_key;
          Alcotest.test_case "keyed_preserves_child" `Quick
            test_keyed_preserves_child;
        ] );
      ( "map",
        [
          Alcotest.test_case "map_transforms_click" `Quick
            test_map_transforms_click;
          Alcotest.test_case "map_transforms_input" `Quick
            test_map_transforms_input;
          Alcotest.test_case "map_recursive" `Quick test_map_recursive;
          Alcotest.test_case "map_column" `Quick test_map_column;
          Alcotest.test_case "map_image" `Quick test_map_image;
          Alcotest.test_case "map_scroll" `Quick test_map_scroll;
          Alcotest.test_case "map_keyed" `Quick test_map_keyed;
          Alcotest.test_case "map_empty_noop" `Quick test_map_empty_noop;
          Alcotest.test_case "map_text_noop" `Quick test_map_text_noop;
        ] );
      ( "equal",
        [
          Alcotest.test_case "equal_text_same" `Quick test_equal_text_same;
          Alcotest.test_case "equal_text_different" `Quick
            test_equal_text_different;
          Alcotest.test_case "equal_deep_nesting" `Quick test_equal_deep_nesting;
          Alcotest.test_case "equal_deep_nesting_distinct" `Quick
            test_equal_deep_nesting_distinct;
          Alcotest.test_case "equal_different_structure" `Quick
            test_equal_different_structure;
          Alcotest.test_case "equal_different_children_count" `Quick
            test_equal_different_children_count;
          Alcotest.test_case "equal_button_distinct" `Quick
            test_equal_button_distinct;
          Alcotest.test_case "equal_button_different_click" `Quick
            test_equal_button_different_click;
          Alcotest.test_case "equal_input_distinct" `Quick
            test_equal_input_distinct;
          Alcotest.test_case "equal_input_different_value" `Quick
            test_equal_input_different_value;
          Alcotest.test_case "equal_input_different_placeholder" `Quick
            test_equal_input_different_placeholder;
          Alcotest.test_case "equal_image_distinct" `Quick
            test_equal_image_distinct;
          Alcotest.test_case "equal_image_different_src" `Quick
            test_equal_image_different_src;
          Alcotest.test_case "equal_image_different_alt" `Quick
            test_equal_image_different_alt;
          Alcotest.test_case "equal_scroll_distinct" `Quick
            test_equal_scroll_distinct;
          Alcotest.test_case "equal_scroll_different_child" `Quick
            test_equal_scroll_different_child;
          Alcotest.test_case "equal_keyed_distinct" `Quick
            test_equal_keyed_distinct;
          Alcotest.test_case "equal_keyed_different_key" `Quick
            test_equal_keyed_different_key;
          Alcotest.test_case "equal_keyed_different_child" `Quick
            test_equal_keyed_different_child;
        ] );
      ( "interaction",
        [
          Alcotest.test_case "box_default_interaction" `Quick
            test_box_default_interaction;
          Alcotest.test_case "button_with_interaction" `Quick
            test_button_with_interaction;
          Alcotest.test_case "input_with_interaction" `Quick
            test_input_with_interaction;
          Alcotest.test_case "map_preserves_interaction" `Quick
            test_map_preserves_interaction;
          Alcotest.test_case "equal_different_interaction" `Quick
            test_equal_different_interaction;
        ] );
      ( "styled_text",
        [
          Alcotest.test_case "styled_text_carries_style" `Quick
            test_styled_text_carries_style;
          Alcotest.test_case "styled_text_with_default_is_some" `Quick
            test_styled_text_with_default_is_some;
        ] );
    ]

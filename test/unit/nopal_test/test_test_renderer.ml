open Nopal_test.Test_renderer
module E = Nopal_element.Element
module R = Nopal_element.Reveal
module Ix = Nopal_style.Interaction

let ix0 = Ix.default
let s0 = Nopal_style.Style.default
let check_node = Test_util.check_node

(* Task 1: Rendering tests *)

let render_empty () =
  let r = render E.empty in
  check_node "empty renders to Empty" Empty (tree r)

let render_text () =
  let r = render (E.text "hello") in
  check_node "text renders to Text"
    (Text { content = "hello"; text_style = None })
    (tree r)

let render_box () =
  let r = render (E.box [ E.text "a"; E.text "b" ]) in
  check_node "box renders correctly"
    (Element
       {
         tag = "box";
         style = s0;
         attrs = [];
         children =
           [
             Text { content = "a"; text_style = None };
             Text { content = "b"; text_style = None };
           ];
         interaction = ix0;
       })
    (tree r)

let render_row () =
  let r = render (E.row [ E.text "a" ]) in
  check_node "row renders correctly"
    (Element
       {
         tag = "row";
         style = s0;
         attrs = [];
         children = [ Text { content = "a"; text_style = None } ];
         interaction = ix0;
       })
    (tree r)

let render_column () =
  let r = render (E.column [ E.text "a" ]) in
  check_node "column renders correctly"
    (Element
       {
         tag = "column";
         style = s0;
         attrs = [];
         children = [ Text { content = "a"; text_style = None } ];
         interaction = ix0;
       })
    (tree r)

let render_button () =
  let r = render (E.button (E.text "click me")) in
  check_node "button renders correctly"
    (Element
       {
         tag = "button";
         style = s0;
         attrs = [];
         children = [ Text { content = "click me"; text_style = None } ];
         interaction = ix0;
       })
    (tree r)

let render_input_attrs () =
  let r = render (E.input ~placeholder:"ph" "val") in
  check_node "input renders with attrs"
    (Element
       {
         tag = "input";
         style = s0;
         attrs = [ ("value", "val"); ("placeholder", "ph") ];
         children = [];
         interaction = ix0;
       })
    (tree r)

let render_image_attrs () =
  let r = render (E.image ~src:"a.png" ~alt:"pic" ()) in
  check_node "image renders with attrs"
    (Element
       {
         tag = "image";
         style = s0;
         attrs = [ ("src", "a.png"); ("alt", "pic") ];
         children = [];
         interaction = ix0;
       })
    (tree r)

let render_scroll () =
  let r = render (E.scroll (E.text "content")) in
  check_node "scroll renders correctly"
    (Element
       {
         tag = "scroll";
         style = s0;
         attrs = [];
         children = [ Text { content = "content"; text_style = None } ];
         interaction = ix0;
       })
    (tree r)

let render_keyed () =
  let r = render (E.keyed "k1" (E.text "child")) in
  check_node "keyed renders correctly"
    (Element
       {
         tag = "keyed";
         style = s0;
         attrs = [ ("key", "k1") ];
         children = [ Text { content = "child"; text_style = None } ];
         interaction = ix0;
       })
    (tree r)

let render_nested () =
  let r =
    render
      (E.box
         [
           E.row [ E.text "a"; E.column [ E.text "b"; E.text "c" ] ]; E.text "d";
         ])
  in
  check_node "nested renders correctly"
    (Element
       {
         tag = "box";
         style = s0;
         attrs = [];
         children =
           [
             Element
               {
                 tag = "row";
                 style = s0;
                 attrs = [];
                 children =
                   [
                     Text { content = "a"; text_style = None };
                     Element
                       {
                         tag = "column";
                         style = s0;
                         attrs = [];
                         children =
                           [
                             Text { content = "b"; text_style = None };
                             Text { content = "c"; text_style = None };
                           ];
                         interaction = ix0;
                       };
                   ];
                 interaction = ix0;
               };
             Text { content = "d"; text_style = None };
           ];
         interaction = ix0;
       })
    (tree r)

let render_messages_empty () =
  let r = render (E.box [ E.text "hello" ]) in
  Alcotest.(check int) "messages start empty" 0 (List.length (messages r))

let rendering_tests =
  [
    Alcotest.test_case "render_empty" `Quick render_empty;
    Alcotest.test_case "render_text" `Quick render_text;
    Alcotest.test_case "render_box" `Quick render_box;
    Alcotest.test_case "render_row" `Quick render_row;
    Alcotest.test_case "render_column" `Quick render_column;
    Alcotest.test_case "render_button" `Quick render_button;
    Alcotest.test_case "render_input_attrs" `Quick render_input_attrs;
    Alcotest.test_case "render_image_attrs" `Quick render_image_attrs;
    Alcotest.test_case "render_scroll" `Quick render_scroll;
    Alcotest.test_case "render_keyed" `Quick render_keyed;
    Alcotest.test_case "render_nested" `Quick render_nested;
    Alcotest.test_case "render_messages_empty" `Quick render_messages_empty;
  ]

(* Task 2: Query tests *)

let sample_tree =
  E.box
    [
      E.row [ E.text "hello"; E.text "world" ];
      E.column
        [ E.button (E.text "click"); E.input ~placeholder:"search" "query" ];
      E.image ~src:"pic.png" ~alt:"photo" ();
    ]

let find_by_tag () =
  let r = render sample_tree in
  let result = find (By_tag "row") (tree r) in
  Alcotest.(check bool) "finds row element" true (Option.is_some result);
  match result with
  | Some (Element { tag; _ }) -> Alcotest.(check string) "tag is row" "row" tag
  | _ -> Alcotest.fail "expected Element"

let find_by_tag_nested () =
  let r = render sample_tree in
  let result = find (By_tag "button") (tree r) in
  Alcotest.(check bool) "finds nested button" true (Option.is_some result);
  match result with
  | Some (Element { tag; _ }) ->
      Alcotest.(check string) "tag is button" "button" tag
  | _ -> Alcotest.fail "expected Element"

let find_by_tag_not_found () =
  let r = render sample_tree in
  let result = find (By_tag "nonexistent") (tree r) in
  Alcotest.(check bool) "returns None" true (Option.is_none result)

let find_by_text () =
  let r = render sample_tree in
  let result = find (By_text "hello") (tree r) in
  Alcotest.(check bool) "finds text node" true (Option.is_some result);
  match result with
  | Some (Text { content; _ }) ->
      Alcotest.(check string) "text matches" "hello" content
  | _ -> Alcotest.fail "expected Text node"

let find_by_text_substring () =
  let r = render (E.box [ E.text "hello world" ]) in
  let result = find (By_text "world") (tree r) in
  Alcotest.(check bool) "finds text by substring" true (Option.is_some result);
  match result with
  | Some (Text { content; _ }) ->
      Alcotest.(check string) "full text" "hello world" content
  | _ -> Alcotest.fail "expected Text node"

let find_by_attr () =
  let r = render sample_tree in
  let result = find (By_attr ("src", "pic.png")) (tree r) in
  Alcotest.(check bool) "finds image by attr" true (Option.is_some result);
  match result with
  | Some (Element { tag; _ }) ->
      Alcotest.(check string) "tag is image" "image" tag
  | _ -> Alcotest.fail "expected Element"

let find_first_child () =
  let r = render (E.box [ E.text "a"; E.text "b"; E.text "c" ]) in
  let result = find First_child (tree r) in
  check_node "first child is text a"
    (Text { content = "a"; text_style = None })
    (Option.get result)

let find_first_child_empty () =
  let result = find First_child Empty in
  Alcotest.(check bool) "Empty has no first child" true (Option.is_none result);
  let result2 = find First_child (Text { content = "hi"; text_style = None }) in
  Alcotest.(check bool) "Text has no first child" true (Option.is_none result2)

let find_nth_child () =
  let r = render (E.box [ E.text "a"; E.text "b"; E.text "c" ]) in
  let result = find (Nth_child 1) (tree r) in
  check_node "nth child 1 is text b"
    (Text { content = "b"; text_style = None })
    (Option.get result)

let find_nth_child_out_of_bounds () =
  let r = render (E.box [ E.text "a" ]) in
  let result = find (Nth_child 5) (tree r) in
  Alcotest.(check bool)
    "out of bounds returns None" true (Option.is_none result)

let find_all_by_tag () =
  let r =
    render
      (E.box
         [
           E.row [ E.text "a" ];
           E.row [ E.text "b" ];
           E.column [ E.row [ E.text "c" ] ];
         ])
  in
  let results = find_all (By_tag "row") (tree r) in
  Alcotest.(check int) "finds all 3 rows" 3 (List.length results)

let find_all_empty_result () =
  let r = render (E.box [ E.text "hello" ]) in
  let results = find_all (By_tag "button") (tree r) in
  Alcotest.(check int) "finds no buttons" 0 (List.length results)

let text_content_text_node () =
  let s = text_content (Text { content = "hello"; text_style = None }) in
  Alcotest.(check string) "text content of Text" "hello" s

let text_content_element () =
  let r = render (E.box [ E.text "hello"; E.text " "; E.text "world" ]) in
  let s = text_content (tree r) in
  Alcotest.(check string) "concatenated text content" "hello world" s

let text_content_empty () =
  let s = text_content Empty in
  Alcotest.(check string) "empty text content" "" s

let has_attr_present () =
  let r = render (E.image ~src:"a.png" ~alt:"pic" ()) in
  Alcotest.(check bool) "has src attr" true (has_attr "src" (tree r))

let has_attr_absent () =
  let r = render (E.image ~src:"a.png" ~alt:"pic" ()) in
  Alcotest.(check bool) "no href attr" false (has_attr "href" (tree r))

let attr_present () =
  let r = render (E.image ~src:"a.png" ~alt:"pic" ()) in
  Alcotest.(check (option string))
    "attr src" (Some "a.png")
    (attr "src" (tree r))

let attr_absent () =
  let r = render (E.image ~src:"a.png" ~alt:"pic" ()) in
  Alcotest.(check (option string)) "attr href" None (attr "href" (tree r))

let querying_tests =
  [
    Alcotest.test_case "find_by_tag" `Quick find_by_tag;
    Alcotest.test_case "find_by_tag_nested" `Quick find_by_tag_nested;
    Alcotest.test_case "find_by_tag_not_found" `Quick find_by_tag_not_found;
    Alcotest.test_case "find_by_text" `Quick find_by_text;
    Alcotest.test_case "find_by_text_substring" `Quick find_by_text_substring;
    Alcotest.test_case "find_by_attr" `Quick find_by_attr;
    Alcotest.test_case "find_first_child" `Quick find_first_child;
    Alcotest.test_case "find_first_child_empty" `Quick find_first_child_empty;
    Alcotest.test_case "find_nth_child" `Quick find_nth_child;
    Alcotest.test_case "find_nth_child_out_of_bounds" `Quick
      find_nth_child_out_of_bounds;
    Alcotest.test_case "find_all_by_tag" `Quick find_all_by_tag;
    Alcotest.test_case "find_all_empty_result" `Quick find_all_empty_result;
    Alcotest.test_case "text_content_text_node" `Quick text_content_text_node;
    Alcotest.test_case "text_content_element" `Quick text_content_element;
    Alcotest.test_case "text_content_empty" `Quick text_content_empty;
    Alcotest.test_case "has_attr_present" `Quick has_attr_present;
    Alcotest.test_case "has_attr_absent" `Quick has_attr_absent;
    Alcotest.test_case "attr_present" `Quick attr_present;
    Alcotest.test_case "attr_absent" `Quick attr_absent;
  ]

(* Task 3: Event simulation tests *)

type msg = Click | Changed of string | Submit

let error_testable = Test_util.error_testable

let msg_testable =
  Alcotest.testable
    (fun fmt m ->
      match m with
      | Click -> Format.fprintf fmt "Click"
      | Changed s -> Format.fprintf fmt "Changed %S" s
      | Submit -> Format.fprintf fmt "Submit")
    ( = )

let click_button () =
  let r = render (E.button ~on_click:Click (E.text "ok")) in
  let result = click (By_tag "button") r in
  Alcotest.(check (result unit error_testable)) "click succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "message dispatched" [ Click ] (messages r)

let click_no_handler () =
  let r = render (E.button (E.text "no handler")) in
  let result = click (By_tag "button") r in
  Alcotest.(check (result unit error_testable))
    "click returns No_handler"
    (Error (No_handler { tag = "button"; event = "click" }))
    result;
  Alcotest.(check int) "no messages" 0 (List.length (messages r))

let click_not_found () =
  let r = render (E.box [ E.text "hello" ]) in
  let result = click (By_tag "button") r in
  Alcotest.(check (result unit error_testable))
    "click returns Not_found" (Error (Not_found (By_tag "button"))) result

let input_dispatches_on_change () =
  let r =
    render (E.input ~on_change:(fun s -> Changed s) ~placeholder:"type" "")
  in
  let result = input (By_tag "input") "hello" r in
  Alcotest.(check (result unit error_testable)) "input succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "change message dispatched" [ Changed "hello" ] (messages r)

let input_no_handler () =
  let r = render (E.input ~placeholder:"type" "") in
  let result = input (By_tag "input") "hello" r in
  Alcotest.(check (result unit error_testable))
    "input returns No_handler"
    (Error (No_handler { tag = "input"; event = "change" }))
    result

let submit_dispatches_on_submit () =
  let r = render (E.input ~on_submit:Submit ~placeholder:"type" "") in
  let result = submit (By_tag "input") r in
  Alcotest.(check (result unit error_testable)) "submit succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "submit message dispatched" [ Submit ] (messages r)

let submit_no_handler () =
  let r = render (E.input ~placeholder:"type" "") in
  let result = submit (By_tag "input") r in
  Alcotest.(check (result unit error_testable))
    "submit returns No_handler"
    (Error (No_handler { tag = "input"; event = "submit" }))
    result

let messages_accumulate () =
  let r = render (E.button ~on_click:Click (E.text "ok")) in
  let _ = click (By_tag "button") r in
  let _ = click (By_tag "button") r in
  let _ = click (By_tag "button") r in
  Alcotest.(check (list msg_testable))
    "three messages accumulated" [ Click; Click; Click ] (messages r)

let clear_messages_resets () =
  let r = render (E.button ~on_click:Click (E.text "ok")) in
  let _ = click (By_tag "button") r in
  Alcotest.(check int) "one message before clear" 1 (List.length (messages r));
  clear_messages r;
  Alcotest.(check int) "zero messages after clear" 0 (List.length (messages r));
  let _ = click (By_tag "button") r in
  Alcotest.(check (list msg_testable))
    "message after clear" [ Click ] (messages r)

let event_tests =
  [
    Alcotest.test_case "click_button" `Quick click_button;
    Alcotest.test_case "click_no_handler" `Quick click_no_handler;
    Alcotest.test_case "click_not_found" `Quick click_not_found;
    Alcotest.test_case "input_dispatches_on_change" `Quick
      input_dispatches_on_change;
    Alcotest.test_case "input_no_handler" `Quick input_no_handler;
    Alcotest.test_case "submit_dispatches_on_submit" `Quick
      submit_dispatches_on_submit;
    Alcotest.test_case "submit_no_handler" `Quick submit_no_handler;
    Alcotest.test_case "messages_accumulate" `Quick messages_accumulate;
    Alcotest.test_case "clear_messages_resets" `Quick clear_messages_resets;
  ]

(* Task 4: Map support tests *)

type outer_msg = Outer of msg

let outer_msg_testable =
  Alcotest.testable
    (fun fmt m ->
      match m with
      | Outer Click -> Format.fprintf fmt "Outer Click"
      | Outer (Changed s) -> Format.fprintf fmt "Outer (Changed %S)" s
      | Outer Submit -> Format.fprintf fmt "Outer Submit")
    ( = )

type wrapper = Wrapped of outer_msg

let wrapper_testable =
  Alcotest.testable
    (fun fmt m ->
      match m with
      | Wrapped (Outer Click) -> Format.fprintf fmt "Wrapped (Outer Click)"
      | Wrapped (Outer (Changed s)) ->
          Format.fprintf fmt "Wrapped (Outer (Changed %S))" s
      | Wrapped (Outer Submit) -> Format.fprintf fmt "Wrapped (Outer Submit)")
    ( = )

let render_mapped_click () =
  let mapped =
    E.map (fun m -> Outer m) (E.button ~on_click:Click (E.text "ok"))
  in
  let r = render mapped in
  let result = click (By_tag "button") r in
  Alcotest.(check (result unit error_testable)) "click succeeds" (Ok ()) result;
  Alcotest.(check (list outer_msg_testable))
    "mapped click message" [ Outer Click ] (messages r)

let render_mapped_input () =
  let mapped =
    E.map
      (fun m -> Outer m)
      (E.input ~on_change:(fun s -> Changed s) ~placeholder:"type" "")
  in
  let r = render mapped in
  let result = input (By_tag "input") "hello" r in
  Alcotest.(check (result unit error_testable)) "input succeeds" (Ok ()) result;
  Alcotest.(check (list outer_msg_testable))
    "mapped input message"
    [ Outer (Changed "hello") ]
    (messages r)

let render_mapped_nested () =
  let inner = E.button ~on_click:Click (E.text "deep") in
  let mid = E.map (fun m -> Outer m) inner in
  let outer = E.map (fun m -> Wrapped m) mid in
  let r = render outer in
  let result = click (By_tag "button") r in
  Alcotest.(check (result unit error_testable)) "click succeeds" (Ok ()) result;
  Alcotest.(check (list wrapper_testable))
    "double-mapped click message" [ Wrapped (Outer Click) ] (messages r)

let map_tests =
  [
    Alcotest.test_case "render_mapped_click" `Quick render_mapped_click;
    Alcotest.test_case "render_mapped_input" `Quick render_mapped_input;
    Alcotest.test_case "render_mapped_nested" `Quick render_mapped_nested;
  ]

(* Task 5: run_app MVU loop tests *)

type counter_msg = Increment | Decrement

let counter_init () = (0, Nopal_mvu.Cmd.none)

let counter_update model msg =
  match msg with
  | Increment -> (model + 1, Nopal_mvu.Cmd.none)
  | Decrement -> (model - 1, Nopal_mvu.Cmd.none)

let counter_view _vp model =
  E.box
    [
      E.text (string_of_int model);
      E.button ~on_click:Increment (E.text "+");
      E.button ~on_click:Decrement (E.text "-");
    ]

let run_app_init_only () =
  let model, r =
    run_app ~init:counter_init ~update:counter_update ~view:counter_view []
  in
  Alcotest.(check int) "initial model is 0" 0 model;
  let t = tree r in
  let count_text = find First_child t in
  Alcotest.(check string)
    "initial view shows 0" "0"
    (text_content (Option.get count_text))

let run_app_single_message () =
  let model, r =
    run_app ~init:counter_init ~update:counter_update ~view:counter_view
      [ Increment ]
  in
  Alcotest.(check int) "model is 1 after increment" 1 model;
  let t = tree r in
  let count_text = find First_child t in
  Alcotest.(check string)
    "view shows 1" "1"
    (text_content (Option.get count_text))

let run_app_multiple_messages () =
  let model, r =
    run_app ~init:counter_init ~update:counter_update ~view:counter_view
      [ Increment; Increment; Increment; Decrement ]
  in
  Alcotest.(check int) "model is 2 after 3 inc + 1 dec" 2 model;
  let t = tree r in
  let count_text = find First_child t in
  Alcotest.(check string)
    "view shows 2" "2"
    (text_content (Option.get count_text))

let run_app_ignores_commands () =
  let init () = (0, Nopal_mvu.Cmd.batch [ Nopal_mvu.Cmd.none ]) in
  let update model msg =
    match msg with
    | Increment -> (model + 1, Nopal_mvu.Cmd.batch [ Nopal_mvu.Cmd.none ])
    | Decrement -> (model - 1, Nopal_mvu.Cmd.none)
  in
  let model, r = run_app ~init ~update ~view:counter_view [ Increment ] in
  Alcotest.(check int) "commands ignored, model is 1" 1 model;
  let t = tree r in
  let count_text = find First_child t in
  Alcotest.(check string)
    "view shows 1" "1"
    (text_content (Option.get count_text))

let run_app_tests =
  [
    Alcotest.test_case "run_app_init_only" `Quick run_app_init_only;
    Alcotest.test_case "run_app_single_message" `Quick run_app_single_message;
    Alcotest.test_case "run_app_multiple_messages" `Quick
      run_app_multiple_messages;
    Alcotest.test_case "run_app_ignores_commands" `Quick
      run_app_ignores_commands;
  ]

(* Task 5: Text style in test renderer *)
module T = Nopal_style.Text
module F = Nopal_style.Font
module C = Nopal_style.Color

let text_node_has_no_text_style () =
  let r = render (E.text "hello") in
  match tree r with
  | Text { text_style; _ } ->
      Alcotest.(check bool)
        "plain text has no text_style" true
        (Option.is_none text_style)
  | _ -> Alcotest.fail "expected Text node"

let styled_text_node_has_text_style () =
  let ts = T.default |> T.font_size 16.0 |> T.font_weight F.Bold in
  let r = render (E.styled_text ~text_style:ts "styled") in
  match tree r with
  | Text { content; text_style } ->
      Alcotest.(check string) "content preserved" "styled" content;
      Alcotest.(check bool)
        "text_style is Some" true
        (Option.is_some text_style);
      let ts' = Option.get text_style in
      Alcotest.(check bool)
        "font_size matches" true
        (Option.equal Float.equal ts'.font_size (Some 16.0));
      Alcotest.(check bool)
        "font_weight matches" true
        (Option.equal F.equal_weight ts'.font_weight (Some F.Bold))
  | _ -> Alcotest.fail "expected Text node"

let text_style_accessor_returns_style () =
  let ts = T.default |> T.font_size 24.0 in
  let r = render (E.styled_text ~text_style:ts "big") in
  let result = text_style (tree r) in
  Alcotest.(check bool) "text_style returns Some" true (Option.is_some result);
  let ts' = Option.get result in
  Alcotest.(check bool)
    "font_size matches" true
    (Option.equal Float.equal ts'.font_size (Some 24.0))

let text_style_accessor_returns_none_for_plain () =
  let r = render (E.text "plain") in
  let result = text_style (tree r) in
  Alcotest.(check bool)
    "text_style returns None for plain" true (Option.is_none result)

let text_style_accessor_returns_none_for_element () =
  let r = render (E.box [ E.text "child" ]) in
  let result = text_style (tree r) in
  Alcotest.(check bool)
    "text_style returns None for element" true (Option.is_none result)

(* The colour is authored, rendered and read back through the public path, so
   this is the composition the two halves miss: the builder is pinned in the
   style package's own suite, the accessor by the cases above with a font size,
   and neither carries a colour across the renderer. *)
let text_style_carries_colour () =
  let c = C.rgba 12 34 56 0.5 in
  let ts = T.default |> T.color c in
  let r = render (E.styled_text ~text_style:ts "coloured") in
  let result = text_style (tree r) in
  Alcotest.(check bool) "text_style returns Some" true (Option.is_some result);
  let ts' = Option.get result in
  Alcotest.(check bool)
    "authored colour survives the round-trip" true
    (Option.equal C.equal ts'.color (Some c))

(* Same composition as the colour case above, for the whitespace pair: the style
   package's suite pins the builders and the accessor cases above pin the
   accessor with a font size, so nothing yet carries this field across the
   renderer. The fixture is the consumer's own spelling: preserved spaces on a
   line that must not wrap. Its leading run is a reader's hint and nothing here
   asserts on it, because text_content_element and text_content_still_works
   below already fail if the renderer touches the content. *)
let text_style_carries_whitespace () =
  let ts = T.default |> T.whitespace T.Preserve |> T.text_overflow T.No_wrap in
  let r = render (E.styled_text ~text_style:ts "    indented") in
  let result = text_style (tree r) in
  Alcotest.(check bool) "text_style returns Some" true (Option.is_some result);
  let ts' = Option.get result in
  Alcotest.(check bool)
    "authored whitespace survives the round-trip" true
    (Option.equal T.equal_whitespace ts'.whitespace (Some T.Preserve));
  Alcotest.(check bool)
    "the wrapping axis beside it survives too" true
    (Option.equal T.equal_text_overflow ts'.text_overflow (Some T.No_wrap))

let text_content_still_works () =
  let ts = T.default |> T.font_size 14.0 in
  let r =
    render (E.box [ E.text "plain"; E.styled_text ~text_style:ts " styled" ])
  in
  let s = text_content (tree r) in
  Alcotest.(check string) "text_content concatenates" "plain styled" s

type ts_msg = Ts_toggle

let styled_text_reconciliation_changes_style () =
  let init () = (false, Nopal_mvu.Cmd.none) in
  let update _model msg =
    match msg with
    | Ts_toggle -> (true, Nopal_mvu.Cmd.none)
  in
  let view _vp model =
    if model then
      E.styled_text
        ~text_style:(T.default |> T.font_size 24.0 |> T.font_weight F.Bold)
        "big"
    else E.styled_text ~text_style:(T.default |> T.font_size 12.0) "small"
  in
  (* Before toggle *)
  let model0, r0 = run_app ~init ~update ~view [] in
  Alcotest.(check bool) "initial model" false model0;
  let ts0 = text_style (tree r0) in
  Alcotest.(check bool) "initial has text_style" true (Option.is_some ts0);
  Alcotest.(check bool)
    "initial font_size is 12" true
    (Option.equal Float.equal (Option.get ts0).font_size (Some 12.0));
  Alcotest.(check bool)
    "initial no font_weight" true
    (Option.is_none (Option.get ts0).font_weight);
  (* After toggle *)
  let model1, r1 = run_app ~init ~update ~view [ Ts_toggle ] in
  Alcotest.(check bool) "toggled model" true model1;
  let ts1 = text_style (tree r1) in
  Alcotest.(check bool) "toggled has text_style" true (Option.is_some ts1);
  Alcotest.(check bool)
    "toggled font_size is 24" true
    (Option.equal Float.equal (Option.get ts1).font_size (Some 24.0));
  Alcotest.(check bool)
    "toggled font_weight is Bold" true
    (Option.equal F.equal_weight (Option.get ts1).font_weight (Some F.Bold))

let styled_text_reconciliation_removes_style () =
  let init () = (false, Nopal_mvu.Cmd.none) in
  let update _model msg =
    match msg with
    | Ts_toggle -> (true, Nopal_mvu.Cmd.none)
  in
  let view _vp model =
    if model then E.text "plain"
    else E.styled_text ~text_style:(T.default |> T.font_size 16.0) "styled"
  in
  let _model0, r0 = run_app ~init ~update ~view [] in
  Alcotest.(check bool)
    "initial has text_style" true
    (Option.is_some (text_style (tree r0)));
  let _model1, r1 = run_app ~init ~update ~view [ Ts_toggle ] in
  Alcotest.(check bool)
    "after toggle no text_style" true
    (Option.is_none (text_style (tree r1)))

let text_style_tests =
  [
    Alcotest.test_case "text_node_has_no_text_style" `Quick
      text_node_has_no_text_style;
    Alcotest.test_case "styled_text_node_has_text_style" `Quick
      styled_text_node_has_text_style;
    Alcotest.test_case "text_style_accessor_returns_style" `Quick
      text_style_accessor_returns_style;
    Alcotest.test_case "text_style_accessor_returns_none_for_plain" `Quick
      text_style_accessor_returns_none_for_plain;
    Alcotest.test_case "text_style_accessor_returns_none_for_element" `Quick
      text_style_accessor_returns_none_for_element;
    Alcotest.test_case "text_style_carries_colour" `Quick
      text_style_carries_colour;
    Alcotest.test_case "text_style_carries_whitespace" `Quick
      text_style_carries_whitespace;
    Alcotest.test_case "text_content_still_works" `Quick
      text_content_still_works;
    Alcotest.test_case "styled_text_reconciliation_changes_style" `Quick
      styled_text_reconciliation_changes_style;
    Alcotest.test_case "styled_text_reconciliation_removes_style" `Quick
      styled_text_reconciliation_removes_style;
  ]

(* Task 5: Virtual list handler path resolution (FR-5) *)

type vl_msg = Vl_click of int | Vl_change of int * string

let vl_msg_testable =
  Alcotest.testable
    (fun fmt m ->
      match m with
      | Vl_click i -> Format.fprintf fmt "Vl_click %d" i
      | Vl_change (i, s) -> Format.fprintf fmt "Vl_change (%d, %S)" i s)
    ( = )

let vl_option_get msg = function
  | Some x -> x
  | None -> failwith msg

let virtual_list_handler_at_nonzero_offset () =
  let module VL = Nopal_element.Virtual_list in
  let row_height =
    vl_option_get "row_height" (VL.Positive_float.of_float 10.0)
  in
  let container_height =
    vl_option_get "container_height" (VL.Positive_float.of_float 50.0)
  in
  let item_count = vl_option_get "item_count" (VL.Natural.of_int 100) in
  let overscan = vl_option_get "overscan" (VL.Natural.of_int 0) in
  (* offset 100 / row 10 => the visible window starts at item 10, not 0;
     this is the scroll condition under which absolute and positional item
     indices diverge (FR-5). *)
  let scroll_state = VL.scroll_state ~offset:100.0 in
  let render_item i =
    E.row
      [
        E.button
          ~attrs:[ ("data-btn", string_of_int i) ]
          ~on_click:(Vl_click i) (E.text "row");
        E.input
          ~attrs:[ ("data-inp", string_of_int i) ]
          ~on_change:(fun s -> Vl_change (i, s))
          ~placeholder:"" "";
      ]
  in
  let r =
    render
      (E.virtual_list ~item_count ~row_height ~container_height ~scroll_state
         ~overscan render_item)
  in
  (* item 12 is inside the visible window (10..14) but at positional slot 2 *)
  let click_result = click (By_attr ("data-btn", "12")) r in
  Alcotest.(check (result unit error_testable))
    "click reaches the scrolled item's handler" (Ok ()) click_result;
  let input_result = input (By_attr ("data-inp", "12")) "hi" r in
  Alcotest.(check (result unit error_testable))
    "input reaches the scrolled item's handler" (Ok ()) input_result;
  Alcotest.(check (list vl_msg_testable))
    "handlers dispatch for the correct scrolled item"
    [ Vl_click 12; Vl_change (12, "hi") ]
    (messages r)

let virtual_list_tests =
  [
    Alcotest.test_case "virtual_list_handler_at_nonzero_offset" `Quick
      virtual_list_handler_at_nonzero_offset;
  ]

(* File input selection simulation *)

type file_msg = Picked of E.file_info list

let pp_file_info fmt (fi : E.file_info) =
  Format.fprintf fmt "{blob_id=%S; name=%S; size=%d; mime=%S; last_modified=%f}"
    fi.blob_id fi.name fi.size fi.mime fi.last_modified

let file_info_equal (a : E.file_info) (b : E.file_info) =
  String.equal a.blob_id b.blob_id
  && String.equal a.name b.name
  && Int.equal a.size b.size
  && String.equal a.mime b.mime
  && Float.equal a.last_modified b.last_modified

let file_msg_testable =
  Alcotest.testable
    (fun fmt m ->
      match m with
      | Picked files ->
          Format.fprintf fmt "Picked [%a]"
            (Format.pp_print_list
               ~pp_sep:(fun fmt () -> Format.fprintf fmt "; ")
               pp_file_info)
            files)
    (fun a b ->
      match (a, b) with
      | Picked xs, Picked ys -> List.equal file_info_equal xs ys)

let receipt =
  E.file_info ~blob_id:"nopal-blob-1" ~name:"receipt.png" ~size:1024
    ~mime:"image/png" ~last_modified:1_700_000_000_000.0

let scan =
  E.file_info ~blob_id:"nopal-blob-2" ~name:"scan.pdf" ~size:2048
    ~mime:"application/pdf" ~last_modified:1_700_000_060_000.0

let picker_with_handler () =
  E.file_input
    ~attrs:[ ("data-field", "receipt") ]
    ~accept:[ "image/*" ] ~capture:E.Environment ~multiple:true
    ~on_change:(fun files -> Picked files)
    ()

let select_files_dispatches_provided_list () =
  let r = render (picker_with_handler ()) in
  let result =
    select_files (By_attr ("data-field", "receipt")) [ receipt; scan ] r
  in
  Alcotest.(check (result unit error_testable))
    "select_files succeeds" (Ok ()) result;
  Alcotest.(check (list file_msg_testable))
    "handler receives exactly the provided selection"
    [ Picked [ receipt; scan ] ]
    (messages r)

(* The empty-selection arm and its affirmative sibling share one rendered
   element, so the [[]] observation cannot pass because the fixture stopped
   reaching the handler at all. *)
let select_files_empty_list_dispatches_empty_list () =
  let r = render (picker_with_handler ()) in
  let picked = select_files (By_attr ("data-field", "receipt")) [ receipt ] r in
  Alcotest.(check (result unit error_testable))
    "selecting a file succeeds" (Ok ()) picked;
  let cleared = select_files (By_attr ("data-field", "receipt")) [] r in
  Alcotest.(check (result unit error_testable))
    "clearing the picker succeeds" (Ok ()) cleared;
  Alcotest.(check (list file_msg_testable))
    "clearing dispatches an empty list rather than nothing"
    [ Picked [ receipt ]; Picked [] ]
    (messages r)

let select_files_not_found () =
  let r = render (picker_with_handler ()) in
  let result = select_files (By_attr ("data-field", "avatar")) [ receipt ] r in
  Alcotest.(check (result unit error_testable))
    "select_files returns Not_found"
    (Error (Not_found (By_attr ("data-field", "avatar"))))
    result;
  Alcotest.(check int) "no messages" 0 (List.length (messages r))

let select_files_no_handler () =
  let r = render (E.file_input ~attrs:[ ("data-field", "receipt") ] ()) in
  let result = select_files (By_attr ("data-field", "receipt")) [ receipt ] r in
  Alcotest.(check (result unit error_testable))
    "select_files returns No_handler"
    (Error (No_handler { tag = "file_input"; event = "change" }))
    result;
  Alcotest.(check int) "no messages" 0 (List.length (messages r))

(* The picker renders under its own pseudo-tag, not [Input]'s: a file input and
   a text field are both <input> in the DOM, so sharing a tag here would make
   [By_tag "input"] resolve either one by document order. *)
let file_input_node_shape () =
  let r = render (picker_with_handler ()) in
  let node =
    match find (By_tag "file_input") (tree r) with
    | Some node -> node
    | None -> Alcotest.fail "file input node not found by its own tag"
  in
  Alcotest.(check (option string))
    "accept is the comma-joined form" (Some "image/*") (attr "accept" node);
  Alcotest.(check (option string))
    "capture carries the wire token" (Some "environment") (attr "capture" node);
  Alcotest.(check (option string))
    "multiple is surfaced" (Some "true") (attr "multiple" node);
  Alcotest.(check (option string))
    "caller attrs survive alongside the config" (Some "receipt")
    (attr "data-field" node);
  Alcotest.(check bool)
    "a text field does not answer to the file input's tag" true
    (Option.is_none (find (By_tag "input") (tree r)))

(* Every config field has an absent form, and each must reach the node as such
   rather than silently carrying the previous fixture's value. *)
let file_input_node_shape_unconfigured () =
  let r = render (E.file_input ~attrs:[ ("data-field", "receipt") ] ()) in
  let node =
    match find (By_tag "file_input") (tree r) with
    | Some node -> node
    | None -> Alcotest.fail "file input node not found by its own tag"
  in
  Alcotest.(check (option string))
    "an empty accept is the empty string" (Some "") (attr "accept" node);
  Alcotest.(check (option string))
    "an absent capture is the empty string" (Some "") (attr "capture" node);
  Alcotest.(check (option string))
    "multiple defaults to false" (Some "false") (attr "multiple" node)

let file_input_tests =
  [
    Alcotest.test_case "select_files_dispatches_provided_list" `Quick
      select_files_dispatches_provided_list;
    Alcotest.test_case "select_files_empty_list_dispatches_empty_list" `Quick
      select_files_empty_list_dispatches_empty_list;
    Alcotest.test_case "select_files_not_found" `Quick select_files_not_found;
    Alcotest.test_case "select_files_no_handler" `Quick select_files_no_handler;
    Alcotest.test_case "file_input_node_shape" `Quick file_input_node_shape;
    Alcotest.test_case "file_input_node_shape_unconfigured" `Quick
      file_input_node_shape_unconfigured;
  ]

(* Reveal request projection — a scroll container's declaration of which child
   must be brought into view is inspectable on its node. *)

let scroll_node_of label r =
  match find (By_tag "scroll") (tree r) with
  | Some (Element _ as node) -> node
  | Some (Empty | Text _)
  | None ->
      Alcotest.fail label

let scroll_reveal_attrs () =
  let r = render (E.scroll ~reveal:(R.center "row-7") (E.text "content")) in
  match find (By_attr ("reveal", "row-7")) (tree r) with
  | Some (Element { tag; _ } as node) ->
      Alcotest.(check string)
        "the node carrying the request is the container itself" "scroll" tag;
      Alcotest.(check (option string))
        "it names the child to bring into view" (Some "row-7")
        (attr "reveal" node);
      Alcotest.(check (option string))
        "and the alignment to bring it into view under" (Some "center")
        (attr "reveal-align" node)
  | Some (Empty | Text _)
  | None ->
      Alcotest.fail "no node is findable by the declared reveal key"

let scroll_no_reveal_attrs () =
  let child = E.text "content" in
  let without =
    scroll_node_of "no scroll node without a request" (render (E.scroll child))
  in
  let containing =
    scroll_node_of "no scroll node with a request"
      (render (E.scroll ~reveal:(R.start "row-3") child))
  in
  (match without with
  | Element { attrs; _ } ->
      Alcotest.(check (list (pair string string)))
        "a container with no request carries no attributes at all" [] attrs
  | Empty
  | Text _ ->
      Alcotest.fail "the scroll node is not an element");
  (* The affirmative arm, on the same child and the same builder: the emptiness
     above is caused by the absent request, not by the fixture failing to reach
     the container arm at all. *)
  Alcotest.(check (option string))
    "the same container with a request names the child" (Some "row-3")
    (attr "reveal" containing);
  Alcotest.(check (option string))
    "and its alignment" (Some "start")
    (attr "reveal-align" containing)

let scroll_reveal_hostile_key () =
  (* Written as a quoted literal so the bytes are legible: a double quote and a
     backslash, the two characters a query built by concatenation would let
     through. *)
  let key = {|a"b\c|} in
  let r = render (E.scroll ~reveal:(R.end_ key) (E.text "content")) in
  let node = scroll_node_of "no scroll node for a hostile key" r in
  (* Spelled with escapes rather than reusing [key], so the expectation is the
     bytes themselves and not the same literal compared with itself. Storing it
     escaped would be a defect here: escaping belongs at the point a backend
     builds a query, and a value escaped twice resolves to nothing. *)
  Alcotest.(check (option string))
    "the key reaches the attributes exactly as written" (Some "a\"b\\c")
    (attr "reveal" node);
  Alcotest.(check (option string))
    "its alignment travels with it" (Some "end") (attr "reveal-align" node);
  Alcotest.(check bool)
    "and the unescaped key finds the container back" true
    (Option.is_some (find (By_attr ("reveal", key)) (tree r)))

(* Application attributes on a scroll container: the identity a later relative
   scroll resolves against, and the reason the container no longer needs a
   wrapper box to be named. *)
let scroll_projects_its_attrs () =
  let child = E.text "content" in
  let node =
    scroll_node_of "no scroll node for a container carrying attributes"
      (render
         (E.scroll
            ~attrs:[ ("id", "reading-pane"); ("data-testid", "pane") ]
            child))
  in
  Alcotest.(check (option string))
    "the container is findable by the id the view wrote" (Some "reading-pane")
    (attr "id" node);
  Alcotest.(check (option string))
    "and every other attribute travels with it" (Some "pane")
    (attr "data-testid" node);
  Alcotest.(check bool)
    "the query the backend will use finds the container back" true
    (Option.is_some
       (find
          (By_attr ("id", "reading-pane"))
          (tree (render (E.scroll ~attrs:[ ("id", "reading-pane") ] child)))));
  (* Attributes and a reveal on one container, which is the pairing the
     ordering contract is written about: neither projection may displace the
     other, and the derived reveal keys are prepended so a view that supplies
     its own "reveal" key cannot shadow them. *)
  let both =
    scroll_node_of "no scroll node for a container declaring both"
      (render
         (E.scroll
            ~attrs:[ ("id", "reading-pane"); ("reveal", "decoy") ]
            ~reveal:(R.start "row-3") child))
  in
  Alcotest.(check (option string))
    "the declared reveal wins the name over a caller-supplied one"
    (Some "row-3") (attr "reveal" both);
  Alcotest.(check (option string))
    "its alignment travels with it" (Some "start") (attr "reveal-align" both);
  Alcotest.(check (option string))
    "and the application attribute is still readable" (Some "reading-pane")
    (attr "id" both)

let reveal_tests =
  [
    Alcotest.test_case "scroll_reveal_attrs" `Quick scroll_reveal_attrs;
    Alcotest.test_case "scroll_no_reveal_attrs" `Quick scroll_no_reveal_attrs;
    Alcotest.test_case "scroll_reveal_hostile_key" `Quick
      scroll_reveal_hostile_key;
    Alcotest.test_case "scroll_projects_its_attrs" `Quick
      scroll_projects_its_attrs;
  ]

let () =
  Alcotest.run "Test_renderer"
    [
      ("rendering", rendering_tests);
      ("querying", querying_tests);
      ("events", event_tests);
      ("map", map_tests);
      ("run_app", run_app_tests);
      ("text_style", text_style_tests);
      ("virtual_list", virtual_list_tests);
      ("file_input", file_input_tests);
      ("reveal", reveal_tests);
    ]

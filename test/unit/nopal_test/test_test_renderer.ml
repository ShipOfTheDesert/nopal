open Nopal_test.Test_renderer
module E = Nopal_element.Element
module Ix = Nopal_style.Interaction

let ix0 = Ix.default

let node_pp fmt node =
  let rec aux indent = function
    | Empty -> Format.fprintf fmt "%sEmpty" indent
    | Text { content; _ } -> Format.fprintf fmt "%sText %S" indent content
    | Element { tag; attrs; children; _ } ->
        Format.fprintf fmt "%sElement { tag = %S; attrs = [%s]; children = ["
          indent tag
          (String.concat "; "
             (List.map (fun (k, v) -> Printf.sprintf "(%S, %S)" k v) attrs));
        List.iter
          (fun c ->
            Format.fprintf fmt "\n";
            aux (indent ^ "  ") c)
          children;
        Format.fprintf fmt "] }"
  in
  aux "" node

let node_equal a b =
  let rec eq a b =
    match (a, b) with
    | Empty, Empty -> true
    | ( Text { content = s1; text_style = ts1 },
        Text { content = s2; text_style = ts2 } ) ->
        String.equal s1 s2 && Option.equal Nopal_style.Text.equal ts1 ts2
    | ( Element { tag = t1; attrs = a1; children = c1; _ },
        Element { tag = t2; attrs = a2; children = c2; _ } ) ->
        String.equal t1 t2 && a1 = a2 && List.equal eq c1 c2
    | _ -> false
  in
  eq a b

let node_testable = Alcotest.testable node_pp node_equal

let check_node msg expected actual =
  Alcotest.check node_testable msg expected actual

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
         attrs = [];
         children =
           [
             Element
               {
                 tag = "row";
                 attrs = [];
                 children =
                   [
                     Text { content = "a"; text_style = None };
                     Element
                       {
                         tag = "column";
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

let pp_selector fmt sel =
  match sel with
  | By_tag t -> Format.fprintf fmt "By_tag %S" t
  | By_text t -> Format.fprintf fmt "By_text %S" t
  | By_attr (k, v) -> Format.fprintf fmt "By_attr (%S, %S)" k v
  | First_child -> Format.fprintf fmt "First_child"
  | Nth_child n -> Format.fprintf fmt "Nth_child %d" n

let error_testable =
  Alcotest.testable
    (fun fmt e ->
      match e with
      | Not_found sel -> Format.fprintf fmt "Not_found (%a)" pp_selector sel
      | No_handler { tag; event } ->
          Format.fprintf fmt "No_handler { tag = %S; event = %S }" tag event)
    ( = )

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

let counter_view model =
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
  let view model =
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
    "initial font_size is 12"
    true
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
    "toggled font_size is 24"
    true
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
  let view model =
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
    Alcotest.test_case "text_content_still_works" `Quick
      text_content_still_works;
    Alcotest.test_case "styled_text_reconciliation_changes_style" `Quick
      styled_text_reconciliation_changes_style;
    Alcotest.test_case "styled_text_reconciliation_removes_style" `Quick
      styled_text_reconciliation_removes_style;
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
    ]

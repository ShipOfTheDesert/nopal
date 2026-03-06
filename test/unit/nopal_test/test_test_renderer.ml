open Nopal_test.Test_renderer
module E = Nopal_element.Element

let node_pp fmt node =
  let rec aux indent = function
    | Empty -> Format.fprintf fmt "%sEmpty" indent
    | Text s -> Format.fprintf fmt "%sText %S" indent s
    | Element { tag; attrs; children } ->
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
    | Text s1, Text s2 -> String.equal s1 s2
    | ( Element { tag = t1; attrs = a1; children = c1 },
        Element { tag = t2; attrs = a2; children = c2 } ) ->
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
  check_node "text renders to Text" (Text "hello") (tree r)

let render_box () =
  let r = render (E.box [ E.text "a"; E.text "b" ]) in
  check_node "box renders correctly"
    (Element { tag = "box"; attrs = []; children = [ Text "a"; Text "b" ] })
    (tree r)

let render_row () =
  let r = render (E.row [ E.text "a" ]) in
  check_node "row renders correctly"
    (Element { tag = "row"; attrs = []; children = [ Text "a" ] })
    (tree r)

let render_column () =
  let r = render (E.column [ E.text "a" ]) in
  check_node "column renders correctly"
    (Element { tag = "column"; attrs = []; children = [ Text "a" ] })
    (tree r)

let render_button () =
  let r = render (E.button (E.text "click me")) in
  check_node "button renders correctly"
    (Element { tag = "button"; attrs = []; children = [ Text "click me" ] })
    (tree r)

let render_input_attrs () =
  let r = render (E.input ~placeholder:"ph" "val") in
  check_node "input renders with attrs"
    (Element
       {
         tag = "input";
         attrs = [ ("value", "val"); ("placeholder", "ph") ];
         children = [];
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
       })
    (tree r)

let render_scroll () =
  let r = render (E.scroll (E.text "content")) in
  check_node "scroll renders correctly"
    (Element { tag = "scroll"; attrs = []; children = [ Text "content" ] })
    (tree r)

let render_keyed () =
  let r = render (E.keyed "k1" (E.text "child")) in
  check_node "keyed renders correctly"
    (Element
       { tag = "keyed"; attrs = [ ("key", "k1") ]; children = [ Text "child" ] })
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
                     Text "a";
                     Element
                       {
                         tag = "column";
                         attrs = [];
                         children = [ Text "b"; Text "c" ];
                       };
                   ];
               };
             Text "d";
           ];
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
  | Some (Text s) -> Alcotest.(check string) "text matches" "hello" s
  | _ -> Alcotest.fail "expected Text node"

let find_by_text_substring () =
  let r = render (E.box [ E.text "hello world" ]) in
  let result = find (By_text "world") (tree r) in
  Alcotest.(check bool) "finds text by substring" true (Option.is_some result);
  match result with
  | Some (Text s) -> Alcotest.(check string) "full text" "hello world" s
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
  check_node "first child is text a" (Text "a") (Option.get result)

let find_first_child_empty () =
  let result = find First_child Empty in
  Alcotest.(check bool) "Empty has no first child" true (Option.is_none result);
  let result2 = find First_child (Text "hi") in
  Alcotest.(check bool) "Text has no first child" true (Option.is_none result2)

let find_nth_child () =
  let r = render (E.box [ E.text "a"; E.text "b"; E.text "c" ]) in
  let result = find (Nth_child 1) (tree r) in
  check_node "nth child 1 is text b" (Text "b") (Option.get result)

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
  let s = text_content (Text "hello") in
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

let () =
  Alcotest.run "Test_renderer"
    [
      ("rendering", rendering_tests);
      ("querying", querying_tests);
      ("events", event_tests);
      ("map", map_tests);
      ("run_app", run_app_tests);
    ]

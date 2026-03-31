open Nopal_element

let pf = Virtual_list.Positive_float.of_float
let nat = Virtual_list.Natural.of_int

let option_get msg = function
  | Some x -> x
  | None -> failwith msg

let () =
  Alcotest.run "virtual_list_structural"
    [
      ( "Element.map",
        [
          Alcotest.test_case "on_scroll_callback_maps_with_element_map" `Quick
            (fun () ->
              let row_height = option_get "row_height" (pf 50.0) in
              let container_height = option_get "container_height" (pf 300.0) in
              let item_count = option_get "item_count" (nat 100) in
              let overscan = option_get "overscan" (nat 0) in
              let scroll_state = Virtual_list.scroll_state ~offset:0.0 in
              let on_scroll offset = `Scroll offset in
              let el =
                Element.virtual_list ~item_count ~row_height ~container_height
                  ~scroll_state ~overscan ~on_scroll (fun i ->
                    Element.text (string_of_int i))
              in
              let mapped =
                Element.map
                  (fun msg ->
                    match msg with
                    | `Scroll offset -> `Wrapped offset
                    | `Other -> `Wrapped 0.0)
                  el
              in
              match mapped with
              | Element.Virtual_list { on_scroll = Some f; _ } ->
                  let result = f 42.0 in
                  Alcotest.(check bool)
                    "mapped on_scroll produces wrapped message" true
                    (result = `Wrapped 42.0)
              | _ ->
                  Alcotest.fail "Expected Virtual_list with on_scroll after map");
        ] );
      ( "Element.map render_item",
        [
          Alcotest.test_case "render_item_maps_with_element_map" `Quick
            (fun () ->
              let row_height = option_get "row_height" (pf 50.0) in
              let container_height = option_get "container_height" (pf 200.0) in
              let item_count = option_get "item_count" (nat 10) in
              let overscan = option_get "overscan" (nat 0) in
              let scroll_state = Virtual_list.scroll_state ~offset:0.0 in
              let el =
                Element.virtual_list ~item_count ~row_height ~container_height
                  ~scroll_state ~overscan (fun i ->
                    Element.button ~on_click:(`Click i)
                      (Element.text (string_of_int i)))
              in
              let mapped =
                Element.map
                  (fun msg ->
                    match msg with
                    | `Click i -> `Wrapped i
                    | `Other -> `Wrapped (-1))
                  el
              in
              (* Render the mapped element and click the first button *)
              let rendered = Nopal_test.Test_renderer.render mapped in
              let tree = Nopal_test.Test_renderer.tree rendered in
              (match tree with
              | Nopal_test.Test_renderer.Element
                  { tag = "virtual_list"; children; _ } ->
                  (* 200px / 50px = 4 visible items, indices 0-3 *)
                  Alcotest.(check int)
                    "4 visible items" 4 (List.length children)
              | _ ->
                  Alcotest.fail
                    "Expected Virtual_list after map with render_item");
              (* Click the first button child; message should be mapped *)
              let result =
                Nopal_test.Test_renderer.click
                  (Nopal_test.Test_renderer.By_tag "button") rendered
              in
              (match result with
              | Ok () -> ()
              | Error (Nopal_test.Test_renderer.Not_found _) ->
                  Alcotest.fail "Button not found in virtual list"
              | Error (Nopal_test.Test_renderer.No_handler _) ->
                  Alcotest.fail "Button has no click handler");
              match Nopal_test.Test_renderer.messages rendered with
              | msg :: _ ->
                  Alcotest.(check bool)
                    "click produces Wrapped 0" true
                    (msg = `Wrapped 0)
              | [] -> Alcotest.fail "Expected a message after click");
        ] );
      ( "structural rendering",
        [
          Alcotest.test_case "renders_only_visible_items" `Quick (fun () ->
              let row_height = option_get "row_height" (pf 50.0) in
              let container_height = option_get "container_height" (pf 200.0) in
              let item_count = option_get "item_count" (nat 100) in
              let overscan = option_get "overscan" (nat 0) in
              let scroll_state = Virtual_list.scroll_state ~offset:0.0 in
              let el =
                Element.virtual_list ~item_count ~row_height ~container_height
                  ~scroll_state ~overscan (fun i ->
                    Element.text (string_of_int i))
              in
              let rendered = Nopal_test.Test_renderer.render el in
              let tree = Nopal_test.Test_renderer.tree rendered in
              match tree with
              | Nopal_test.Test_renderer.Element
                  { tag = "virtual_list"; children; _ } ->
                  Alcotest.(check int)
                    "4 visible items" 4 (List.length children)
              | _ -> Alcotest.fail "Expected virtual_list element");
          Alcotest.test_case "renders_visible_plus_overscan" `Quick (fun () ->
              let row_height = option_get "row_height" (pf 50.0) in
              let container_height = option_get "container_height" (pf 200.0) in
              let item_count = option_get "item_count" (nat 100) in
              let overscan = option_get "overscan" (nat 2) in
              let scroll_state = Virtual_list.scroll_state ~offset:100.0 in
              let el =
                Element.virtual_list ~item_count ~row_height ~container_height
                  ~scroll_state ~overscan (fun i ->
                    Element.text (string_of_int i))
              in
              let rendered = Nopal_test.Test_renderer.render el in
              let tree = Nopal_test.Test_renderer.tree rendered in
              match tree with
              | Nopal_test.Test_renderer.Element
                  { tag = "virtual_list"; children; _ } ->
                  (* offset 100 / 50 = first_visible 2, visible_count ceil(200/50) = 4
                     last_visible = 5, with overscan 2: first=0, last=7 → 8 items *)
                  Alcotest.(check int)
                    "visible + overscan items" 8 (List.length children)
              | _ -> Alcotest.fail "Expected virtual_list element");
          Alcotest.test_case "scroll_updates_visible_window" `Quick (fun () ->
              let row_height = option_get "row_height" (pf 50.0) in
              let container_height = option_get "container_height" (pf 200.0) in
              let item_count = option_get "item_count" (nat 100) in
              let overscan = option_get "overscan" (nat 0) in
              let scroll_state = Virtual_list.scroll_state ~offset:500.0 in
              let el =
                Element.virtual_list ~item_count ~row_height ~container_height
                  ~scroll_state ~overscan (fun i ->
                    Element.text (string_of_int i))
              in
              let rendered = Nopal_test.Test_renderer.render el in
              let tree = Nopal_test.Test_renderer.tree rendered in
              match tree with
              | Nopal_test.Test_renderer.Element
                  { tag = "virtual_list"; children; _ } -> (
                  (* offset 500 / 50 = first 10, visible 4, last 13 → 4 items *)
                  Alcotest.(check int)
                    "4 visible items at offset 500" 4 (List.length children);
                  (* First child should be item 10 *)
                  match children with
                  | first_child :: _ ->
                      let text =
                        Nopal_test.Test_renderer.text_content first_child
                      in
                      Alcotest.(check string) "first item is index 10" "10" text
                  | [] -> Alcotest.fail "Expected children")
              | _ -> Alcotest.fail "Expected virtual_list element");
          Alcotest.test_case "virtual_list_tag_and_attrs" `Quick (fun () ->
              let row_height = option_get "row_height" (pf 50.0) in
              let container_height = option_get "container_height" (pf 200.0) in
              let item_count = option_get "item_count" (nat 100) in
              let overscan = option_get "overscan" (nat 0) in
              let scroll_state = Virtual_list.scroll_state ~offset:0.0 in
              let el =
                Element.virtual_list ~item_count ~row_height ~container_height
                  ~scroll_state ~overscan (fun i ->
                    Element.text (string_of_int i))
              in
              let rendered = Nopal_test.Test_renderer.render el in
              let tree = Nopal_test.Test_renderer.tree rendered in
              match tree with
              | Nopal_test.Test_renderer.Element
                  { tag = "virtual_list"; attrs; _ } ->
                  let find_attr name =
                    match
                      List.find_opt (fun (k, _) -> String.equal k name) attrs
                    with
                    | Some (_, v) -> v
                    | None ->
                        Alcotest.fail (Printf.sprintf "Missing attr: %s" name)
                  in
                  Alcotest.(check string)
                    "item-count" "100" (find_attr "item-count");
                  Alcotest.(check string)
                    "row-height" "50" (find_attr "row-height");
                  Alcotest.(check string) "offset" "0" (find_attr "offset")
              | _ -> Alcotest.fail "Expected virtual_list element");
        ] );
    ]

open Nopal_element.Element
open Nopal_style.Style

type msg = Click | Change of string | Submit

let fresh_dispatch () =
  let msgs = ref [] in
  let dispatch msg = msgs := msg :: !msgs in
  (dispatch, msgs)

let fresh_parent () = Brr.El.v (Jstr.v "div") []
let node_type jv = Jv.Int.get jv "nodeType"

let tag_of jv =
  Jv.Jstr.get jv "nodeName" |> Jstr.to_string |> String.uppercase_ascii

(* 18 *)
let test_empty_creates_comment () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent Empty in
  let node = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check int) "comment nodeType" 8 (node_type node)

(* 19 *)
let test_text_creates_span () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent (Text "hello") in
  let node = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check int) "element nodeType" 1 (node_type node);
  Alcotest.(check string) "tag is SPAN" "SPAN" (tag_of node);
  let text = Jv.Jstr.get node "textContent" |> Jstr.to_string in
  Alcotest.(check string) "text content" "hello" text

(* 20 *)
let test_box_creates_div () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el = Box { style = default; attrs = []; children = [ Text "a" ] } in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el in
  let node = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check string) "tag is DIV" "DIV" (tag_of node);
  let style_obj = Jv.get node "style" in
  let display = Jv.Jstr.get style_obj "display" |> Jstr.to_string in
  Alcotest.(check string) "display flex" "flex" display

(* 21 *)
let test_row_creates_div_flex_row () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el = Row { style = default; attrs = []; children = [] } in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el in
  let node = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check string) "tag is DIV" "DIV" (tag_of node);
  let style_obj = Jv.get node "style" in
  let fd = Jv.Jstr.get style_obj "flex-direction" |> Jstr.to_string in
  Alcotest.(check string) "flex-direction row" "row" fd

(* 22 *)
let test_column_creates_div_flex_column () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el = Column { style = default; attrs = []; children = [] } in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el in
  let node = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check string) "tag is DIV" "DIV" (tag_of node);
  let style_obj = Jv.get node "style" in
  let fd = Jv.Jstr.get style_obj "flex-direction" |> Jstr.to_string in
  Alcotest.(check string) "flex-direction column" "column" fd

(* 23 *)
let test_button_creates_button () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el =
    Button
      {
        style = default;
        attrs = [];
        on_click = None;
        on_dblclick = None;
        child = Text "ok";
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el in
  let node = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check string) "tag is BUTTON" "BUTTON" (tag_of node)

(* 24 *)
let test_input_creates_input () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el =
    Input
      {
        style = default;
        attrs = [];
        value = "hi";
        placeholder = "type here";
        on_change = None;
        on_submit = None;
        on_blur = None;
        on_keydown = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el in
  let node = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check string) "tag is INPUT" "INPUT" (tag_of node);
  let value = Jv.Jstr.get node "value" |> Jstr.to_string in
  Alcotest.(check string) "value" "hi" value;
  let ph =
    Jv.call node "getAttribute" [| Jv.of_string "placeholder" |] |> Jv.to_string
  in
  Alcotest.(check string) "placeholder" "type here" ph

(* 25 *)
let test_image_creates_img () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el = Image { style = default; src = "pic.png"; alt = "A pic" } in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el in
  let node = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check string) "tag is IMG" "IMG" (tag_of node);
  let src =
    Jv.call node "getAttribute" [| Jv.of_string "src" |] |> Jv.to_string
  in
  Alcotest.(check string) "src" "pic.png" src;
  let alt =
    Jv.call node "getAttribute" [| Jv.of_string "alt" |] |> Jv.to_string
  in
  Alcotest.(check string) "alt" "A pic" alt

(* 26 *)
let test_scroll_creates_div_overflow_auto () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el = Scroll { style = default; child = Text "x" } in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el in
  let node = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check string) "tag is DIV" "DIV" (tag_of node);
  let style_obj = Jv.get node "style" in
  let ov = Jv.Jstr.get style_obj "overflow" |> Jstr.to_string in
  Alcotest.(check string) "overflow auto" "auto" ov

(* 27 *)
let test_keyed_sets_data_key () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el = Keyed { key = "k1"; child = Text "x" } in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el in
  let node = Nopal_web.Renderer.dom_node handle in
  let dk =
    Jv.call node "getAttribute" [| Jv.of_string "data-key" |] |> Jv.to_string
  in
  Alcotest.(check string) "data-key" "k1" dk

(* 28 *)
let test_button_click_dispatches () =
  let parent = fresh_parent () in
  let dispatch, msgs = fresh_dispatch () in
  let el =
    Button
      {
        style = default;
        attrs = [];
        on_click = Some Click;
        on_dblclick = None;
        child = Text "go";
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el in
  let node = Nopal_web.Renderer.dom_node handle in
  let ev = Jv.new' (Jv.get Jv.global "Event") [| Jv.of_string "click" |] in
  ignore (Jv.call node "dispatchEvent" [| ev |]);
  Alcotest.(check int) "one dispatch" 1 (List.length !msgs);
  match !msgs with
  | [ Click ] -> ()
  | _ -> Alcotest.fail "expected Click message"

(* 29 *)
let test_input_change_dispatches () =
  let parent = fresh_parent () in
  let dispatch, msgs = fresh_dispatch () in
  let el =
    Input
      {
        style = default;
        attrs = [];
        value = "";
        placeholder = "";
        on_change = Some (fun s -> Change s);
        on_submit = None;
        on_blur = None;
        on_keydown = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el in
  let node = Nopal_web.Renderer.dom_node handle in
  (* Set value on the node before dispatching input event *)
  Jv.set node "value" (Jv.of_string "typed");
  let ev = Jv.new' (Jv.get Jv.global "Event") [| Jv.of_string "input" |] in
  ignore (Jv.call node "dispatchEvent" [| ev |]);
  Alcotest.(check int) "one dispatch" 1 (List.length !msgs);
  match !msgs with
  | [ Change "typed" ] -> ()
  | _ -> Alcotest.fail "expected Change \"typed\" message"

(* 30 *)
let test_input_submit_dispatches_on_enter () =
  let parent = fresh_parent () in
  let dispatch, msgs = fresh_dispatch () in
  let el =
    Input
      {
        style = default;
        attrs = [];
        value = "";
        placeholder = "";
        on_change = None;
        on_submit = Some Submit;
        on_blur = None;
        on_keydown = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el in
  let node = Nopal_web.Renderer.dom_node handle in
  let ev =
    Jv.new'
      (Jv.get Jv.global "KeyboardEvent")
      [| Jv.of_string "keydown"; Jv.obj [| ("key", Jv.of_string "Enter") |] |]
  in
  ignore (Jv.call node "dispatchEvent" [| ev |]);
  Alcotest.(check int) "one dispatch" 1 (List.length !msgs);
  match !msgs with
  | [ Submit ] -> ()
  | _ -> Alcotest.fail "expected Submit message"

(* 31 *)
let test_input_submit_ignores_non_enter () =
  let parent = fresh_parent () in
  let dispatch, msgs = fresh_dispatch () in
  let el =
    Input
      {
        style = default;
        attrs = [];
        value = "";
        placeholder = "";
        on_change = None;
        on_submit = Some Submit;
        on_blur = None;
        on_keydown = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el in
  let node = Nopal_web.Renderer.dom_node handle in
  let ev =
    Jv.new'
      (Jv.get Jv.global "KeyboardEvent")
      [| Jv.of_string "keydown"; Jv.obj [| ("key", Jv.of_string "a") |] |]
  in
  ignore (Jv.call node "dispatchEvent" [| ev |]);
  Alcotest.(check int) "no dispatch" 0 (List.length !msgs)

(* 32 *)
let test_style_applied_as_inline () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let styled =
    with_paint
      (fun p -> { p with background = Some (rgba 255 0 0 1.0) })
      default
  in
  let el = Box { style = styled; attrs = []; children = [] } in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el in
  let node = Nopal_web.Renderer.dom_node handle in
  let style_obj = Jv.get node "style" in
  let bg = Jv.Jstr.get style_obj "background-color" |> Jstr.to_string in
  Alcotest.(check string) "background-color set" "rgba(255,0,0,1)" bg

(* 33 *)
let test_reconcile_text_update () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent (Text "a") in
  let node_before = Nopal_web.Renderer.dom_node handle in
  Nopal_web.Renderer.update ~dispatch handle (Text "b");
  let node_after = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check bool) "same node" true (node_before == node_after);
  let text = Jv.Jstr.get node_after "textContent" |> Jstr.to_string in
  Alcotest.(check string) "text updated" "b" text

(* 34 *)
let test_reconcile_same_variant_reuses_node () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 = Box { style = default; attrs = []; children = [ Text "a" ] } in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node_before = Nopal_web.Renderer.dom_node handle in
  let el2 = Box { style = default; attrs = []; children = [ Text "b" ] } in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let node_after = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check bool) "same div node" true (node_before == node_after)

(* 35 *)
let test_reconcile_different_variant_replaces () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent (Text "a") in
  let node_before = Nopal_web.Renderer.dom_node handle in
  let el2 =
    Button
      {
        style = default;
        attrs = [];
        on_click = None;
        on_dblclick = None;
        child = Text "b";
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let node_after = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check bool) "different node" false (node_before == node_after);
  Alcotest.(check string) "tag is BUTTON" "BUTTON" (tag_of node_after)

(* 36 *)
let test_reconcile_children_append () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 = Box { style = default; attrs = []; children = [ Text "a" ] } in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let count_before = Jv.Int.get (Jv.get node "childNodes") "length" in
  Alcotest.(check int) "one child" 1 count_before;
  let el2 =
    Box { style = default; attrs = []; children = [ Text "a"; Text "b" ] }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let count_after = Jv.Int.get (Jv.get node "childNodes") "length" in
  Alcotest.(check int) "two children" 2 count_after

(* 37 *)
let test_reconcile_children_remove () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Box { style = default; attrs = []; children = [ Text "a"; Text "b" ] }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let count_before = Jv.Int.get (Jv.get node "childNodes") "length" in
  Alcotest.(check int) "two children" 2 count_before;
  let el2 = Box { style = default; attrs = []; children = [ Text "a" ] } in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let count_after = Jv.Int.get (Jv.get node "childNodes") "length" in
  Alcotest.(check int) "one child" 1 count_after

(* 38 *)
let test_reconcile_children_reuse_by_position () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Box { style = default; attrs = []; children = [ Text "a"; Text "b" ] }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let children = Jv.get node "childNodes" in
  let child0_before = Jv.get children "0" in
  let child1_before = Jv.get children "1" in
  let el2 =
    Box { style = default; attrs = []; children = [ Text "c"; Text "d" ] }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let children_after = Jv.get node "childNodes" in
  let child0_after = Jv.get children_after "0" in
  let child1_after = Jv.get children_after "1" in
  Alcotest.(check bool) "child 0 same node" true (child0_before == child0_after);
  Alcotest.(check bool) "child 1 same node" true (child1_before == child1_after);
  let text0 = Jv.Jstr.get child0_after "textContent" |> Jstr.to_string in
  let text1 = Jv.Jstr.get child1_after "textContent" |> Jstr.to_string in
  Alcotest.(check string) "child 0 text" "c" text0;
  Alcotest.(check string) "child 1 text" "d" text1

(* 40 *)
let test_keyed_reorder_reuses_nodes () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Box
      {
        style = default;
        attrs = [];
        children =
          [
            Keyed { key = "a"; child = Text "A" };
            Keyed { key = "b"; child = Text "B" };
          ];
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let children_before = Jv.get node "childNodes" in
  let child_a = Jv.get children_before "0" in
  let child_b = Jv.get children_before "1" in
  (* Reverse order *)
  let el2 =
    Box
      {
        style = default;
        attrs = [];
        children =
          [
            Keyed { key = "b"; child = Text "B" };
            Keyed { key = "a"; child = Text "A" };
          ];
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let children_after = Jv.get node "childNodes" in
  let child_0 = Jv.get children_after "0" in
  let child_1 = Jv.get children_after "1" in
  (* "b" is now first, "a" is now second — same DOM nodes, just moved *)
  Alcotest.(check bool) "b node moved to 0" true (child_b == child_0);
  Alcotest.(check bool) "a node moved to 1" true (child_a == child_1)

(* 41 *)
let test_keyed_add_new_key () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Box
      {
        style = default;
        attrs = [];
        children = [ Keyed { key = "a"; child = Text "A" } ];
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let children_before = Jv.get node "childNodes" in
  let child_a = Jv.get children_before "0" in
  let el2 =
    Box
      {
        style = default;
        attrs = [];
        children =
          [
            Keyed { key = "a"; child = Text "A" };
            Keyed { key = "b"; child = Text "B" };
          ];
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let children_after = Jv.get node "childNodes" in
  let child_0 = Jv.get children_after "0" in
  Alcotest.(check bool) "a reused" true (child_a == child_0);
  let count = Jv.Int.get children_after "length" in
  Alcotest.(check int) "two children" 2 count;
  let text_1 =
    Jv.Jstr.get (Jv.get children_after "1") "textContent" |> Jstr.to_string
  in
  Alcotest.(check string) "b created" "B" text_1

(* 42 *)
let test_keyed_remove_key () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Box
      {
        style = default;
        attrs = [];
        children =
          [
            Keyed { key = "a"; child = Text "A" };
            Keyed { key = "b"; child = Text "B" };
          ];
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let children_before = Jv.get node "childNodes" in
  let child_b = Jv.get children_before "1" in
  let el2 =
    Box
      {
        style = default;
        attrs = [];
        children = [ Keyed { key = "a"; child = Text "A" } ];
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let children_after = Jv.get node "childNodes" in
  let count = Jv.Int.get children_after "length" in
  Alcotest.(check int) "one child" 1 count;
  (* Verify removed node is no longer in parent *)
  let parent_of_b = Jv.get child_b "parentNode" in
  Alcotest.(check bool) "b removed from parent" true (Jv.is_null parent_of_b)

(* 43 *)
let test_keyed_stable_node_identity () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Box
      {
        style = default;
        attrs = [];
        children =
          [
            Keyed
              {
                key = "x";
                child =
                  Input
                    {
                      style = default;
                      attrs = [];
                      value = "v";
                      placeholder = "";
                      on_change = None;
                      on_submit = None;
                      on_blur = None;
                      on_keydown = None;
                    };
              };
            Keyed { key = "y"; child = Text "Y" };
          ];
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let children_before = Jv.get node "childNodes" in
  let input_node = Jv.get children_before "0" in
  (* Update: add a new sibling before "x", keep "x" and drop "y" *)
  let el2 =
    Box
      {
        style = default;
        attrs = [];
        children =
          [
            Keyed { key = "z"; child = Text "Z" };
            Keyed
              {
                key = "x";
                child =
                  Input
                    {
                      style = default;
                      attrs = [];
                      value = "v2";
                      placeholder = "";
                      on_change = None;
                      on_submit = None;
                      on_blur = None;
                      on_keydown = None;
                    };
              };
          ];
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let children_after = Jv.get node "childNodes" in
  let input_after = Jv.get children_after "1" in
  Alcotest.(check bool) "input node preserved" true (input_node == input_after)

(* Spy utility: wraps setAttribute on a DOM node and counts calls *)
let spy_set_attr node =
  let count = ref 0 in
  let original_fn = Jv.get node "setAttribute" in
  let spy =
    Jv.callback ~arity:2 (fun name value ->
        incr count;
        ignore (Jv.apply original_fn [| name; value |]);
        Jv.undefined)
  in
  Jv.set node "setAttribute" spy;
  count

(* test_reconcile_image_attributes *)
let test_reconcile_image_attributes () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 = Image { style = default; src = "a.png"; alt = "old" } in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let el2 = Image { style = default; src = "b.png"; alt = "new" } in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let node_after = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check bool) "same node" true (node == node_after);
  let src =
    Jv.call node_after "getAttribute" [| Jv.of_string "src" |] |> Jv.to_string
  in
  let alt =
    Jv.call node_after "getAttribute" [| Jv.of_string "alt" |] |> Jv.to_string
  in
  Alcotest.(check string) "src updated" "b.png" src;
  Alcotest.(check string) "alt updated" "new" alt

(* Image: unchanged src/alt must not trigger setAttribute *)
let test_reconcile_image_skips_unchanged_src () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 = Image { style = default; src = "same.png"; alt = "same" } in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let count = spy_set_attr node in
  let el2 = Image { style = default; src = "same.png"; alt = "same" } in
  Nopal_web.Renderer.update ~dispatch handle el2;
  Alcotest.(check int) "setAttribute not called for unchanged image" 0 !count

(* Image: changed src triggers setAttribute for src only *)
let test_reconcile_image_updates_only_changed_attr () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 = Image { style = default; src = "a.png"; alt = "same" } in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let count = spy_set_attr node in
  let el2 = Image { style = default; src = "b.png"; alt = "same" } in
  Nopal_web.Renderer.update ~dispatch handle el2;
  Alcotest.(check int) "setAttribute called once (src only)" 1 !count;
  let src =
    Jv.call node "getAttribute" [| Jv.of_string "src" |] |> Jv.to_string
  in
  Alcotest.(check string) "src updated" "b.png" src

(* Box: unchanged attrs must not trigger setAttribute *)
let test_reconcile_box_skips_unchanged_attrs () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Box { style = default; attrs = [ ("data-id", "x") ]; children = [] }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let count = spy_set_attr node in
  let el2 =
    Box { style = default; attrs = [ ("data-id", "x") ]; children = [] }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  Alcotest.(check int) "setAttribute not called for unchanged attrs" 0 !count

(* Box: changed attrs triggers setAttribute *)
let test_reconcile_box_updates_changed_attrs () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Box { style = default; attrs = [ ("data-id", "x") ]; children = [] }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let count = spy_set_attr node in
  let el2 =
    Box { style = default; attrs = [ ("data-id", "y") ]; children = [] }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  Alcotest.(check int) "setAttribute called once for changed attr" 1 !count;
  let v =
    Jv.call node "getAttribute" [| Jv.of_string "data-id" |] |> Jv.to_string
  in
  Alcotest.(check string) "attr updated" "y" v

(* Box: removed attrs must be cleared from the DOM *)
let test_reconcile_box_removes_stale_attrs () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Box
      {
        style = default;
        attrs = [ ("data-id", "x"); ("data-extra", "y") ];
        children = [];
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  (* Verify initial attrs are set *)
  let v =
    Jv.call node "getAttribute" [| Jv.of_string "data-extra" |] |> Jv.to_string
  in
  Alcotest.(check string) "data-extra initially set" "y" v;
  (* Update: remove data-extra, keep data-id *)
  let el2 =
    Box { style = default; attrs = [ ("data-id", "x") ]; children = [] }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let removed =
    Jv.call node "getAttribute" [| Jv.of_string "data-extra" |] |> Jv.is_null
  in
  Alcotest.(check bool) "data-extra removed from DOM" true removed

(* Button: unchanged attrs must not trigger setAttribute *)
let test_reconcile_button_skips_unchanged_attrs () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Button
      {
        style = default;
        attrs = [ ("data-id", "x") ];
        on_click = Some Click;
        on_dblclick = None;
        child = Text "a";
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let count = spy_set_attr node in
  let el2 =
    Button
      {
        style = default;
        attrs = [ ("data-id", "x") ];
        on_click = Some Click;
        on_dblclick = None;
        child = Text "a";
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  Alcotest.(check int) "setAttribute not called for unchanged attrs" 0 !count

(* Input: unchanged placeholder must not trigger setAttribute *)
let test_reconcile_input_skips_unchanged_placeholder () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Input
      {
        style = default;
        attrs = [];
        value = "";
        placeholder = "type here";
        on_change = None;
        on_submit = None;
        on_blur = None;
        on_keydown = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let count = spy_set_attr node in
  let el2 =
    Input
      {
        style = default;
        attrs = [];
        value = "typed";
        placeholder = "type here";
        on_change = None;
        on_submit = None;
        on_blur = None;
        on_keydown = None;
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  Alcotest.(check int)
    "setAttribute not called for unchanged placeholder" 0 !count

(* Input: changed placeholder triggers setAttribute *)
let test_reconcile_input_updates_changed_placeholder () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Input
      {
        style = default;
        attrs = [];
        value = "";
        placeholder = "old";
        on_change = None;
        on_submit = None;
        on_blur = None;
        on_keydown = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let count = spy_set_attr node in
  let el2 =
    Input
      {
        style = default;
        attrs = [];
        value = "";
        placeholder = "new";
        on_change = None;
        on_submit = None;
        on_blur = None;
        on_keydown = None;
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  Alcotest.(check int)
    "setAttribute called once for changed placeholder" 1 !count;
  let ph =
    Jv.call node "getAttribute" [| Jv.of_string "placeholder" |] |> Jv.to_string
  in
  Alcotest.(check string) "placeholder updated" "new" ph

(* Input: unchanged attrs must not trigger setAttribute *)
let test_reconcile_input_skips_unchanged_attrs () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Input
      {
        style = default;
        attrs = [ ("data-id", "x") ];
        value = "";
        placeholder = "";
        on_change = None;
        on_submit = None;
        on_blur = None;
        on_keydown = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let count = spy_set_attr node in
  let el2 =
    Input
      {
        style = default;
        attrs = [ ("data-id", "x") ];
        value = "typed";
        placeholder = "";
        on_change = None;
        on_submit = None;
        on_blur = None;
        on_keydown = None;
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  Alcotest.(check int) "setAttribute not called for unchanged attrs" 0 !count

(* 39 *)
let test_reconcile_event_listener_update () =
  let parent = fresh_parent () in
  let dispatch, msgs = fresh_dispatch () in
  let el1 =
    Button
      {
        style = default;
        attrs = [];
        on_click = Some Click;
        on_dblclick = None;
        child = Text "a";
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let el2 =
    Button
      {
        style = default;
        attrs = [];
        on_click = Some Submit;
        on_dblclick = None;
        child = Text "a";
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let node = Nopal_web.Renderer.dom_node handle in
  let ev = Jv.new' (Jv.get Jv.global "Event") [| Jv.of_string "click" |] in
  ignore (Jv.call node "dispatchEvent" [| ev |]);
  Alcotest.(check int) "one dispatch" 1 (List.length !msgs);
  match !msgs with
  | [ Submit ] -> ()
  | _ -> Alcotest.fail "expected Submit message (not old Click)"

(* C1: schedule_after dispatches delayed messages *)
module Delayed_app = struct
  type model = { triggered : bool; delayed : bool }
  type msg = Trigger | Delayed

  let init () = ({ triggered = false; delayed = false }, Nopal_mvu.Cmd.none)

  let update model msg =
    match msg with
    | Trigger ->
        ({ model with triggered = true }, Nopal_mvu.Cmd.after 10 Delayed)
    | Delayed -> ({ model with delayed = true }, Nopal_mvu.Cmd.none)

  let view _model = Nopal_element.Element.Empty
  let subscriptions _model = Nopal_mvu.Sub.none
end

let test_schedule_after_dispatches () =
  let module R = Nopal_runtime.Runtime.Make (Delayed_app) in
  let rt = R.create ~schedule_after:(fun _ms f -> f ()) () in
  R.start rt;
  R.dispatch rt Delayed_app.Trigger;
  let m = R.model rt in
  Alcotest.(check bool) "triggered" true m.triggered;
  Alcotest.(check bool) "delayed message dispatched" true m.delayed

(* C2: removing a parent with nested listeners unlistens children *)
let test_recursive_unlisten_on_remove () =
  let parent = fresh_parent () in
  let dispatch, msgs = fresh_dispatch () in
  let el1 =
    Box
      {
        style = default;
        attrs = [];
        children =
          [
            Button
              {
                style = default;
                attrs = [];
                on_click = Some Click;
                on_dblclick = None;
                child = Text "inner";
              };
          ];
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let inner_button = Jv.get (Jv.get node "childNodes") "0" in
  (* Replace the entire Box with a Text — this removes the Box and its Button child *)
  Nopal_web.Renderer.update ~dispatch handle (Text "replaced");
  (* The old inner button's listener should have been cleaned up.
     Dispatching a click on the orphaned button should not produce a message. *)
  let ev = Jv.new' (Jv.get Jv.global "Event") [| Jv.of_string "click" |] in
  ignore (Jv.call inner_button "dispatchEvent" [| ev |]);
  Alcotest.(check int) "no dispatch from orphaned button" 0 (List.length !msgs)

(* C3: Keyed wrapping an Empty produces a comment node with no data-key *)
let test_keyed_empty_has_no_data_key () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el = Keyed { key = "ghost"; child = Empty } in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el in
  let node = Nopal_web.Renderer.dom_node handle in
  (* Comment nodes (nodeType 8) don't support setAttribute, so data-key
     is silently skipped. This is expected — keyed Empty is a valid but
     degenerate case. The comment still occupies a DOM position for
     positional stability but won't participate in keyed reconciliation
     since it has no data-key attribute. *)
  Alcotest.(check int) "comment nodeType" 8 (node_type node)

let () =
  Alcotest.run "nopal_web"
    [
      ( "element creation",
        [
          Alcotest.test_case "empty creates comment" `Quick
            test_empty_creates_comment;
          Alcotest.test_case "text creates span" `Quick test_text_creates_span;
          Alcotest.test_case "box creates div" `Quick test_box_creates_div;
          Alcotest.test_case "row creates div flex row" `Quick
            test_row_creates_div_flex_row;
          Alcotest.test_case "column creates div flex column" `Quick
            test_column_creates_div_flex_column;
          Alcotest.test_case "button creates button" `Quick
            test_button_creates_button;
          Alcotest.test_case "input creates input" `Quick
            test_input_creates_input;
          Alcotest.test_case "image creates img" `Quick test_image_creates_img;
          Alcotest.test_case "scroll creates div overflow auto" `Quick
            test_scroll_creates_div_overflow_auto;
          Alcotest.test_case "keyed sets data-key" `Quick
            test_keyed_sets_data_key;
        ] );
      ( "event wiring",
        [
          Alcotest.test_case "button click dispatches" `Quick
            test_button_click_dispatches;
          Alcotest.test_case "input change dispatches" `Quick
            test_input_change_dispatches;
          Alcotest.test_case "input submit dispatches on enter" `Quick
            test_input_submit_dispatches_on_enter;
          Alcotest.test_case "input submit ignores non-enter" `Quick
            test_input_submit_ignores_non_enter;
        ] );
      ( "style application",
        [
          Alcotest.test_case "style applied as inline" `Quick
            test_style_applied_as_inline;
        ] );
      ( "reconciliation",
        [
          Alcotest.test_case "reconcile text update" `Quick
            test_reconcile_text_update;
          Alcotest.test_case "reconcile same variant reuses node" `Quick
            test_reconcile_same_variant_reuses_node;
          Alcotest.test_case "reconcile different variant replaces" `Quick
            test_reconcile_different_variant_replaces;
          Alcotest.test_case "reconcile children append" `Quick
            test_reconcile_children_append;
          Alcotest.test_case "reconcile children remove" `Quick
            test_reconcile_children_remove;
          Alcotest.test_case "reconcile children reuse by position" `Quick
            test_reconcile_children_reuse_by_position;
          Alcotest.test_case "reconcile event listener update" `Quick
            test_reconcile_event_listener_update;
          Alcotest.test_case "reconcile image attributes" `Quick
            test_reconcile_image_attributes;
          Alcotest.test_case "reconcile image skips unchanged src/alt" `Quick
            test_reconcile_image_skips_unchanged_src;
          Alcotest.test_case "reconcile image updates only changed attr" `Quick
            test_reconcile_image_updates_only_changed_attr;
          Alcotest.test_case "reconcile box skips unchanged attrs" `Quick
            test_reconcile_box_skips_unchanged_attrs;
          Alcotest.test_case "reconcile box updates changed attrs" `Quick
            test_reconcile_box_updates_changed_attrs;
          Alcotest.test_case "reconcile box removes stale attrs" `Quick
            test_reconcile_box_removes_stale_attrs;
          Alcotest.test_case "reconcile button skips unchanged attrs" `Quick
            test_reconcile_button_skips_unchanged_attrs;
          Alcotest.test_case "reconcile input skips unchanged placeholder"
            `Quick test_reconcile_input_skips_unchanged_placeholder;
          Alcotest.test_case "reconcile input updates changed placeholder"
            `Quick test_reconcile_input_updates_changed_placeholder;
          Alcotest.test_case "reconcile input skips unchanged attrs" `Quick
            test_reconcile_input_skips_unchanged_attrs;
        ] );
      ( "keyed reconciliation",
        [
          Alcotest.test_case "keyed reorder reuses nodes" `Quick
            test_keyed_reorder_reuses_nodes;
          Alcotest.test_case "keyed add new key" `Quick test_keyed_add_new_key;
          Alcotest.test_case "keyed remove key" `Quick test_keyed_remove_key;
          Alcotest.test_case "keyed stable node identity" `Quick
            test_keyed_stable_node_identity;
        ] );
      ( "schedule_after",
        [
          Alcotest.test_case "schedule_after dispatches delayed msg" `Quick
            test_schedule_after_dispatches;
        ] );
      ( "recursive unlisten",
        [
          Alcotest.test_case "removing parent unlistens nested children" `Quick
            test_recursive_unlisten_on_remove;
        ] );
      ( "keyed edge cases",
        [
          Alcotest.test_case "keyed empty has no data-key" `Quick
            test_keyed_empty_has_no_data_key;
        ] );
    ]

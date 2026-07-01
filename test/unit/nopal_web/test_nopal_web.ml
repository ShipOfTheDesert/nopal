open Nopal_element.Element
open Nopal_style.Style

type msg = Click | Change of string | Submit | Toggled of bool | Selected

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
  let handle =
    Nopal_web.Renderer.create ~dispatch ~parent
      (Text { content = "hello"; text_style = None })
  in
  let node = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check int) "element nodeType" 1 (node_type node);
  Alcotest.(check string) "tag is SPAN" "SPAN" (tag_of node);
  let text = Jv.Jstr.get node "textContent" |> Jstr.to_string in
  Alcotest.(check string) "text content" "hello" text

(* 20 *)
let test_box_creates_div () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el =
    Box
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children = [ Text { content = "a"; text_style = None } ];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
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
  let el =
    Row
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children = [];
      }
  in
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
  let el =
    Column
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children = [];
      }
  in
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
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        on_click = None;
        on_dblclick = None;
        child = Text { content = "ok"; text_style = None };
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
        interaction = Nopal_style.Interaction.default;
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
  let el =
    Scroll
      { style = default; child = Text { content = "x"; text_style = None } }
  in
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
  let el =
    Keyed { key = "k1"; child = Text { content = "x"; text_style = None } }
  in
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
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        on_click = Some Click;
        on_dblclick = None;
        child = Text { content = "go"; text_style = None };
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
        interaction = Nopal_style.Interaction.default;
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
        interaction = Nopal_style.Interaction.default;
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
        interaction = Nopal_style.Interaction.default;
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
  let el =
    Box
      {
        style = styled;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children = [];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el in
  let node = Nopal_web.Renderer.dom_node handle in
  let style_obj = Jv.get node "style" in
  let bg = Jv.Jstr.get style_obj "background-color" |> Jstr.to_string in
  Alcotest.(check string) "background-color set" "rgba(255,0,0,1)" bg

(* 33 *)
let test_reconcile_text_update () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let handle =
    Nopal_web.Renderer.create ~dispatch ~parent
      (Text { content = "a"; text_style = None })
  in
  let node_before = Nopal_web.Renderer.dom_node handle in
  Nopal_web.Renderer.update ~dispatch handle
    (Text { content = "b"; text_style = None });
  let node_after = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check bool) "same node" true (node_before == node_after);
  let text = Jv.Jstr.get node_after "textContent" |> Jstr.to_string in
  Alcotest.(check string) "text updated" "b" text

(* 34 *)
let test_reconcile_same_variant_reuses_node () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Box
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children = [ Text { content = "a"; text_style = None } ];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node_before = Nopal_web.Renderer.dom_node handle in
  let el2 =
    Box
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children = [ Text { content = "b"; text_style = None } ];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let node_after = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check bool) "same div node" true (node_before == node_after)

(* 35 *)
let test_reconcile_different_variant_replaces () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let handle =
    Nopal_web.Renderer.create ~dispatch ~parent
      (Text { content = "a"; text_style = None })
  in
  let node_before = Nopal_web.Renderer.dom_node handle in
  let el2 =
    Button
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        on_click = None;
        on_dblclick = None;
        child = Text { content = "b"; text_style = None };
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
  let el1 =
    Box
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children = [ Text { content = "a"; text_style = None } ];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let count_before = Jv.Int.get (Jv.get node "childNodes") "length" in
  Alcotest.(check int) "one child" 1 count_before;
  let el2 =
    Box
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children =
          [
            Text { content = "a"; text_style = None };
            Text { content = "b"; text_style = None };
          ];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let count_after = Jv.Int.get (Jv.get node "childNodes") "length" in
  Alcotest.(check int) "two children" 2 count_after

(* 37 *)
let test_reconcile_children_remove () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Box
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children =
          [
            Text { content = "a"; text_style = None };
            Text { content = "b"; text_style = None };
          ];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let count_before = Jv.Int.get (Jv.get node "childNodes") "length" in
  Alcotest.(check int) "two children" 2 count_before;
  let el2 =
    Box
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children = [ Text { content = "a"; text_style = None } ];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let count_after = Jv.Int.get (Jv.get node "childNodes") "length" in
  Alcotest.(check int) "one child" 1 count_after

(* 38 *)
let test_reconcile_children_reuse_by_position () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Box
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children =
          [
            Text { content = "a"; text_style = None };
            Text { content = "b"; text_style = None };
          ];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let children = Jv.get node "childNodes" in
  let child0_before = Jv.get children "0" in
  let child1_before = Jv.get children "1" in
  let el2 =
    Box
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children =
          [
            Text { content = "c"; text_style = None };
            Text { content = "d"; text_style = None };
          ];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
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
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children =
          [
            Keyed
              { key = "a"; child = Text { content = "A"; text_style = None } };
            Keyed
              { key = "b"; child = Text { content = "B"; text_style = None } };
          ];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
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
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children =
          [
            Keyed
              { key = "b"; child = Text { content = "B"; text_style = None } };
            Keyed
              { key = "a"; child = Text { content = "A"; text_style = None } };
          ];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
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
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children =
          [
            Keyed
              { key = "a"; child = Text { content = "A"; text_style = None } };
          ];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
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
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children =
          [
            Keyed
              { key = "a"; child = Text { content = "A"; text_style = None } };
            Keyed
              { key = "b"; child = Text { content = "B"; text_style = None } };
          ];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
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
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children =
          [
            Keyed
              { key = "a"; child = Text { content = "A"; text_style = None } };
            Keyed
              { key = "b"; child = Text { content = "B"; text_style = None } };
          ];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
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
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children =
          [
            Keyed
              { key = "a"; child = Text { content = "A"; text_style = None } };
          ];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
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
        interaction = Nopal_style.Interaction.default;
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
                      interaction = Nopal_style.Interaction.default;
                      attrs = [];
                      value = "v";
                      placeholder = "";
                      on_change = None;
                      on_submit = None;
                      on_blur = None;
                      on_keydown = None;
                    };
              };
            Keyed
              { key = "y"; child = Text { content = "Y"; text_style = None } };
          ];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
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
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children =
          [
            Keyed
              { key = "z"; child = Text { content = "Z"; text_style = None } };
            Keyed
              {
                key = "x";
                child =
                  Input
                    {
                      style = default;
                      interaction = Nopal_style.Interaction.default;
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
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let children_after = Jv.get node "childNodes" in
  let input_after = Jv.get children_after "1" in
  Alcotest.(check bool) "input node preserved" true (input_node == input_after)

(* Builds a Box whose children are keyed Text nodes, one per key, in order. *)
let keyed_text_box keys =
  Box
    {
      style = default;
      interaction = Nopal_style.Interaction.default;
      attrs = [];
      children =
        List.map
          (fun k ->
            Keyed
              {
                key = k;
                child =
                  Text { content = String.uppercase_ascii k; text_style = None };
              })
          keys;
      on_pointer_move = None;
      on_pointer_leave = None;
      on_pointer_down = None;
      on_pointer_up = None;
      on_wheel = None;
    }

(* Spy utility: wraps appendChild and insertBefore on a DOM node, sharing one
   counter, so a test can assert how many DOM moves a reconcile performed. *)
let spy_dom_moves node =
  let count = ref 0 in
  let append_orig = Jv.get node "appendChild" in
  let append_spy =
    Jv.callback ~arity:1 (fun child ->
        incr count;
        Jv.apply append_orig [| child |])
  in
  Jv.set node "appendChild" append_spy;
  let insert_orig = Jv.get node "insertBefore" in
  let insert_spy =
    Jv.callback ~arity:2 (fun child ref_node ->
        incr count;
        Jv.apply insert_orig [| child; ref_node |])
  in
  Jv.set node "insertBefore" insert_spy;
  count

let test_keyed_reorder_moves_only_displaced () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let handle =
    Nopal_web.Renderer.create ~dispatch ~parent
      (keyed_text_box [ "a"; "b"; "c" ])
  in
  let node = Nopal_web.Renderer.dom_node handle in
  let children0 = Jv.get node "childNodes" in
  let n_a = Jv.get children0 "0" in
  let n_b = Jv.get children0 "1" in
  let n_c = Jv.get children0 "2" in
  (* Key-stable update with unchanged order must perform no DOM moves, so a
     focused/scrolled row survives an unrelated model update (FR-3, NFR-3). *)
  let moves = spy_dom_moves node in
  Nopal_web.Renderer.update ~dispatch handle (keyed_text_box [ "a"; "b"; "c" ]);
  Alcotest.(check int) "no DOM moves on key-stable update" 0 !moves;
  let children1 = Jv.get node "childNodes" in
  Alcotest.(check bool) "a preserved at 0" true (n_a == Jv.get children1 "0");
  Alcotest.(check bool) "b preserved at 1" true (n_b == Jv.get children1 "1");
  Alcotest.(check bool) "c preserved at 2" true (n_c == Jv.get children1 "2");
  (* Reorder to c,a,b reuses the same nodes in the new order. *)
  Nopal_web.Renderer.update ~dispatch handle (keyed_text_box [ "c"; "a"; "b" ]);
  let children2 = Jv.get node "childNodes" in
  Alcotest.(check bool) "c now at 0" true (n_c == Jv.get children2 "0");
  Alcotest.(check bool) "a now at 1" true (n_a == Jv.get children2 "1");
  Alcotest.(check bool) "b now at 2" true (n_b == Jv.get children2 "2")

let test_keyed_reorder_full_permutation () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let handle =
    Nopal_web.Renderer.create ~dispatch ~parent
      (keyed_text_box [ "a"; "b"; "c" ])
  in
  let node = Nopal_web.Renderer.dom_node handle in
  let children0 = Jv.get node "childNodes" in
  let n_a = Jv.get children0 "0" in
  let n_b = Jv.get children0 "1" in
  let n_c = Jv.get children0 "2" in
  let expected_node = function
    | "a" -> n_a
    | "b" -> n_b
    | "c" -> n_c
    | k -> Alcotest.failf "unknown key %s" k
  in
  (* Step the same three nodes through every position permutation, asserting
     the fully-enumerated key order and node identity at each index each
     step — no membership checks (multi-axis ordering convention). *)
  let permutations =
    [
      [ "a"; "b"; "c" ];
      [ "a"; "c"; "b" ];
      [ "b"; "a"; "c" ];
      [ "b"; "c"; "a" ];
      [ "c"; "a"; "b" ];
      [ "c"; "b"; "a" ];
    ]
  in
  List.iter
    (fun perm ->
      Nopal_web.Renderer.update ~dispatch handle (keyed_text_box perm);
      let children = Jv.get node "childNodes" in
      Alcotest.(check int) "three children" 3 (Jv.Int.get children "length");
      List.iteri
        (fun i key ->
          let child = Jv.get children (string_of_int i) in
          let dk =
            Jv.call child "getAttribute" [| Jv.of_string "data-key" |]
            |> Jv.to_string
          in
          Alcotest.(check string) (Printf.sprintf "key at %d" i) key dk;
          Alcotest.(check bool)
            (Printf.sprintf "node identity at %d" i)
            true
            (expected_node key == child))
        perm)
    permutations

(* FR-3, NFR-3: a real reorder must move only the displaced node, not re-insert
   the whole list. The permutation test above pins order and node identity, but
   a naive re-append-everything implementation preserves both too — so it would
   pass while silently doing N moves and blurring every focused row. This test
   pins the *move count*: swapping the first two of three keyed rows is one
   adjacent transposition, which the right-to-left insert-when-out-of-place pass
   performs in exactly one [insertBefore]; a re-insert-all pass would report
   three. *)
let test_keyed_reorder_minimal_move_count () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let handle =
    Nopal_web.Renderer.create ~dispatch ~parent
      (keyed_text_box [ "a"; "b"; "c" ])
  in
  let node = Nopal_web.Renderer.dom_node handle in
  let children0 = Jv.get node "childNodes" in
  let n_a = Jv.get children0 "0" in
  let n_b = Jv.get children0 "1" in
  let n_c = Jv.get children0 "2" in
  let moves = spy_dom_moves node in
  Nopal_web.Renderer.update ~dispatch handle (keyed_text_box [ "b"; "a"; "c" ]);
  Alcotest.(check int) "exactly one move for an adjacent swap" 1 !moves;
  let children1 = Jv.get node "childNodes" in
  Alcotest.(check bool) "b now at 0" true (n_b == Jv.get children1 "0");
  Alcotest.(check bool) "a now at 1" true (n_a == Jv.get children1 "1");
  Alcotest.(check bool) "c still at 2" true (n_c == Jv.get children1 "2")

(* FR-1: switching a parent's children from non-keyed to all-keyed must remove
   every old child not carried forward by key from the DOM and release its
   listeners — today the orphaned non-keyed node lingers forever. *)
let test_keyed_into_keyed_removes_old_nonkeyed () =
  let parent = fresh_parent () in
  let dispatch, msgs = fresh_dispatch () in
  let el1 =
    Box
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children =
          [
            Button
              {
                style = default;
                interaction = Nopal_style.Interaction.default;
                attrs = [];
                on_click = Some Click;
                on_dblclick = None;
                child = Text { content = "old"; text_style = None };
              };
          ];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let old_button = Jv.get (Jv.get node "childNodes") "0" in
  (* Transition to an all-keyed child list that does not carry the old child. *)
  let el2 =
    Box
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children =
          [
            Keyed
              {
                key = "k1";
                child = Text { content = "new"; text_style = None };
              };
          ];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let children_after = Jv.get node "childNodes" in
  Alcotest.(check int)
    "only the new keyed child remains" 1
    (Jv.Int.get children_after "length");
  let new_key =
    Jv.call
      (Jv.get children_after "0")
      "getAttribute"
      [| Jv.of_string "data-key" |]
    |> Jv.to_string
  in
  Alcotest.(check string) "remaining child is the new keyed node" "k1" new_key;
  let parent_of_old = Jv.get old_button "parentNode" in
  Alcotest.(check bool)
    "old non-keyed child removed from DOM" true (Jv.is_null parent_of_old);
  (* Listener cleanup: clicking the removed button must produce no message. *)
  let ev = Jv.new' (Jv.get Jv.global "Event") [| Jv.of_string "click" |] in
  ignore (Jv.call old_button "dispatchEvent" [| ev |]);
  Alcotest.(check int) "removed child's listener released" 0 (List.length !msgs)

(* Parent Box holding exactly one keyed child, so a test can flip that child's
   root variant under a stable key. *)
let keyed_one key child =
  Box
    {
      style = default;
      interaction = Nopal_style.Interaction.default;
      attrs = [];
      children = [ Keyed { key; child } ];
      on_pointer_move = None;
      on_pointer_leave = None;
      on_pointer_down = None;
      on_pointer_up = None;
      on_wheel = None;
    }

let inner_box =
  Box
    {
      style = default;
      interaction = Nopal_style.Interaction.default;
      attrs = [];
      children = [];
      on_pointer_move = None;
      on_pointer_leave = None;
      on_pointer_down = None;
      on_pointer_up = None;
      on_wheel = None;
    }

let inner_text = Text { content = "t"; text_style = None }

(* FR-2: when a keyed child's root variant changes (Box->Text) its DOM node is
   replaced; the replacement must remain identifiable by the same key so the
   next reconcile reuses it instead of destroying-and-recreating (or
   duplicating) it. *)
let test_keyed_variant_change_no_duplicate () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let handle =
    Nopal_web.Renderer.create ~dispatch ~parent (keyed_one "k" inner_box)
  in
  let node = Nopal_web.Renderer.dom_node handle in
  (* Box -> Text forces the replaceChild path in reconcile_live. *)
  Nopal_web.Renderer.update ~dispatch handle (keyed_one "k" inner_text);
  let children1 = Jv.get node "childNodes" in
  Alcotest.(check int)
    "one child after variant change" 1
    (Jv.Int.get children1 "length");
  let n1 = Jv.get children1 "0" in
  (* Reconcile the same key/variant again: without the key-carry the replaced
     node has no recoverable key, so it is destroyed and recreated (a different
     DOM node) instead of reused. *)
  Nopal_web.Renderer.update ~dispatch handle (keyed_one "k" inner_text);
  let children2 = Jv.get node "childNodes" in
  Alcotest.(check int)
    "still one child after re-reconcile" 1
    (Jv.Int.get children2 "length");
  let n2 = Jv.get children2 "0" in
  Alcotest.(check bool) "replaced keyed node reused by key" true (n1 == n2);
  let dk =
    Jv.call n2 "getAttribute" [| Jv.of_string "data-key" |] |> Jv.to_string
  in
  Alcotest.(check string) "data-key intact after replacement" "k" dk

(* FR-4: a keyed child that renders to a comment node (Empty) must be matched
   and reused across reconciles by its key, like any other keyed child. A
   comment node can't carry a data-key attribute, so its key round-trips via a
   JS expando property; repeated reconciles of the identical tree must reuse
   the same comment node rather than removing it and creating a fresh orphan
   each frame. *)
let test_keyed_empty_no_leak () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let handle =
    Nopal_web.Renderer.create ~dispatch ~parent (keyed_one "k" Empty)
  in
  let node = Nopal_web.Renderer.dom_node handle in
  let children0 = Jv.get node "childNodes" in
  Alcotest.(check int)
    "one comment child after create" 1
    (Jv.Int.get children0 "length");
  let c0 = Jv.get children0 "0" in
  Alcotest.(check int) "child is a comment node" 8 (node_type c0);
  (* Reconcile the identical tree three times. Without key recovery for the
     comment node the keyed Empty is not carried forward: it is removed and a
     fresh comment is created — a different DOM node every frame. With the
     expando key it is matched and the same comment node is reused. *)
  let reconcile_and_check label =
    Nopal_web.Renderer.update ~dispatch handle (keyed_one "k" Empty);
    let children = Jv.get node "childNodes" in
    Alcotest.(check int)
      (label ^ ": still one child")
      1
      (Jv.Int.get children "length");
    let c = Jv.get children "0" in
    Alcotest.(check bool) (label ^ ": same comment node reused") true (c0 == c)
  in
  reconcile_and_check "reconcile 1";
  reconcile_and_check "reconcile 2";
  reconcile_and_check "reconcile 3"

(* FR-2/FR-4: a variant change that crosses the comment-node boundary under a
   stable key must re-key the replacement through *both* representations —
   data-key on the element side, the [comment_key_prop] expando on the comment
   side. [test_keyed_variant_change_no_duplicate] only exercises Box->Text
   (element->element, [set_data_key]'s Live_node/Live_text arms); this pins the
   Empty<->Box crossing so the Live_comment arm of [set_data_key] (renderer.ml
   ~835) is covered. Each replacement must carry its key forward so the next
   reconcile reuses the very same node instead of destroying-and-recreating it. *)
let test_keyed_variant_change_empty_box_carries_key () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  (* Start as a keyed Empty (comment node). *)
  let handle =
    Nopal_web.Renderer.create ~dispatch ~parent (keyed_one "k" Empty)
  in
  let node = Nopal_web.Renderer.dom_node handle in
  (* Empty -> Box: the comment is replaced by an element; the replacement is
     re-keyed via the data-key attribute (set_data_key Live_node arm). *)
  Nopal_web.Renderer.update ~dispatch handle (keyed_one "k" inner_box);
  let children1 = Jv.get node "childNodes" in
  Alcotest.(check int)
    "one child after Empty->Box" 1
    (Jv.Int.get children1 "length");
  let box1 = Jv.get children1 "0" in
  let dk =
    Jv.call box1 "getAttribute" [| Jv.of_string "data-key" |] |> Jv.to_string
  in
  Alcotest.(check string) "box carries key after Empty->Box" "k" dk;
  (* Re-reconcile identical: the replaced box is reused by key, not recreated. *)
  Nopal_web.Renderer.update ~dispatch handle (keyed_one "k" inner_box);
  let box2 = Jv.get (Jv.get node "childNodes") "0" in
  Alcotest.(check bool) "box reused by key after Empty->Box" true (box1 == box2);
  (* Box -> Empty: the element is replaced by a comment; the replacement is
     re-keyed via the comment expando (set_data_key Live_comment arm — the path
     test_keyed_variant_change_no_duplicate never reaches). *)
  Nopal_web.Renderer.update ~dispatch handle (keyed_one "k" Empty);
  let children3 = Jv.get node "childNodes" in
  Alcotest.(check int)
    "one child after Box->Empty" 1
    (Jv.Int.get children3 "length");
  let comment1 = Jv.get children3 "0" in
  Alcotest.(check int) "child is a comment node" 8 (node_type comment1);
  (* Re-reconcile identical: the replaced comment is reused via the expando key,
     not destroyed and recreated each frame. *)
  Nopal_web.Renderer.update ~dispatch handle (keyed_one "k" Empty);
  let comment2 = Jv.get (Jv.get node "childNodes") "0" in
  Alcotest.(check bool)
    "comment reused by key after Box->Empty" true (comment1 == comment2)

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

(* FR-2 guard / NFR-3: the key-carry write in reconcile_keyed_children is guarded
   so it fires only when a node was replaced. A reused, same-variant keyed node
   keeps its existing key, so the order-unchanged hot path must skip the
   set_data_key write entirely — no redundant setAttribute. Spying setAttribute
   on a reused node and asserting zero calls pins the skip branch directly;
   dropping the guard (unconditional set_data_key) would make this one. *)
let test_keyed_reused_node_skips_data_key_write () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let handle =
    Nopal_web.Renderer.create ~dispatch ~parent
      (keyed_text_box [ "a"; "b"; "c" ])
  in
  let node = Nopal_web.Renderer.dom_node handle in
  let n_b = Jv.get (Jv.get node "childNodes") "1" in
  let writes = spy_set_attr n_b in
  Nopal_web.Renderer.update ~dispatch handle (keyed_text_box [ "a"; "b"; "c" ]);
  Alcotest.(check int) "no data-key rewrite on a reused keyed node" 0 !writes

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
    Box
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [ ("data-id", "x") ];
        children = [];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let count = spy_set_attr node in
  let el2 =
    Box
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [ ("data-id", "x") ];
        children = [];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  Alcotest.(check int) "setAttribute not called for unchanged attrs" 0 !count

(* Box: changed attrs triggers setAttribute *)
let test_reconcile_box_updates_changed_attrs () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Box
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [ ("data-id", "x") ];
        children = [];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let count = spy_set_attr node in
  let el2 =
    Box
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [ ("data-id", "y") ];
        children = [];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
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
        interaction = Nopal_style.Interaction.default;
        attrs = [ ("data-id", "x"); ("data-extra", "y") ];
        children = [];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
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
    Box
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [ ("data-id", "x") ];
        children = [];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
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
        interaction = Nopal_style.Interaction.default;
        attrs = [ ("data-id", "x") ];
        on_click = Some Click;
        on_dblclick = None;
        child = Text { content = "a"; text_style = None };
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let count = spy_set_attr node in
  let el2 =
    Button
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [ ("data-id", "x") ];
        on_click = Some Click;
        on_dblclick = None;
        child = Text { content = "a"; text_style = None };
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
        interaction = Nopal_style.Interaction.default;
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
        interaction = Nopal_style.Interaction.default;
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
        interaction = Nopal_style.Interaction.default;
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
        interaction = Nopal_style.Interaction.default;
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

(* NFR-3: a controlled input reflects the model, but reconciling with an
   unchanged value must NOT re-write the DOM `value`. A redundant write
   collapses the caret/selection and resets IME composition; combined with the
   global keydown subscription (a reconcile per keystroke), an unconditional
   write heals the DOM back to the model mid-edit and clobbers in-progress
   typing. Dropping the guard makes this assertion fail. *)
let test_reconcile_input_skips_unchanged_value () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let mk v =
    Input
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        value = v;
        placeholder = "";
        on_change = None;
        on_submit = None;
        on_blur = None;
        on_keydown = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent (mk "v") in
  let node = Nopal_web.Renderer.dom_node handle in
  let before = Jv.get node "_valueWrites" |> Jv.to_int in
  Nopal_web.Renderer.update ~dispatch handle (mk "v");
  let after = Jv.get node "_valueWrites" |> Jv.to_int in
  Alcotest.(check int) "no value write on unchanged reconcile" 0 (after - before)

(* The guard must not over-skip: a changed value still writes through once and
   the DOM reflects the new model value. *)
let test_reconcile_input_updates_changed_value () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let mk v =
    Input
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        value = v;
        placeholder = "";
        on_change = None;
        on_submit = None;
        on_blur = None;
        on_keydown = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent (mk "v") in
  let node = Nopal_web.Renderer.dom_node handle in
  let before = Jv.get node "_valueWrites" |> Jv.to_int in
  Nopal_web.Renderer.update ~dispatch handle (mk "v2");
  let after = Jv.get node "_valueWrites" |> Jv.to_int in
  Alcotest.(check int) "one value write on changed reconcile" 1 (after - before);
  let value = Jv.Jstr.get node "value" |> Jstr.to_string in
  Alcotest.(check string) "value updated" "v2" value

(* FR-1: a style prop present last render but absent now must be cleared from
   the element so the painted result matches the model. Image is non-interactive,
   so it exercises the inline-style reconcile path directly. *)
let test_reconcile_removes_dropped_inline_style () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let mk style = Image { style; src = "a.png"; alt = "a" } in
  let styled =
    with_paint
      (fun p -> { p with background = Some (rgba 255 0 0 1.0) })
      default
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent (mk styled) in
  let node = Nopal_web.Renderer.dom_node handle in
  let style_obj = Jv.get node "style" in
  let bg_before = Jv.Jstr.get style_obj "background-color" |> Jstr.to_string in
  Alcotest.(check bool)
    "background applied before" true
    (String.length bg_before > 0);
  Nopal_web.Renderer.update ~dispatch handle (mk default);
  let bg_after = Jv.Jstr.get style_obj "background-color" |> Jstr.to_string in
  Alcotest.(check string) "dropped background removed" "" bg_after

(* NFR-1: an identical re-render performs zero inline-style writes. The style is
   reconstructed each frame (physically distinct, structurally equal), as a real
   view function would, so this fails unless the guard uses structural equality. *)
let test_reconcile_unchanged_style_no_write () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let mk () =
    let styled =
      with_paint
        (fun p -> { p with background = Some (rgba 255 0 0 1.0) })
        default
    in
    Image { style = styled; src = "a.png"; alt = "a" }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent (mk ()) in
  let node = Nopal_web.Renderer.dom_node handle in
  let style_obj = Jv.get node "style" in
  let before = Jv.get style_obj "_writes" |> Jv.to_int in
  Nopal_web.Renderer.update ~dispatch handle (mk ());
  let after = Jv.get style_obj "_writes" |> Jv.to_int in
  Alcotest.(check int)
    "no inline-style write on unchanged reconcile" 0 (after - before)

(* Input: unchanged attrs must not trigger setAttribute *)
let test_reconcile_input_skips_unchanged_attrs () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Input
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
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
        interaction = Nopal_style.Interaction.default;
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
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        on_click = Some Click;
        on_dblclick = None;
        child = Text { content = "a"; text_style = None };
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let el2 =
    Button
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        on_click = Some Submit;
        on_dblclick = None;
        child = Text { content = "a"; text_style = None };
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

  let view _vp _model = Nopal_element.Element.Empty
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
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children =
          [
            Button
              {
                style = default;
                interaction = Nopal_style.Interaction.default;
                attrs = [];
                on_click = Some Click;
                on_dblclick = None;
                child = Text { content = "inner"; text_style = None };
              };
          ];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let inner_button = Jv.get (Jv.get node "childNodes") "0" in
  (* Replace the entire Box with a Text — this removes the Box and its Button child *)
  Nopal_web.Renderer.update ~dispatch handle
    (Text { content = "replaced"; text_style = None });
  (* The old inner button's listener should have been cleaned up.
     Dispatching a click on the orphaned button should not produce a message. *)
  let ev = Jv.new' (Jv.get Jv.global "Event") [| Jv.of_string "click" |] in
  ignore (Jv.call inner_button "dispatchEvent" [| ev |]);
  Alcotest.(check int) "no dispatch from orphaned button" 0 (List.length !msgs)

let has_class node class_name =
  let cl = Jv.get node "classList" in
  Jv.to_bool (Jv.call cl "contains" [| Jv.of_string class_name |])

let class_count node =
  let cl = Jv.get node "classList" in
  let s = Jv.to_string (Jv.call cl "toString" [||]) in
  match String.trim s with
  | "" -> 0
  | s -> List.length (String.split_on_char ' ' s)

let hover_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_paint (fun p ->
      { p with background = Some (Nopal_style.Style.rgba 91 160 233 1.0) })

let hover_interaction =
  { Nopal_style.Interaction.default with hover = Some hover_style }

let pressed_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_paint (fun p ->
      { p with background = Some (Nopal_style.Style.rgba 42 106 184 1.0) })

let hover_pressed_interaction =
  {
    Nopal_style.Interaction.default with
    hover = Some hover_style;
    pressed = Some pressed_style;
  }

(* I-2a: reconciling from no interaction to hover adds class *)
let test_reconcile_interaction_inject_on_change () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Box
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children = [];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check int) "no classes initially" 0 (class_count node);
  let el2 =
    Box
      {
        style = default;
        interaction = hover_interaction;
        attrs = [];
        children = [];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  Alcotest.(check int) "one class after inject" 1 (class_count node);
  Alcotest.(check bool)
    "has _nopal_ix_ class" true
    (has_class node "_nopal_ix_0")

(* I-2b: reconciling from hover interaction to no interaction removes class *)
let test_reconcile_interaction_remove_on_change () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Box
      {
        style = default;
        interaction = hover_interaction;
        attrs = [];
        children = [];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check int) "one class initially" 1 (class_count node);
  let el2 =
    Box
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children = [];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  Alcotest.(check int) "no classes after remove" 0 (class_count node)

(* I-2c: reconciling to a different interaction replaces class *)
let test_reconcile_interaction_replace_on_change () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Box
      {
        style = default;
        interaction = hover_interaction;
        attrs = [];
        children = [];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check bool) "has first class" true (has_class node "_nopal_ix_0");
  let el2 =
    Box
      {
        style = default;
        interaction = hover_pressed_interaction;
        attrs = [];
        children = [];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  Alcotest.(check int) "still one class" 1 (class_count node);
  Alcotest.(check bool) "old class removed" false (has_class node "_nopal_ix_0");
  Alcotest.(check bool) "new class added" true (has_class node "_nopal_ix_1")

(* I-2d: unchanged interaction skips injection *)
let test_reconcile_interaction_skips_unchanged () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Box
      {
        style = default;
        interaction = hover_interaction;
        attrs = [];
        children = [];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check bool) "has class" true (has_class node "_nopal_ix_0");
  let el2 =
    Box
      {
        style = default;
        interaction = hover_interaction;
        attrs = [];
        children = [];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  (* Same class retained, no new class injected *)
  Alcotest.(check int) "still one class" 1 (class_count node);
  Alcotest.(check bool) "same class kept" true (has_class node "_nopal_ix_0")

(* The single <style data-nopal> element the renderer's Style_sheet appends to
   document.head on create; the most recently created one belongs to the handle
   under test. Used to read the CSSOM mutation counters the stylesheet_shim
   records (FR-2/NFR-1). *)
let current_nopal_sheet () =
  let head = Jv.get (Jv.get Jv.global "document") "head" in
  let children = Jv.get head "childNodes" in
  let len = Jv.to_int (Jv.get children "length") in
  let result = ref Jv.null in
  for i = 0 to len - 1 do
    let child = Jv.get children (string_of_int i) in
    if
      String.equal (Jv.to_string (Jv.get child "nodeName")) "STYLE"
      && Jv.to_bool
           (Jv.call child "hasAttribute" [| Jv.of_string "data-nopal" |])
    then result := Jv.get child "sheet"
  done;
  !result

let sheet_inserts sheet = Jv.to_int (Jv.get sheet "_inserts")
let sheet_deletes sheet = Jv.to_int (Jv.get sheet "_deletes")

let classlist_writes node =
  Jv.to_int (Jv.get (Jv.get node "classList") "_writes")

(* A real view rebuilds its style/interaction every frame, so these thunks
   return physically-distinct but structurally-equal values — the case
   structural equality must catch but physical (==) does not. *)
let mk_base_style () =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_paint (fun p ->
      { p with background = Some (Nopal_style.Style.rgba 255 0 0 1.0) })

let mk_hover_interaction color =
  {
    Nopal_style.Interaction.default with
    hover =
      Some
        (Nopal_style.Style.default
        |> Nopal_style.Style.with_paint (fun p ->
            { p with background = Some color }));
  }

let interactive_box ~style ~interaction =
  Box
    {
      style;
      interaction;
      attrs = [];
      children = [];
      on_pointer_move = None;
      on_pointer_leave = None;
      on_pointer_down = None;
      on_pointer_up = None;
      on_wheel = None;
    }

(* FR-2/NFR-1: re-rendering an interactive element whose base style and
   interaction are unchanged (rebuilt fresh, as a view does) must not mutate the
   stylesheet or the classList. The base-class diff used physical equality, so a
   fresh-but-equal style churned the base rule every frame; this pins zero CSSOM
   and zero classList work on the unchanged path. *)
let test_reconcile_interaction_unchanged_no_cssom () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let blue = Nopal_style.Style.rgba 91 160 233 1.0 in
  let handle =
    Nopal_web.Renderer.create ~dispatch ~parent
      (interactive_box ~style:(mk_base_style ())
         ~interaction:(mk_hover_interaction blue))
  in
  let node = Nopal_web.Renderer.dom_node handle in
  let sheet = current_nopal_sheet () in
  let inserts_before = sheet_inserts sheet in
  let deletes_before = sheet_deletes sheet in
  let classes_before = classlist_writes node in
  Nopal_web.Renderer.update ~dispatch handle
    (interactive_box ~style:(mk_base_style ())
       ~interaction:(mk_hover_interaction blue));
  Alcotest.(check int)
    "no rule inserted on unchanged interactive reconcile" 0
    (sheet_inserts sheet - inserts_before);
  Alcotest.(check int)
    "no rule deleted on unchanged interactive reconcile" 0
    (sheet_deletes sheet - deletes_before);
  Alcotest.(check int)
    "no class assignment on unchanged interactive reconcile" 0
    (classlist_writes node - classes_before)

(* FR-2: a changed interaction must release the rules it replaces. Changing only
   the interaction (base style structurally equal) must delete exactly one rule
   (the superseded interaction) and insert exactly one (its replacement) — not
   two, which would mean the unchanged base rule was needlessly churned (NFR-1). *)
let test_reconcile_interaction_change_releases_prior () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let blue = Nopal_style.Style.rgba 91 160 233 1.0 in
  let green = Nopal_style.Style.rgba 42 184 106 1.0 in
  let handle =
    Nopal_web.Renderer.create ~dispatch ~parent
      (interactive_box ~style:(mk_base_style ())
         ~interaction:(mk_hover_interaction blue))
  in
  let sheet = current_nopal_sheet () in
  let inserts_before = sheet_inserts sheet in
  let deletes_before = sheet_deletes sheet in
  Nopal_web.Renderer.update ~dispatch handle
    (interactive_box ~style:(mk_base_style ())
       ~interaction:(mk_hover_interaction green));
  Alcotest.(check int)
    "exactly one rule deleted (prior interaction released, base untouched)" 1
    (sheet_deletes sheet - deletes_before);
  Alcotest.(check int)
    "exactly one rule inserted (replacement interaction)" 1
    (sheet_inserts sheet - inserts_before)

(* C3: Keyed wrapping an Empty produces a comment node with no data-key *)
let test_keyed_empty_has_no_data_key () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el = Keyed { key = "ghost"; child = Empty } in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el in
  let node = Nopal_web.Renderer.dom_node handle in
  (* Comment nodes (nodeType 8) don't support setAttribute, so no data-key
     attribute is set. The key is carried on a JS expando property instead,
     so the keyed Empty still participates in keyed reconciliation and is
     reused across frames (see test_keyed_empty_no_leak). *)
  Alcotest.(check int) "comment nodeType" 8 (node_type node)

let test_parse_css_px_integer () =
  Alcotest.(check int) "42" 42 (Nopal_web.parse_css_px "42")

let test_parse_css_px_integer_px () =
  Alcotest.(check int) "42px" 42 (Nopal_web.parse_css_px "42px")

let test_parse_css_px_fractional_px () =
  Alcotest.(check int)
    "44.5px truncates to 44" 44
    (Nopal_web.parse_css_px "44.5px")

let test_parse_css_px_zero () =
  Alcotest.(check int) "0px" 0 (Nopal_web.parse_css_px "0px")

let test_parse_css_px_empty () =
  Alcotest.(check int) "empty string" 0 (Nopal_web.parse_css_px "")

let test_parse_css_px_whitespace () =
  Alcotest.(check int)
    "whitespace padded" 44
    (Nopal_web.parse_css_px "  44px  ")

let test_parse_css_px_garbage () =
  Alcotest.(check int) "garbage returns 0" 0 (Nopal_web.parse_css_px "abc")

(* --- Box direction logic --- *)

let test_box_direction_defaults_column_when_none () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el =
    Box
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children = [];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el in
  let node = Nopal_web.Renderer.dom_node handle in
  let style_obj = Jv.get node "style" in
  let fd = Jv.Jstr.get style_obj "flex-direction" |> Jstr.to_string in
  Alcotest.(check string) "default direction is column" "column" fd

let test_box_direction_overrides_when_some () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let style =
    { default with layout = { default_layout with direction = Some Row_dir } }
  in
  let el =
    Box
      {
        style;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children = [];
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el in
  let node = Nopal_web.Renderer.dom_node handle in
  let style_obj = Jv.get node "style" in
  let fd = Jv.Jstr.get style_obj "flex-direction" |> Jstr.to_string in
  Alcotest.(check string) "direction is row" "row" fd

let test_row_ignores_style_direction () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let style =
    {
      default with
      layout = { default_layout with direction = Some Column_dir };
    }
  in
  let el =
    Row
      {
        style;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children = [];
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el in
  let node = Nopal_web.Renderer.dom_node handle in
  let style_obj = Jv.get node "style" in
  let fd = Jv.Jstr.get style_obj "flex-direction" |> Jstr.to_string in
  Alcotest.(check string) "row always row regardless of style" "row" fd

let test_column_ignores_style_direction () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let style =
    { default with layout = { default_layout with direction = Some Row_dir } }
  in
  let el =
    Column
      {
        style;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children = [];
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el in
  let node = Nopal_web.Renderer.dom_node handle in
  let style_obj = Jv.get node "style" in
  let fd = Jv.Jstr.get style_obj "flex-direction" |> Jstr.to_string in
  Alcotest.(check string) "column always column regardless of style" "column" fd

(* --- Reconcile direction re-assertion --- *)

let test_reconcile_row_reasserts_direction () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Row
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children = [];
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let el2 =
    Row
      {
        style =
          {
            default with
            layout = { default_layout with direction = Some Column_dir };
          };
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children = [];
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let node = Nopal_web.Renderer.dom_node handle in
  let style_obj = Jv.get node "style" in
  let fd = Jv.Jstr.get style_obj "flex-direction" |> Jstr.to_string in
  Alcotest.(check string) "row stays row after reconcile" "row" fd

let test_reconcile_column_reasserts_direction () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Column
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children = [];
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let el2 =
    Column
      {
        style =
          {
            default with
            layout = { default_layout with direction = Some Row_dir };
          };
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children = [];
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let node = Nopal_web.Renderer.dom_node handle in
  let style_obj = Jv.get node "style" in
  let fd = Jv.Jstr.get style_obj "flex-direction" |> Jstr.to_string in
  Alcotest.(check string) "column stays column after reconcile" "column" fd

(* --- Checkbox reconciliation --- *)

(* Checkbox: checked state changes true->false *)
let test_reconcile_checkbox_checked_true_to_false () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Checkbox
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        checked = true;
        disabled = false;
        on_toggle = Some (fun b -> Toggled b);
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check bool) "initially checked" true (Jv.Bool.get node "checked");
  let el2 =
    Checkbox
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        checked = false;
        disabled = false;
        on_toggle = Some (fun b -> Toggled b);
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let node_after = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check bool) "same node reused" true (node == node_after);
  Alcotest.(check bool)
    "checked updated to false" false
    (Jv.Bool.get node "checked")

(* Checkbox: checked state changes false->true *)
let test_reconcile_checkbox_checked_false_to_true () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Checkbox
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        checked = false;
        disabled = false;
        on_toggle = Some (fun b -> Toggled b);
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check bool) "initially unchecked" false (Jv.Bool.get node "checked");
  let el2 =
    Checkbox
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        checked = true;
        disabled = false;
        on_toggle = Some (fun b -> Toggled b);
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  Alcotest.(check bool)
    "checked updated to true" true
    (Jv.Bool.get node "checked")

(* Checkbox: enabled->disabled suppresses handler *)
let test_reconcile_checkbox_enabled_to_disabled () =
  let parent = fresh_parent () in
  let dispatch, msgs = fresh_dispatch () in
  let el1 =
    Checkbox
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        checked = false;
        disabled = false;
        on_toggle = Some (fun b -> Toggled b);
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let el2 =
    Checkbox
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        checked = false;
        disabled = true;
        on_toggle = Some (fun b -> Toggled b);
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let disabled_val =
    Jv.call node "getAttribute" [| Jv.of_string "disabled" |]
  in
  Alcotest.(check bool) "disabled attr set" false (Jv.is_null disabled_val);
  (* Dispatch a change event — should not produce a message *)
  let ev = Jv.new' (Jv.get Jv.global "Event") [| Jv.of_string "change" |] in
  ignore (Jv.call node "dispatchEvent" [| ev |]);
  Alcotest.(check int)
    "no message dispatched when disabled" 0 (List.length !msgs)

(* Checkbox: disabled->enabled restores handler *)
let test_reconcile_checkbox_disabled_to_enabled () =
  let parent = fresh_parent () in
  let dispatch, msgs = fresh_dispatch () in
  let el1 =
    Checkbox
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        checked = false;
        disabled = true;
        on_toggle = Some (fun b -> Toggled b);
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let el2 =
    Checkbox
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        checked = false;
        disabled = false;
        on_toggle = Some (fun b -> Toggled b);
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let disabled_val =
    Jv.call node "getAttribute" [| Jv.of_string "disabled" |]
  in
  Alcotest.(check bool) "disabled attr removed" true (Jv.is_null disabled_val);
  (* Dispatch a change event — should produce a message *)
  let ev = Jv.new' (Jv.get Jv.global "Event") [| Jv.of_string "change" |] in
  ignore (Jv.call node "dispatchEvent" [| ev |]);
  Alcotest.(check int) "message dispatched when enabled" 1 (List.length !msgs)

(* --- Radio reconciliation --- *)

(* Radio: checked state changes *)
let test_reconcile_radio_checked_state_changes () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Radio
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        name = "color";
        checked = false;
        disabled = false;
        on_select = Some Selected;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check bool) "initially unchecked" false (Jv.Bool.get node "checked");
  let el2 =
    Radio
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        name = "color";
        checked = true;
        disabled = false;
        on_select = Some Selected;
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let node_after = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check bool) "same node reused" true (node == node_after);
  Alcotest.(check bool)
    "checked updated to true" true
    (Jv.Bool.get node "checked")

(* Radio: enabled->disabled suppresses handler *)
let test_reconcile_radio_enabled_to_disabled () =
  let parent = fresh_parent () in
  let dispatch, msgs = fresh_dispatch () in
  let el1 =
    Radio
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        name = "color";
        checked = false;
        disabled = false;
        on_select = Some Selected;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let el2 =
    Radio
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        name = "color";
        checked = false;
        disabled = true;
        on_select = Some Selected;
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let disabled_val =
    Jv.call node "getAttribute" [| Jv.of_string "disabled" |]
  in
  Alcotest.(check bool) "disabled attr set" false (Jv.is_null disabled_val);
  let ev = Jv.new' (Jv.get Jv.global "Event") [| Jv.of_string "change" |] in
  ignore (Jv.call node "dispatchEvent" [| ev |]);
  Alcotest.(check int)
    "no message dispatched when disabled" 0 (List.length !msgs)

(* Radio: disabled->enabled restores handler *)
let test_reconcile_radio_disabled_to_enabled () =
  let parent = fresh_parent () in
  let dispatch, msgs = fresh_dispatch () in
  let el1 =
    Radio
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        name = "color";
        checked = false;
        disabled = true;
        on_select = Some Selected;
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let el2 =
    Radio
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        name = "color";
        checked = false;
        disabled = false;
        on_select = Some Selected;
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let disabled_val =
    Jv.call node "getAttribute" [| Jv.of_string "disabled" |]
  in
  Alcotest.(check bool) "disabled attr removed" true (Jv.is_null disabled_val);
  let ev = Jv.new' (Jv.get Jv.global "Event") [| Jv.of_string "change" |] in
  ignore (Jv.call node "dispatchEvent" [| ev |]);
  Alcotest.(check int) "message dispatched when enabled" 1 (List.length !msgs)

(* --- Select reconciliation --- *)

let opts_ab : select_option list =
  [
    { value = "a"; label = "Alpha"; disabled = false };
    { value = "b"; label = "Beta"; disabled = false };
  ]

let opts_abc : select_option list =
  [
    { value = "a"; label = "Alpha"; disabled = false };
    { value = "b"; label = "Beta"; disabled = false };
    { value = "c"; label = "Gamma"; disabled = false };
  ]

let opts_a_only : select_option list =
  [ { value = "a"; label = "Alpha"; disabled = false } ]

(* Select: selected value changes *)
let test_reconcile_select_selected_value_changes () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Select
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        options = opts_ab;
        selected = "a";
        disabled = false;
        on_change = Some (fun v -> Change v);
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let el2 =
    Select
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        options = opts_ab;
        selected = "b";
        disabled = false;
        on_change = Some (fun v -> Change v);
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let node_after = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check bool) "same node reused" true (node == node_after);
  (* Check that the selected option is now "b" by inspecting the value property *)
  let value = Jv.Jstr.get node "value" |> Jstr.to_string in
  Alcotest.(check string) "selected value is b" "b" value

(* Select: options list grows (add option) *)
let test_reconcile_select_options_add () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Select
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        options = opts_ab;
        selected = "a";
        disabled = false;
        on_change = Some (fun v -> Change v);
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let count_before = Jv.Int.get (Jv.get node "childNodes") "length" in
  Alcotest.(check int) "2 options initially" 2 count_before;
  let el2 =
    Select
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        options = opts_abc;
        selected = "a";
        disabled = false;
        on_change = Some (fun v -> Change v);
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let count_after = Jv.Int.get (Jv.get node "childNodes") "length" in
  Alcotest.(check int) "3 options after add" 3 count_after

(* Select: options list shrinks (remove option) *)
let test_reconcile_select_options_remove () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  let el1 =
    Select
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        options = opts_ab;
        selected = "a";
        disabled = false;
        on_change = Some (fun v -> Change v);
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let count_before = Jv.Int.get (Jv.get node "childNodes") "length" in
  Alcotest.(check int) "2 options initially" 2 count_before;
  let el2 =
    Select
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        options = opts_a_only;
        selected = "a";
        disabled = false;
        on_change = Some (fun v -> Change v);
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let count_after = Jv.Int.get (Jv.get node "childNodes") "length" in
  Alcotest.(check int) "1 option after remove" 1 count_after

(* Select: enabled->disabled suppresses handler *)
let test_reconcile_select_enabled_to_disabled () =
  let parent = fresh_parent () in
  let dispatch, msgs = fresh_dispatch () in
  let el1 =
    Select
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        options = opts_ab;
        selected = "a";
        disabled = false;
        on_change = Some (fun v -> Change v);
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let el2 =
    Select
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        options = opts_ab;
        selected = "a";
        disabled = true;
        on_change = Some (fun v -> Change v);
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let disabled_val =
    Jv.call node "getAttribute" [| Jv.of_string "disabled" |]
  in
  Alcotest.(check bool) "disabled attr set" false (Jv.is_null disabled_val);
  let ev = Jv.new' (Jv.get Jv.global "Event") [| Jv.of_string "change" |] in
  ignore (Jv.call node "dispatchEvent" [| ev |]);
  Alcotest.(check int)
    "no message dispatched when disabled" 0 (List.length !msgs)

(* Select: disabled->enabled restores handler *)
let test_reconcile_select_disabled_to_enabled () =
  let parent = fresh_parent () in
  let dispatch, msgs = fresh_dispatch () in
  let el1 =
    Select
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        options = opts_ab;
        selected = "a";
        disabled = true;
        on_change = Some (fun v -> Change v);
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  let el2 =
    Select
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        options = opts_ab;
        selected = "a";
        disabled = false;
        on_change = Some (fun v -> Change v);
      }
  in
  Nopal_web.Renderer.update ~dispatch handle el2;
  let disabled_val =
    Jv.call node "getAttribute" [| Jv.of_string "disabled" |]
  in
  Alcotest.(check bool) "disabled attr removed" true (Jv.is_null disabled_val);
  let ev = Jv.new' (Jv.get Jv.global "Event") [| Jv.of_string "change" |] in
  ignore (Jv.call node "dispatchEvent" [| ev |]);
  Alcotest.(check int) "message dispatched when enabled" 1 (List.length !msgs)

(* Select: a model value matching no option reflects the model (nothing
   selected), not the browser's default first option (FR-4). *)
let test_select_no_match_reflects_model () =
  let parent = fresh_parent () in
  let dispatch, _msgs = fresh_dispatch () in
  (* Initial render whose model value matches no option. *)
  let el1 =
    Select
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        options = opts_ab;
        selected = "z";
        disabled = false;
        on_change = Some (fun v -> Change v);
      }
  in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent el1 in
  let node = Nopal_web.Renderer.dom_node handle in
  Alcotest.(check int)
    "no option selected on create (selectedIndex = -1)" (-1)
    (Jv.Int.get node "selectedIndex");
  Alcotest.(check string)
    "value empty when nothing selected" ""
    (Jv.Jstr.get node "value" |> Jstr.to_string);
  (* Reconcile to a valid selection, then back to a no-match value: the prior
     selection must be released, not retained as a stale first option. *)
  let mk selected =
    Select
      {
        style = default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        options = opts_ab;
        selected;
        disabled = false;
        on_change = Some (fun v -> Change v);
      }
  in
  Nopal_web.Renderer.update ~dispatch handle (mk "a");
  Alcotest.(check int)
    "valid selection reflected after reconcile" 0
    (Jv.Int.get node "selectedIndex");
  Nopal_web.Renderer.update ~dispatch handle (mk "z");
  Alcotest.(check int)
    "no-match after reconcile clears selection (selectedIndex = -1)" (-1)
    (Jv.Int.get node "selectedIndex")

(* FR-3 focus-queue drain. [Nopal_web.drain_focus] focuses each queued id in
   FIFO order, so batched [Cmd.focus] requests (via [Cmd.batch]) all fire and the
   last one wins. The dom_shim records every focus() call into [document._focusLog]
   for registered targets. *)
let js_document () = Jv.get Jv.global "document"

let register_focus_target id =
  ignore (Jv.call (js_document ()) "_registerFocusTarget" [| Jv.of_string id |])

let reset_focus_log () =
  Jv.set (js_document ()) "_focusLog" (Jv.of_list Jv.of_string [])

let focus_log () =
  Jv.get (js_document ()) "_focusLog" |> Jv.to_list Jv.to_string

let active_element_id () =
  let ae = Jv.get (js_document ()) "activeElement" in
  if Jv.is_none ae then None else Some (Jv.to_string (Jv.get ae "id"))

let test_drain_focus_fifo_last_wins () =
  register_focus_target "focus-a";
  register_focus_target "focus-b";
  register_focus_target "focus-c";
  reset_focus_log ();
  let q = Queue.create () in
  List.iter (fun id -> Queue.add id q) [ "focus-a"; "focus-b"; "focus-c" ];
  Nopal_web.drain_focus q;
  Alcotest.(check (list string))
    "focuses each queued id in FIFO order"
    [ "focus-a"; "focus-b"; "focus-c" ]
    (focus_log ());
  Alcotest.(check bool) "queue is drained" true (Queue.is_empty q);
  Alcotest.(check (option string))
    "the last enqueued focus wins (activeElement)" (Some "focus-c")
    (active_element_id ())

let test_drain_focus_unknown_id_is_noop () =
  reset_focus_log ();
  let q = Queue.create () in
  Queue.add "no-such-element" q;
  (* Must not raise: getElementById returns null for an unknown id. *)
  Nopal_web.drain_focus q;
  Alcotest.(check (list string))
    "no focus recorded for an unknown id" [] (focus_log ());
  Alcotest.(check bool) "queue still drained" true (Queue.is_empty q)

let () =
  Alcotest.run "nopal_web"
    [
      ( "focus queue drain",
        [
          Alcotest.test_case "drains in FIFO order, last wins" `Quick
            test_drain_focus_fifo_last_wins;
          Alcotest.test_case "unknown id is a no-op" `Quick
            test_drain_focus_unknown_id_is_noop;
        ] );
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
          Alcotest.test_case "reconcile input skips unchanged value" `Quick
            test_reconcile_input_skips_unchanged_value;
          Alcotest.test_case "reconcile input updates changed value" `Quick
            test_reconcile_input_updates_changed_value;
          Alcotest.test_case "reconcile input skips unchanged attrs" `Quick
            test_reconcile_input_skips_unchanged_attrs;
          Alcotest.test_case "reconcile removes dropped inline style" `Quick
            test_reconcile_removes_dropped_inline_style;
          Alcotest.test_case "reconcile unchanged style no write" `Quick
            test_reconcile_unchanged_style_no_write;
        ] );
      ( "checkbox reconciliation",
        [
          Alcotest.test_case "checked true->false" `Quick
            test_reconcile_checkbox_checked_true_to_false;
          Alcotest.test_case "checked false->true" `Quick
            test_reconcile_checkbox_checked_false_to_true;
          Alcotest.test_case "enabled->disabled suppresses handler" `Quick
            test_reconcile_checkbox_enabled_to_disabled;
          Alcotest.test_case "disabled->enabled restores handler" `Quick
            test_reconcile_checkbox_disabled_to_enabled;
        ] );
      ( "radio reconciliation",
        [
          Alcotest.test_case "checked state changes" `Quick
            test_reconcile_radio_checked_state_changes;
          Alcotest.test_case "enabled->disabled suppresses handler" `Quick
            test_reconcile_radio_enabled_to_disabled;
          Alcotest.test_case "disabled->enabled restores handler" `Quick
            test_reconcile_radio_disabled_to_enabled;
        ] );
      ( "select reconciliation",
        [
          Alcotest.test_case "selected value changes" `Quick
            test_reconcile_select_selected_value_changes;
          Alcotest.test_case "options list add" `Quick
            test_reconcile_select_options_add;
          Alcotest.test_case "options list remove" `Quick
            test_reconcile_select_options_remove;
          Alcotest.test_case "enabled->disabled suppresses handler" `Quick
            test_reconcile_select_enabled_to_disabled;
          Alcotest.test_case "disabled->enabled restores handler" `Quick
            test_reconcile_select_disabled_to_enabled;
          Alcotest.test_case "no-match value reflects model" `Quick
            test_select_no_match_reflects_model;
        ] );
      ( "keyed reconciliation",
        [
          Alcotest.test_case "keyed reorder reuses nodes" `Quick
            test_keyed_reorder_reuses_nodes;
          Alcotest.test_case "keyed add new key" `Quick test_keyed_add_new_key;
          Alcotest.test_case "keyed remove key" `Quick test_keyed_remove_key;
          Alcotest.test_case "keyed stable node identity" `Quick
            test_keyed_stable_node_identity;
          Alcotest.test_case "keyed reorder moves only displaced" `Quick
            test_keyed_reorder_moves_only_displaced;
          Alcotest.test_case "keyed reorder full permutation" `Quick
            test_keyed_reorder_full_permutation;
          Alcotest.test_case "keyed reorder minimal move count" `Quick
            test_keyed_reorder_minimal_move_count;
          Alcotest.test_case "into-keyed removes old non-keyed" `Quick
            test_keyed_into_keyed_removes_old_nonkeyed;
          Alcotest.test_case "variant change carries key (no duplicate)" `Quick
            test_keyed_variant_change_no_duplicate;
          Alcotest.test_case "variant change Empty<->Box carries key" `Quick
            test_keyed_variant_change_empty_box_carries_key;
          Alcotest.test_case "keyed empty reused (no leak)" `Quick
            test_keyed_empty_no_leak;
          Alcotest.test_case "reused keyed node skips data-key write" `Quick
            test_keyed_reused_node_skips_data_key_write;
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
      ( "interaction reconciliation",
        [
          Alcotest.test_case "inject class on interaction change" `Quick
            test_reconcile_interaction_inject_on_change;
          Alcotest.test_case "remove class on interaction change" `Quick
            test_reconcile_interaction_remove_on_change;
          Alcotest.test_case "replace class on interaction change" `Quick
            test_reconcile_interaction_replace_on_change;
          Alcotest.test_case "skip injection when unchanged" `Quick
            test_reconcile_interaction_skips_unchanged;
          Alcotest.test_case "unchanged interaction does no CSSOM work" `Quick
            test_reconcile_interaction_unchanged_no_cssom;
          Alcotest.test_case "changed interaction releases prior rules" `Quick
            test_reconcile_interaction_change_releases_prior;
        ] );
      ( "parse_css_px",
        [
          Alcotest.test_case "integer" `Quick test_parse_css_px_integer;
          Alcotest.test_case "integer px" `Quick test_parse_css_px_integer_px;
          Alcotest.test_case "fractional px" `Quick
            test_parse_css_px_fractional_px;
          Alcotest.test_case "zero" `Quick test_parse_css_px_zero;
          Alcotest.test_case "empty" `Quick test_parse_css_px_empty;
          Alcotest.test_case "whitespace" `Quick test_parse_css_px_whitespace;
          Alcotest.test_case "garbage" `Quick test_parse_css_px_garbage;
        ] );
      ( "box direction",
        [
          Alcotest.test_case "defaults column when none" `Quick
            test_box_direction_defaults_column_when_none;
          Alcotest.test_case "overrides when some" `Quick
            test_box_direction_overrides_when_some;
          Alcotest.test_case "row ignores style direction" `Quick
            test_row_ignores_style_direction;
          Alcotest.test_case "column ignores style direction" `Quick
            test_column_ignores_style_direction;
          Alcotest.test_case "reconcile row reasserts direction" `Quick
            test_reconcile_row_reasserts_direction;
          Alcotest.test_case "reconcile column reasserts direction" `Quick
            test_reconcile_column_reasserts_direction;
        ] );
    ]

open Nopal_test.Test_renderer
module E = Nopal_element.Element
module Modal = Nopal_ui.Modal
module Toast = Nopal_ui.Toast
module Data_table = Nopal_ui.Data_table
module Text_input = Nopal_ui.TextInput
module Select_input = Nopal_ui.Select_input
module Checkbox = Nopal_ui.Checkbox
module Radio_group = Nopal_ui.Radio_group
module Navigation_bar = Nopal_ui.Navigation_bar

(* One message type spanning every handler the anchored components need. *)
type msg = Close | Dismiss of string | Sort_by of string | Selected of string

(* --- Modal: data-action="modal-dismiss" on the dismiss control --- *)

(* The Modal has no dedicated close button; its only clickable dismiss surface
   is the backdrop, so the dismiss anchor lives there (RFC Decision 1). *)
let modal_emits_dismiss_anchor () =
  let config =
    Modal.make ~open_:true ~title_id:"t" ~on_close:Close ~body:E.empty
    |> Modal.with_on_backdrop_click Close
  in
  match
    find
      (By_attr ("data-action", "modal-dismiss"))
      (tree (render (Modal.view config)))
  with
  | Some _ -> ()
  | None ->
      Alcotest.fail
        "expected data-action=modal-dismiss on the modal dismiss control"

(* --- Toast: data-action="toast-dismiss" on each toast --- *)

let toast_emits_dismiss_anchor () =
  let config = Toast.make ~dismiss:(fun id -> Dismiss id) in
  let toasts, _cmd =
    Toast.add ~variant:Toast.Info ~message:"Saved" ~id:"t1"
      ~dismiss:(fun id -> Dismiss id)
      []
  in
  match
    find
      (By_attr ("data-action", "toast-dismiss"))
      (tree (render (Toast.view config toasts)))
  with
  | Some _ -> ()
  | None -> Alcotest.fail "expected data-action=toast-dismiss on the toast"

(* --- Data_table: data-action="datatable-sort" + data-field=<column key> --- *)

(* Header copy "Name" differs from sort key "name", proving the field anchor
   tracks config, not copy. *)
let data_table_sortable_header_emits_field_anchor () =
  let columns =
    [
      Data_table.column ~header:"Name"
        ~cell:(fun r -> E.text r)
        ~sort_key:"name" ();
      Data_table.column ~header:"Age" ~cell:(fun _ -> E.text "x") ();
    ]
  in
  let config =
    Data_table.make ~columns ~rows:[ "alice" ]
      ~key:(fun r -> r)
      ~on_sort:(fun k -> Sort_by k)
      ()
  in
  match
    find
      (By_attr ("data-action", "datatable-sort"))
      (tree (render (Data_table.view config)))
  with
  | Some node ->
      Alcotest.(check (option string))
        "data-field equals the configured column key" (Some "name")
        (attr "data-field" node)
  | None ->
      Alcotest.fail "expected data-action=datatable-sort on the sortable header"

(* --- Text_input: data-field=<input id> --- *)

let text_input_emits_field_anchor () =
  let base : msg Text_input.config =
    Text_input.make ~label:"Email Address" ~value:""
  in
  let config = { base with Text_input.id = Some "email" } in
  match
    find
      (By_attr ("data-field", "email"))
      (tree (render (Text_input.view config)))
  with
  | Some _ -> ()
  | None ->
      Alcotest.fail
        "expected data-field equal to the input id on the text input"

(* --- Select_input: data-action="select-open" + data-field=slug(label) --- *)

let select_emits_open_and_field_anchors () =
  let options =
    [
      E.select_option ~value:"us" "United States";
      E.select_option ~value:"ca" "Canada";
    ]
  in
  let config : msg Select_input.config =
    Select_input.make ~label:"Country" ~options ~selected:"us"
  in
  let root = tree (render (Select_input.view config)) in
  (match find (By_attr ("data-action", "select-open")) root with
  | Some _ -> ()
  | None ->
      Alcotest.fail "expected data-action=select-open on the select trigger");
  match find (By_attr ("data-field", "country")) root with
  | Some _ -> ()
  | None -> Alcotest.fail "expected data-field derived from the select label"

(* --- Checkbox: data-field=slug(label); Radio_group: data-field=<group name> --- *)

let checkbox_radio_emit_field_anchors () =
  let cb : msg Checkbox.config =
    Checkbox.make ~label:"Accept Terms" ~checked:false
  in
  (match
     find
       (By_attr ("data-field", "accept-terms"))
       (tree (render (Checkbox.view cb)))
   with
  | Some _ -> ()
  | None -> Alcotest.fail "expected data-field derived from the checkbox label");
  let options =
    [
      Radio_group.radio_option ~value:"red" "Red";
      Radio_group.radio_option ~value:"blue" "Blue";
    ]
  in
  let base : msg Radio_group.config =
    Radio_group.make ~label:"Favorite" ~options ~selected:"red"
  in
  let rg = { base with Radio_group.name = Some "color" } in
  let fields =
    find_all
      (By_attr ("data-field", "color"))
      (tree (render (Radio_group.view rg)))
  in
  Alcotest.(check int)
    "one data-field=<group name> per radio option" 2 (List.length fields)

(* --- Navigation_bar: data-action="nav-navigate" + data-field=<route key> --- *)

let navigation_bar_item_emits_navigate_anchor () =
  let items =
    [
      Navigation_bar.item ~id:"home" "Home";
      Navigation_bar.item ~id:"settings" "Settings";
    ]
  in
  let config =
    Navigation_bar.make ~items ~active:"home" ~on_select:(fun id -> Selected id)
  in
  let root = tree (render (Navigation_bar.view config)) in
  let nav_anchors = find_all (By_attr ("data-action", "nav-navigate")) root in
  Alcotest.(check int)
    "one nav-navigate anchor per item" 2 (List.length nav_anchors);
  (match find (By_attr ("data-field", "home")) root with
  | Some _ -> ()
  | None -> Alcotest.fail "expected data-field=<route key> for the home item");
  match find (By_attr ("data-field", "settings")) root with
  | Some _ -> ()
  | None ->
      Alcotest.fail "expected data-field=<route key> for the settings item"

let () =
  Alcotest.run "nopal_ui_anchors"
    [
      ( "intrinsic interaction anchors",
        [
          Alcotest.test_case "modal emits dismiss anchor" `Quick
            modal_emits_dismiss_anchor;
          Alcotest.test_case "toast emits dismiss anchor" `Quick
            toast_emits_dismiss_anchor;
          Alcotest.test_case "data_table sortable header emits field anchor"
            `Quick data_table_sortable_header_emits_field_anchor;
          Alcotest.test_case "text_input emits field anchor" `Quick
            text_input_emits_field_anchor;
          Alcotest.test_case "select emits open and field anchors" `Quick
            select_emits_open_and_field_anchors;
          Alcotest.test_case "checkbox and radio emit field anchors" `Quick
            checkbox_radio_emit_field_anchors;
          Alcotest.test_case "navigation_bar item emits navigate anchor" `Quick
            navigation_bar_item_emits_navigate_anchor;
        ] );
    ]

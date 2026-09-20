(* The published change list is pinned to the tree, in both directions.

   `llms.txt` carries a list of what a downstream consumer meets on its next pin
   bump: the attribute keys whose answer moved, and the rendered-tree changes.
   Every signature involved is unchanged, so a structural suite downstream gets
   no compiler help — the list is the only warning it gets, and a list no test
   pins is a list that drifts.

   So the list is duplicated here as two OCaml values and checked against a live
   render. The check runs in both directions: a key the list publishes whose
   answer did not actually move fails, and a key whose answer moved but which
   the list does not publish fails too. The same for the tree rows.

   {2 Where "before" comes from}

   The [before] column of each candidate is the answer at the merge base — the
   tree the change list's reader is upgrading FROM. It cannot be read at
   runtime, so it is a literal here, taken from the previous revision of each
   component rather than from anyone's expectation of it. The [after] column of
   a tree candidate is asserted against the live render, so a shape change in
   either direction reddens a case; an attribute candidate is partitioned by
   comparing the live reading against [before], which is the shape the
   equivalent list for the attribute-precedence change uses.

   {2 What the unchanged rows are for}

   A change list that names only what moved makes an unbounded claim about
   everything it omits. The candidates below therefore include keys and shapes
   the list records as UNCHANGED, and the test asserts that set too: a key that
   quietly starts moving lands in the moved partition, fails the
   "moved and not published" arm, and has to be published or fixed.

   The unchanged rows for the seven components that gained only style overrides
   read one representative key each rather than every key those components
   emit. Exhaustive per-component coverage is the ARIA-survival suites' job
   ([test_aria_survival.ml] and the four per-component cases it names); these
   rows exist so that the change list's "nothing else moved" half is pinned at
   all. *)

open Nopal_test.Test_renderer
module E = Nopal_element.Element
module Slug = Nopal_ui.Slug
module TI = Nopal_ui.TextInput
module CB = Nopal_ui.Checkbox
module SI = Nopal_ui.Select_input
module RG = Nopal_ui.Radio_group
module TT = Nopal_ui.Toast
module BU = Nopal_ui.Button
module DT = Nopal_ui.Data_table
module MO = Nopal_ui.Modal
module NB = Nopal_ui.Navigation_bar
module BT = Nopal_ui.Bottom_tabs
module Nav_stack = Nopal_navigation.Nav_stack

(* A plain string message: nothing below asserts on a dispatch, so no case needs
   a message type richer than "something could be dispatched". *)
type msg = string

let fail_missing where = Alcotest.fail ("no node found for " ^ where)

let node_at where selector element =
  match find selector (tree (render element)) with
  | Some node -> node
  | None -> fail_missing where

let tag_of = function
  | Element { tag; _ } -> tag
  | Text _ -> "text"
  | Empty -> "empty"

let child_tags = function
  | Element { children; _ } -> List.map tag_of children
  | Text _ -> [ "<a text node has no children>" ]
  | Empty -> [ "<an empty node has no children>" ]

(* --- Fixtures. Every one is built through its component's own constructor and
   then given only the fields the row under test depends on. The change list
   describes what a consumer who sets no override sees, so a fixture setting an
   override would be measuring something else; the two that do set one
   ([cb_with_id], [si_with_id], [rg_visible]) are the rows about that override. *)

let ti_plain : msg TI.config = TI.make ~label:"First Name" ~value:""
let ti_error : msg TI.config = { ti_plain with error = Some "Required" }
let cb_plain : msg CB.config = CB.make ~label:"Accept Terms" ~checked:false
let cb_with_id : msg CB.config = CB.with_id "terms-box" cb_plain

let si_plain : msg SI.config =
  SI.make ~label:"Colour"
    ~options:[ E.select_option ~value:"red" "Red" ]
    ~selected:"red"

let si_with_id : msg SI.config = SI.with_id "hue" si_plain

let rg_plain : msg RG.config =
  RG.make ~label:"Colour"
    ~options:
      [
        RG.radio_option ~value:"red" "Red"; RG.radio_option ~value:"blue" "Blue";
      ]
    ~selected:"red"

let rg_visible : msg RG.config = RG.with_visible_label true rg_plain

let toast_stack () =
  TT.view
    (TT.make ~dismiss:(fun id -> id))
    [
      { TT.id = "saved"; variant = TT.Info; message = "Saved" };
      { TT.id = "gone"; variant = TT.Error; message = "Gone" };
    ]

(* [Button.default] fills concrete behavioural defaults, so both of them are set
   here rather than inherited: [disabled] is what the row reads and [loading] is
   what would otherwise add [aria-busy] to the same node. *)
let button_disabled () =
  BU.view
    { (BU.default BU.Primary) with disabled = true; loading = false }
    (E.text "Save")

type row = { name : string }

let dt_config : (row, msg) DT.config =
  DT.make
    ~columns:
      [
        {
          DT.header = "Name";
          cell = (fun r -> E.text r.name);
          sort_key = Some "name";
        };
      ]
    ~rows:[ { name = "Ada" } ]
    ~key:(fun r -> r.name)
    ~on_sort:(fun k -> k)
    ~sort:{ DT.column = "name"; direction = DT.Ascending }
    ()

let modal_plain : msg MO.config =
  MO.make ~open_:true ~title_id:"dialog-title" ~on_close:"close"
    ~body:(E.text "body")

let modal_backdrop : msg MO.config =
  MO.with_on_backdrop_click "dismiss" modal_plain

let nav_config : msg NB.config =
  NB.make
    ~items:[ NB.item ~id:"home" "Home"; NB.item ~id:"more" "More" ]
    ~active:"home"
    ~on_select:(fun id -> id)

let tabs_config : (string, msg) BT.config =
  BT.make
    ~tabs:
      [
        BT.tab ~id:"home" ~label:"Home"
          ~stack:(Nav_stack.push "detail" (Nav_stack.create "root"))
          ();
      ]
    ~active:"home" ~render_screen:E.text
    ~on_select:(fun id -> id)
    ~on_back:"back" ~safe_area_bottom:34

(* --- The attribute part of the published list. --- *)

type attr_candidate = {
  where : string;
  key : string;
  before : string option;
  reading : unit -> string option;
}

let candidate where selector ~key ~before element =
  {
    where;
    key;
    before;
    reading = (fun () -> attr key (node_at where selector element));
  }

let group_container = By_attr ("role", "radiogroup")

let attr_candidates =
  [
    (* Text_input. *)
    candidate "text input" (By_tag "input") ~key:"aria-label"
      ~before:(Some "First Name") (TI.view ti_plain);
    candidate "text input" (By_tag "input") ~key:"aria-labelledby" ~before:None
      (TI.view ti_plain);
    candidate "text input" (By_tag "input") ~key:"id" ~before:None
      (TI.view ti_plain);
    candidate "text input" (By_tag "input") ~key:"data-field"
      ~before:(Some "first-name") (TI.view ti_plain);
    candidate "text input error slot"
      (By_attr ("role", "alert"))
      ~key:"id" ~before:(Some "first-name-error") (TI.view ti_error);
    candidate "text input with an error" (By_tag "input")
      ~key:"aria-describedby" ~before:(Some "first-name-error")
      (TI.view ti_error);
    (* Checkbox. *)
    candidate "checkbox" (By_tag "checkbox") ~key:"aria-label"
      ~before:(Some "Accept Terms") (CB.view cb_plain);
    candidate "checkbox" (By_tag "checkbox") ~key:"aria-labelledby" ~before:None
      (CB.view cb_plain);
    candidate "checkbox" (By_tag "checkbox") ~key:"id" ~before:None
      (CB.view cb_plain);
    candidate "checkbox" (By_tag "checkbox") ~key:"data-field"
      ~before:(Some "accept-terms") (CB.view cb_plain);
    candidate "checkbox under with_id" (By_tag "checkbox") ~key:"data-field"
      ~before:(Some "accept-terms") (CB.view cb_with_id);
    (* Select_input. *)
    candidate "select" (By_tag "select") ~key:"aria-label"
      ~before:(Some "Colour") (SI.view si_plain);
    candidate "select" (By_tag "select") ~key:"aria-labelledby" ~before:None
      (SI.view si_plain);
    candidate "select" (By_tag "select") ~key:"id" ~before:None
      (SI.view si_plain);
    candidate "select" (By_tag "select") ~key:"data-field"
      ~before:(Some "colour") (SI.view si_plain);
    candidate "select" (By_tag "select") ~key:"data-action"
      ~before:(Some "select-open") (SI.view si_plain);
    candidate "select under with_id" (By_tag "select") ~key:"data-field"
      ~before:(Some "colour") (SI.view si_with_id);
    (* Radio_group — the options, then the group container. *)
    candidate "radio option" (By_tag "radio") ~key:"aria-label"
      ~before:(Some "Red") (RG.view rg_plain);
    candidate "radio option" (By_tag "radio") ~key:"aria-labelledby"
      ~before:None (RG.view rg_plain);
    candidate "radio option" (By_tag "radio") ~key:"id" ~before:None
      (RG.view rg_plain);
    candidate "radio option" (By_tag "radio") ~key:"data-field"
      ~before:(Some "colour") (RG.view rg_plain);
    candidate "radio group container" group_container ~key:"id" ~before:None
      (RG.view rg_plain);
    candidate "radio group container" group_container ~key:"role"
      ~before:(Some "radiogroup") (RG.view rg_plain);
    candidate "radio group container" group_container ~key:"aria-label"
      ~before:(Some "Colour") (RG.view rg_plain);
    candidate "radio group container" group_container ~key:"aria-labelledby"
      ~before:None (RG.view rg_plain);
    candidate "radio group container under with_visible_label" group_container
      ~key:"aria-label" ~before:(Some "Colour") (RG.view rg_visible);
    candidate "radio group container under with_visible_label" group_container
      ~key:"aria-labelledby" ~before:None (RG.view rg_visible);
    (* The seven components that gained only style overrides. One representative
       key each; the ARIA-survival suites cover the rest. *)
    candidate "toast"
      (By_attr ("data-action", "toast-dismiss"))
      ~key:"aria-live" ~before:(Some "polite") (toast_stack ());
    candidate "toast"
      (By_attr ("data-action", "toast-dismiss"))
      ~key:"aria-label" ~before:(Some "Dismiss: Saved") (toast_stack ());
    candidate "button" (By_tag "button") ~key:"aria-disabled"
      ~before:(Some "true") (button_disabled ());
    candidate "button" (By_tag "button") ~key:"data-variant"
      ~before:(Some "primary") (button_disabled ());
    candidate "data table"
      (By_attr ("role", "table"))
      ~key:"role" ~before:(Some "table") (DT.view dt_config);
    candidate "data table sorted header"
      (By_attr ("role", "columnheader"))
      ~key:"aria-sort" ~before:(Some "ascending") (DT.view dt_config);
    candidate "modal dialog"
      (By_attr ("role", "dialog"))
      ~key:"aria-labelledby" ~before:(Some "dialog-title") (MO.view modal_plain);
    candidate "modal root"
      (By_attr ("data-testid", "modal-root"))
      ~key:"data-testid" ~before:(Some "modal-root") (MO.view modal_plain);
    candidate "navigation bar"
      (By_attr ("role", "tablist"))
      ~key:"role" ~before:(Some "tablist") (NB.view nav_config);
    candidate "navigation bar active item" (By_tag "button")
      ~key:"aria-selected" ~before:(Some "true") (NB.view nav_config);
    candidate "bottom tabs panel"
      (By_attr ("role", "tabpanel"))
      ~key:"data-field" ~before:(Some "home") (BT.view tabs_config);
    candidate "bottom tabs back affordance"
      (By_attr ("data-action", "nav-back"))
      ~key:"data-testid" ~before:(Some "bottom-tabs-back") (BT.view tabs_config);
  ]

(* The attribute rows of the change list published in llms.txt, as
   (where, key). Every row is a key whose answer moved. This list and that table
   are edited together. *)
let published_attribute_change_list =
  [
    ("text input", "aria-label");
    ("text input", "aria-labelledby");
    ("text input", "id");
    ("checkbox", "aria-label");
    ("checkbox", "aria-labelledby");
    ("checkbox", "id");
    ("select", "aria-label");
    ("select", "aria-labelledby");
    ("select", "id");
    ("radio option", "aria-label");
    ("radio option", "aria-labelledby");
    ("radio option", "id");
    ("radio group container", "id");
    ("radio group container under with_visible_label", "aria-label");
    ("radio group container under with_visible_label", "aria-labelledby");
  ]

(* The keys the list records as unchanged, in candidate order. *)
let unchanged_attribute_keys =
  [
    ("text input", "data-field");
    ("text input error slot", "id");
    ("text input with an error", "aria-describedby");
    ("checkbox", "data-field");
    ("checkbox under with_id", "data-field");
    ("select", "data-field");
    ("select", "data-action");
    ("select under with_id", "data-field");
    ("radio option", "data-field");
    ("radio group container", "role");
    ("radio group container", "aria-label");
    ("radio group container", "aria-labelledby");
    ("toast", "aria-live");
    ("toast", "aria-label");
    ("button", "aria-disabled");
    ("button", "data-variant");
    ("data table", "role");
    ("data table sorted header", "aria-sort");
    ("modal dialog", "aria-labelledby");
    ("modal root", "data-testid");
    ("navigation bar", "role");
    ("navigation bar active item", "aria-selected");
    ("bottom tabs panel", "data-field");
    ("bottom tabs back affordance", "data-testid");
  ]

let key_list = Alcotest.(list (pair string string))

let change_list_matches_the_attributes_that_moved () =
  let moved, unmoved =
    List.partition (fun c -> c.reading () <> c.before) attr_candidates
  in
  let keys entries = List.map (fun c -> (c.where, c.key)) entries in
  Alcotest.check key_list
    "the published list is exactly the keys whose answer moved"
    published_attribute_change_list (keys moved);
  Alcotest.check key_list "a published key whose answer did not move" []
    (List.filter
       (fun k -> not (List.mem k (keys moved)))
       published_attribute_change_list);
  Alcotest.check key_list "a key whose answer moved and was not published" []
    (List.filter
       (fun k -> not (List.mem k published_attribute_change_list))
       (keys moved));
  Alcotest.check key_list
    "and the keys recorded as unchanged were read, and are unchanged"
    unchanged_attribute_keys (keys unmoved)

(* --- The tree part of the published list. A node appearing is not a key
   changing its answer, so it is a separate part of the list and a separate
   case. --- *)

type tree_candidate = {
  shape : string;
  before_tags : string list;
  after_tags : string list;
  tags_now : unit -> string list;
}

let shape_candidate shape selector ~before ~after element =
  {
    shape;
    before_tags = before;
    after_tags = after;
    tags_now = (fun () -> child_tags (node_at shape selector element));
  }

let tree_candidates =
  [
    shape_candidate "text input column" (By_tag "column")
      ~before:[ "text"; "input" ] ~after:[ "box"; "input" ] (TI.view ti_plain);
    shape_candidate "text input error slot"
      (By_attr ("role", "alert"))
      ~before:[ "text" ] ~after:[ "text" ] (TI.view ti_error);
    shape_candidate "checkbox row" (By_tag "row") ~before:[ "checkbox"; "text" ]
      ~after:[ "checkbox"; "box" ] (CB.view cb_plain);
    shape_candidate "select input column" (By_tag "column")
      ~before:[ "text"; "select" ] ~after:[ "box"; "select" ] (SI.view si_plain);
    shape_candidate "radio option row" (By_tag "row")
      ~before:[ "radio"; "text" ] ~after:[ "radio"; "box" ] (RG.view rg_plain);
    shape_candidate "radio group container" group_container
      ~before:[ "row"; "row" ] ~after:[ "row"; "row" ] (RG.view rg_plain);
    shape_candidate "radio group container under with_visible_label"
      group_container ~before:[ "row"; "row" ] ~after:[ "box"; "row"; "row" ]
      (RG.view rg_visible);
    shape_candidate "toast stack" (By_tag "column")
      ~before:[ "button"; "button" ] ~after:[ "button"; "button" ]
      (toast_stack ());
    shape_candidate "button" (By_tag "button") ~before:[ "text" ]
      ~after:[ "text" ] (button_disabled ());
    shape_candidate "data table root"
      (By_attr ("role", "table"))
      ~before:[ "row"; "keyed" ] ~after:[ "row"; "keyed" ] (DT.view dt_config);
    shape_candidate "modal root without a backdrop"
      (By_attr ("data-testid", "modal-root"))
      ~before:[ "column" ] ~after:[ "column" ] (MO.view modal_plain);
    shape_candidate "modal root with a backdrop"
      (By_attr ("data-testid", "modal-root"))
      ~before:[ "box"; "column" ] ~after:[ "box"; "column" ]
      (MO.view modal_backdrop);
    shape_candidate "navigation bar"
      (By_attr ("role", "tablist"))
      ~before:[ "button"; "button" ] ~after:[ "button"; "button" ]
      (NB.view nav_config);
    shape_candidate "bottom tabs root" (By_tag "column")
      ~before:[ "box"; "box" ] ~after:[ "box"; "box" ] (BT.view tabs_config);
    shape_candidate "bottom tabs panel"
      (By_attr ("role", "tabpanel"))
      ~before:[ "button"; "text" ] ~after:[ "button"; "text" ]
      (BT.view tabs_config);
  ]

(* The tree rows of the change list published in llms.txt. Every row is a
   container whose child list is a different shape after this change. *)
let published_tree_change_list =
  [
    "text input column";
    "checkbox row";
    "select input column";
    "radio option row";
    "radio group container under with_visible_label";
  ]

(* The shapes the list records as unchanged, in candidate order. *)
let unchanged_tree_shapes =
  [
    "text input error slot";
    "radio group container";
    "toast stack";
    "button";
    "data table root";
    "modal root without a backdrop";
    "modal root with a backdrop";
    "navigation bar";
    "bottom tabs root";
    "bottom tabs panel";
  ]

let shape_list = Alcotest.(list string)
let tag_list = Alcotest.(list string)

let change_list_matches_the_tree_changes () =
  List.iter
    (fun c ->
      Alcotest.check tag_list
        (c.shape ^ ": the child list the change list publishes")
        c.after_tags (c.tags_now ()))
    tree_candidates;
  let moved, unmoved =
    List.partition (fun c -> c.tags_now () <> c.before_tags) tree_candidates
  in
  let shapes entries = List.map (fun c -> c.shape) entries in
  Alcotest.check shape_list
    "the published tree list is exactly the shapes that changed"
    published_tree_change_list (shapes moved);
  Alcotest.check shape_list "a published shape that did not change" []
    (List.filter
       (fun s -> not (List.mem s (shapes moved)))
       published_tree_change_list);
  Alcotest.check shape_list "a shape that changed and was not published" []
    (List.filter
       (fun s -> not (List.mem s published_tree_change_list))
       (shapes moved));
  Alcotest.check shape_list
    "and the shapes recorded as unchanged were read, and are unchanged"
    unchanged_tree_shapes (shapes unmoved)

(* --- The cases the change list names rather than leaving to be derived. Each
   is published as prose, so each is pinned by behaviour here. --- *)

let a_caller_aria_label_survives_but_no_longer_names_the_control () =
  let with_caller_name =
    { ti_plain with TI.attrs = [ ("aria-label", "Given name") ] }
  in
  let input =
    node_at "text input" (By_tag "input") (TI.view with_caller_name)
  in
  Alcotest.(check (option string))
    "the caller's pair is still in the tree and still wins its own key"
    (Some "Given name") (attr "aria-label" input);
  Alcotest.(check (option string))
    "and the component's aria-labelledby is there beside it"
    (Some (Slug.derive_id ~explicit:None ~label:"First Name" ~suffix:"label" ()))
    (attr "aria-labelledby" input)

let the_group_label_is_opt_in () =
  let default_group = RG.view rg_plain in
  Alcotest.(check (list string))
    "no group label node exists without the setter" [ "row"; "row" ]
    (child_tags (node_at "radio group" group_container default_group));
  let explicit_false = RG.view (RG.with_visible_label false rg_plain) in
  Alcotest.(check (list string))
    "and none with the setter given false" [ "row"; "row" ]
    (child_tags (node_at "radio group" group_container explicit_false));
  Alcotest.(check (option string))
    "the group keeps aria-label until the setter gives it a target"
    (Some "Colour")
    (attr "aria-label" (node_at "radio group" group_container explicit_false))

(* The ids these controls now emit are derived from the slugified label alone,
   so two controls sharing a label share every id derived from it. Nothing in
   the library prevents it; the list publishes it as the caller's precondition,
   and this pins that the collision is real rather than theoretical. *)
let the_derived_ids_are_not_unique_by_construction () =
  let other = CB.make ~label:"Accept Terms" ~checked:true in
  let id_of config =
    attr "id" (node_at "checkbox" (By_tag "checkbox") (CB.view config))
  in
  Alcotest.(check (option string))
    "two controls with the same label emit the same id" (id_of cb_plain)
    (id_of other);
  Alcotest.(check string)
    "and with_id is the way apart" "terms-box" (CB.control_id cb_with_id);
  let collides =
    RG.with_visible_label true
      (RG.make ~label:"Colour"
         ~options:[ RG.radio_option ~value:"label" "Label" ]
         ~selected:"label")
  in
  Alcotest.(check string)
    "within a group, an option valued \"label\" collides with the group label"
    (RG.control_id collides ^ "-label")
    (RG.option_id collides ~value:"label")

let () =
  Alcotest.run "nopal_ui_change_list"
    [
      ( "the published change list",
        [
          Alcotest.test_case "attributes that moved" `Quick
            change_list_matches_the_attributes_that_moved;
          Alcotest.test_case "tree changes" `Quick
            change_list_matches_the_tree_changes;
        ] );
      ( "the cases the list names",
        [
          Alcotest.test_case "a caller's aria-label no longer names the control"
            `Quick a_caller_aria_label_survives_but_no_longer_names_the_control;
          Alcotest.test_case "the group label is opt-in" `Quick
            the_group_label_is_opt_in;
          Alcotest.test_case "the derived ids are not unique by construction"
            `Quick the_derived_ids_are_not_unique_by_construction;
        ] );
    ]

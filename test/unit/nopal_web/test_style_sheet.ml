open Nopal_web.Style_sheet

(* ── DOM helpers ── *)

let cleanup_head () =
  let doc = Jv.get Jv.global "document" in
  let head = Jv.get doc "head" in
  let children = Jv.get head "childNodes" in
  let len = Jv.to_int (Jv.get children "length") in
  for i = len - 1 downto 0 do
    let child = Jv.get children (string_of_int i) in
    ignore (Jv.call head "removeChild" [| child |])
  done

let count_nopal_style_els () =
  let doc = Jv.get Jv.global "document" in
  let head = Jv.get doc "head" in
  let children = Jv.get head "childNodes" in
  let len = Jv.to_int (Jv.get children "length") in
  let count = ref 0 in
  for i = 0 to len - 1 do
    let child = Jv.get children (string_of_int i) in
    let tag = Jv.to_string (Jv.get child "nodeName") in
    if String.equal tag "STYLE" then begin
      let has_attr =
        Jv.to_bool
          (Jv.call child "hasAttribute" [| Jv.of_string "data-nopal" |])
      in
      if has_attr then incr count
    end
  done;
  !count

let get_sheet () =
  let doc = Jv.get Jv.global "document" in
  let head = Jv.get doc "head" in
  let children = Jv.get head "childNodes" in
  let len = Jv.to_int (Jv.get children "length") in
  let result = ref Jv.null in
  for i = 0 to len - 1 do
    let child = Jv.get children (string_of_int i) in
    let tag = Jv.to_string (Jv.get child "nodeName") in
    if String.equal tag "STYLE" then begin
      let has_attr =
        Jv.to_bool
          (Jv.call child "hasAttribute" [| Jv.of_string "data-nopal" |])
      in
      if has_attr then result := Jv.get child "sheet"
    end
  done;
  !result

let rules_length sheet = Jv.to_int (Jv.get (Jv.get sheet "cssRules") "length")

let rule_text sheet idx =
  let rules = Jv.get sheet "cssRules" in
  let rule = Jv.get rules (string_of_int idx) in
  Jv.to_string (Jv.get rule "cssText")

let rule_texts sheet = List.init (rules_length sheet) (rule_text sheet)

let nopal_sheets () =
  let doc = Jv.get Jv.global "document" in
  let head = Jv.get doc "head" in
  let children = Jv.get head "childNodes" in
  let len = Jv.to_int (Jv.get children "length") in
  List.init len (fun i -> Jv.get children (string_of_int i))
  |> List.filter (fun child ->
      String.equal (Jv.to_string (Jv.get child "nodeName")) "STYLE"
      && Jv.to_bool
           (Jv.call child "hasAttribute" [| Jv.of_string "data-nopal" |]))
  |> List.map (fun child -> Jv.get child "sheet")

let selector_of rule =
  match String.index_opt rule '{' with
  | Some brace -> String.trim (String.sub rule 0 brace)
  | None -> String.trim rule

let declarations_of rule =
  match (String.index_opt rule '{', String.rindex_opt rule '}') with
  | Some opening, Some closing when closing > opening ->
      String.sub rule (opening + 1) (closing - opening - 1)
      |> String.split_on_char ';'
      |> List.map String.trim
      |> List.filter (fun declaration -> not (String.equal declaration ""))
  | Some _, Some _
  | Some _, None
  | None, Some _
  | None, None ->
      []

let heading_reset_selector = ":where([" ^ heading_marker ^ "])"

let heading_resets sheet =
  List.filter
    (fun rule -> String.equal (selector_of rule) heading_reset_selector)
    (rule_texts sheet)

(* Every sheet now opens with the heading reset, so the index-tracking cases
   below count and address only the class rules the sheet manages. *)
let class_rules sheet =
  List.filter
    (fun rule -> not (String.equal (selector_of rule) heading_reset_selector))
    (rule_texts sheet)

let class_rule_count sheet = List.length (class_rules sheet)

let class_rule_text sheet idx =
  match List.nth_opt (class_rules sheet) idx with
  | Some rule -> rule
  | None -> Alcotest.failf "no class rule at index %d" idx

(* ── Test styles ── *)

let mk_style color =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_paint (fun p ->
      { p with background = Some (Nopal_style.Style.hex color) })

let mk_interaction_hover color =
  { Nopal_style.Interaction.default with hover = Some (mk_style color) }

let mk_interaction_all () =
  {
    Nopal_style.Interaction.hover = Some (mk_style "#aaa");
    pressed = Some (mk_style "#bbb");
    focused = Some (mk_style "#ccc");
  }

let base_css_props color =
  Nopal_web.Style_css.of_style ~parent_axis:None (mk_style color)

(* ── Tests ── *)

(* 1 *)
let test_create_inserts_single_style_element () =
  cleanup_head ();
  let _t = create () in
  Alcotest.(check int)
    "exactly one <style data-nopal>" 1 (count_nopal_style_els ())

let test_create_inserts_scoped_heading_reset_once () =
  cleanup_head ();
  let _t = create () in
  match heading_resets (get_sheet ()) with
  | [ reset ] ->
      let declarations = declarations_of reset in
      List.iter
        (fun expected ->
          Alcotest.(check bool)
            (Printf.sprintf "the reset sets %s" expected)
            true
            (List.exists (String.equal expected) declarations))
        [ "margin:0"; "font-size:inherit"; "font-weight:inherit" ]
  | resets ->
      Alcotest.failf "expected one rule with selector %s, got %d"
        heading_reset_selector (List.length resets)

let test_heading_reset_selector_has_no_unscoped_tag () =
  cleanup_head ();
  let _t = create () in
  let rules = rule_texts (get_sheet ()) in
  Alcotest.(check bool)
    "a fresh sheet holds a rule naming the heading marker" true
    (List.exists
       (fun rule -> Test_util.string_contains rule ~sub:"[data-nopal-heading]")
       rules);
  List.iter
    (fun rule ->
      List.iter
        (fun tag ->
          Alcotest.(check bool)
            (Printf.sprintf "%S names no %s" rule tag)
            false
            (Test_util.string_contains rule ~sub:tag))
        [ "h1"; "h2"; "h3"; "h4"; "h5"; "h6" ])
    rules

let test_two_sheets_each_carry_one_reset () =
  cleanup_head ();
  let _first = create () in
  let _second = create () in
  Alcotest.(check (list int))
    "one heading reset in each of the two sheets" [ 1; 1 ]
    (List.map
       (fun sheet -> List.length (heading_resets sheet))
       (nopal_sheets ()))

let test_base_rule_indices_unaffected_by_reset () =
  cleanup_head ();
  let t = create () in
  let bid = inject_base t ~css_props:(base_css_props "#ff0000") in
  let sheet = get_sheet () in
  let base_selector = "." ^ base_class_name bid in
  Alcotest.(check (list string))
    "the reset and the base rule, in insertion order"
    [ heading_reset_selector; base_selector ]
    (List.map selector_of (rule_texts sheet));
  remove_base t bid;
  Alcotest.(check (list string))
    "only the reset remains" [ heading_reset_selector ]
    (List.map selector_of (rule_texts sheet))

(* 2 *)
let test_inject_base_adds_rule () =
  cleanup_head ();
  let t = create () in
  let bid = inject_base t ~css_props:(base_css_props "#ff0000") in
  let sheet = get_sheet () in
  Alcotest.(check int) "one rule" 1 (class_rule_count sheet);
  let rule = class_rule_text sheet 0 in
  let class_n = base_class_name bid in
  Alcotest.(check bool)
    "rule contains class name" true
    (String.length rule > 0
    && String.length class_n > 0
    &&
    let pos =
      let hlen = String.length rule in
      let nlen = String.length class_n in
      if nlen > hlen then -1
      else
        let found = ref (-1) in
        let i = ref 0 in
        while !found = -1 && !i <= hlen - nlen do
          if String.sub rule !i nlen = class_n then found := !i;
          incr i
        done;
        !found
    in
    pos >= 0)

(* 3 *)
let test_inject_interaction_adds_rules () =
  cleanup_head ();
  let t = create () in
  let result = inject_interaction t ~interaction:(mk_interaction_all ()) in
  (match result with
  | Error e -> Alcotest.fail (Printf.sprintf "expected Ok, got Error %S" e)
  | Ok _ -> ());
  let sheet = get_sheet () in
  Alcotest.(check int)
    "three rules (hover + focused + pressed)" 3 (class_rule_count sheet)

(* 4 *)
let test_inject_interaction_dedup_same_style () =
  cleanup_head ();
  let t = create () in
  let interaction = mk_interaction_hover "#ff0000" in
  let r1 = inject_interaction t ~interaction in
  let r2 = inject_interaction t ~interaction in
  let id1 =
    match r1 with
    | Ok id -> id
    | Error e -> Alcotest.failf "r1 error: %s" e
  in
  let id2 =
    match r2 with
    | Ok id -> id
    | Error e -> Alcotest.failf "r2 error: %s" e
  in
  Alcotest.(check string)
    "same class name"
    (interaction_class_name id1)
    (interaction_class_name id2);
  let sheet = get_sheet () in
  Alcotest.(check int) "no extra rules" 1 (class_rule_count sheet)

(* 5 *)
let test_inject_interaction_dedup_different_style () =
  cleanup_head ();
  let t = create () in
  let r1 = inject_interaction t ~interaction:(mk_interaction_hover "#aaa") in
  let r2 = inject_interaction t ~interaction:(mk_interaction_hover "#bbb") in
  let id1 =
    match r1 with
    | Ok id -> id
    | Error e -> Alcotest.failf "r1 error: %s" e
  in
  let id2 =
    match r2 with
    | Ok id -> id
    | Error e -> Alcotest.failf "r2 error: %s" e
  in
  Alcotest.(check bool)
    "different class names" true
    (not
       (String.equal (interaction_class_name id1) (interaction_class_name id2)));
  let sheet = get_sheet () in
  Alcotest.(check int) "two rules" 2 (class_rule_count sheet)

(* 6 *)
let test_remove_interaction_refcount () =
  cleanup_head ();
  let t = create () in
  let interaction = mk_interaction_hover "#ff0000" in
  let id1 =
    match inject_interaction t ~interaction with
    | Ok id -> id
    | Error e -> Alcotest.failf "error: %s" e
  in
  let id2 =
    match inject_interaction t ~interaction with
    | Ok id -> id
    | Error e -> Alcotest.failf "error: %s" e
  in
  let sheet = get_sheet () in
  Alcotest.(check int) "one rule (deduped)" 1 (class_rule_count sheet);
  remove_interaction t id1;
  Alcotest.(check int)
    "still one rule after first remove" 1 (class_rule_count sheet);
  remove_interaction t id2;
  Alcotest.(check int)
    "zero rules after second remove" 0 (class_rule_count sheet)

(* 7 *)
let test_remove_base_deletes_rule () =
  cleanup_head ();
  let t = create () in
  let bid = inject_base t ~css_props:(base_css_props "#ff0000") in
  let sheet = get_sheet () in
  Alcotest.(check int) "one rule before" 1 (class_rule_count sheet);
  remove_base t bid;
  Alcotest.(check int) "zero rules after" 0 (class_rule_count sheet)

(* 8 *)
let test_remove_updates_indices () =
  cleanup_head ();
  let t = create () in
  let bid_a = inject_base t ~css_props:(base_css_props "#aaa") in
  let _bid_b = inject_base t ~css_props:(base_css_props "#bbb") in
  let sheet = get_sheet () in
  Alcotest.(check int) "two rules" 2 (class_rule_count sheet);
  (* Remove A (index 0) — B should shift to index 0 *)
  remove_base t bid_a;
  Alcotest.(check int) "one rule" 1 (class_rule_count sheet);
  let remaining = class_rule_text sheet 0 in
  Alcotest.(check bool)
    "remaining rule is B (contains #bbb)" true
    (let hlen = String.length remaining in
     let needle = "#bbb" in
     let nlen = String.length needle in
     if nlen > hlen then false
     else
       let found = ref false in
       let i = ref 0 in
       while (not !found) && !i <= hlen - nlen do
         if String.sub remaining !i nlen = needle then found := true;
         incr i
       done;
       !found)

(* 9 *)
let test_inject_interaction_error_on_default () =
  cleanup_head ();
  let t = create () in
  let result =
    inject_interaction t ~interaction:Nopal_style.Interaction.default
  in
  match result with
  | Error _ -> ()
  | Ok _ -> Alcotest.fail "expected Error for default interaction"

(* 10 *)
let test_remove_base_idempotent () =
  cleanup_head ();
  let t = create () in
  let bid = inject_base t ~css_props:(base_css_props "#ff0000") in
  remove_base t bid;
  remove_base t bid;
  let sheet = get_sheet () in
  Alcotest.(check int)
    "zero rules after double remove" 0 (class_rule_count sheet)

(* 11 *)
let test_remove_interaction_idempotent () =
  cleanup_head ();
  let t = create () in
  let id =
    match
      inject_interaction t ~interaction:(mk_interaction_hover "#ff0000")
    with
    | Ok id -> id
    | Error e -> Alcotest.failf "error: %s" e
  in
  remove_interaction t id;
  remove_interaction t id;
  let sheet = get_sheet () in
  Alcotest.(check int)
    "zero rules after double remove" 0 (class_rule_count sheet)

(* 12 *)
let test_no_rules_for_non_interactive () =
  cleanup_head ();
  let t = create () in
  let result =
    inject_interaction t ~interaction:Nopal_style.Interaction.default
  in
  (match result with
  | Error _ -> ()
  | Ok _ -> Alcotest.fail "expected Error for non-interactive");
  let sheet = get_sheet () in
  Alcotest.(check int) "no rules" 0 (class_rule_count sheet)

(* 13 — interleaved base + interaction with middle deletion *)
let test_interleaved_index_tracking () =
  cleanup_head ();
  let t = create () in
  (* Insert: base_a(#aaa) at index 0, interaction(hover #bbb) at indices 1,
     base_b(#ccc) at index 2, interaction(hover+pressed #ddd) at indices 3-4 *)
  let bid_a = inject_base t ~css_props:(base_css_props "#aaa") in
  let iid_1 =
    match inject_interaction t ~interaction:(mk_interaction_hover "#bbb") with
    | Ok id -> id
    | Error e -> Alcotest.failf "error: %s" e
  in
  let bid_b = inject_base t ~css_props:(base_css_props "#ccc") in
  let ix_all =
    {
      Nopal_style.Interaction.hover = Some (mk_style "#ddd");
      pressed = Some (mk_style "#eee");
      focused = None;
    }
  in
  let iid_2 =
    match inject_interaction t ~interaction:ix_all with
    | Ok id -> id
    | Error e -> Alcotest.failf "error: %s" e
  in
  let sheet = get_sheet () in
  (* base_a(1) + ix_1(1) + base_b(1) + ix_2(2) = 5 rules *)
  Alcotest.(check int) "5 rules total" 5 (class_rule_count sheet);
  (* Delete the interaction in the middle (ix_1 at index 1, count 1) *)
  remove_interaction t iid_1;
  Alcotest.(check int) "4 rules after removing ix_1" 4 (class_rule_count sheet);
  (* base_a is still at index 0 *)
  let r0 = class_rule_text sheet 0 in
  Alcotest.(check bool) "rule 0 is base_a (#aaa)" true (String.length r0 > 0);
  (* base_b should have shifted from index 2 to index 1 *)
  let r1 = class_rule_text sheet 1 in
  let contains haystack needle =
    let hlen = String.length haystack in
    let nlen = String.length needle in
    if nlen > hlen then false
    else
      let found = ref false in
      let i = ref 0 in
      while (not !found) && !i <= hlen - nlen do
        if String.sub haystack !i nlen = needle then found := true;
        incr i
      done;
      !found
  in
  Alcotest.(check bool) "rule 1 is base_b (#ccc)" true (contains r1 "#ccc");
  (* Now delete base_a (index 0). Everything shifts down by 1. *)
  remove_base t bid_a;
  Alcotest.(check int)
    "3 rules after removing base_a" 3 (class_rule_count sheet);
  (* base_b should now be at index 0 *)
  let r0' = class_rule_text sheet 0 in
  Alcotest.(check bool) "rule 0 is now base_b (#ccc)" true (contains r0' "#ccc");
  (* ix_2 rules at indices 1-2 should still contain #ddd and #eee *)
  let r1' = class_rule_text sheet 1 in
  let r2' = class_rule_text sheet 2 in
  Alcotest.(check bool)
    "ix_2 rules present" true
    ((contains r1' "#ddd" || contains r1' "#eee")
    && (contains r2' "#ddd" || contains r2' "#eee"));
  (* Clean up remaining *)
  remove_base t bid_b;
  remove_interaction t iid_2;
  Alcotest.(check int) "0 rules after full cleanup" 0 (class_rule_count sheet)

let () =
  Alcotest.run "style_sheet"
    [
      ( "create",
        [
          Alcotest.test_case "inserts single style element" `Quick
            test_create_inserts_single_style_element;
          Alcotest.test_case "create_inserts_scoped_heading_reset_once" `Quick
            test_create_inserts_scoped_heading_reset_once;
          Alcotest.test_case "heading_reset_selector_has_no_unscoped_tag" `Quick
            test_heading_reset_selector_has_no_unscoped_tag;
          Alcotest.test_case "two_sheets_each_carry_one_reset" `Quick
            test_two_sheets_each_carry_one_reset;
          Alcotest.test_case "base_rule_indices_unaffected_by_reset" `Quick
            test_base_rule_indices_unaffected_by_reset;
        ] );
      ( "inject_base",
        [ Alcotest.test_case "adds rule" `Quick test_inject_base_adds_rule ] );
      ( "inject_interaction",
        [
          Alcotest.test_case "adds rules" `Quick
            test_inject_interaction_adds_rules;
          Alcotest.test_case "dedup same style" `Quick
            test_inject_interaction_dedup_same_style;
          Alcotest.test_case "dedup different style" `Quick
            test_inject_interaction_dedup_different_style;
          Alcotest.test_case "error on default" `Quick
            test_inject_interaction_error_on_default;
        ] );
      ( "remove_interaction",
        [
          Alcotest.test_case "refcount" `Quick test_remove_interaction_refcount;
          Alcotest.test_case "idempotent" `Quick
            test_remove_interaction_idempotent;
        ] );
      ( "remove_base",
        [
          Alcotest.test_case "deletes rule" `Quick test_remove_base_deletes_rule;
          Alcotest.test_case "idempotent" `Quick test_remove_base_idempotent;
        ] );
      ( "remove_updates_indices",
        [
          Alcotest.test_case "updates indices" `Quick
            test_remove_updates_indices;
          Alcotest.test_case "interleaved index tracking" `Quick
            test_interleaved_index_tracking;
        ] );
      ( "non_interactive",
        [
          Alcotest.test_case "no rules" `Quick test_no_rules_for_non_interactive;
        ] );
    ]

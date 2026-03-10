type rule_slot = {
  mutable start_index : int;
  (* mutable: shifts when rules before this slot are deleted *)
  count : int;
}

type interaction_entry = {
  class_name : string;
  css_key : string;
  mutable refcount : int;
  (* mutable: incremented/decremented on share/release *)
  slots : rule_slot;
  (* rule_slot.start_index is mutable — shifts on prior deletions *)
  mutable ie_removed : bool;
      (* mutable: set true after all refs released and rules deleted *)
}

type base_entry = {
  class_name : string;
  entry_key : int;
  (* immutable: the counter value used as key in base_entries hashtable,
     stored here so remove_base can evict the entry *)
  slot : rule_slot;
  (* rule_slot.start_index is mutable — shifts on prior deletions *)
  mutable removed : bool;
      (* mutable: set true after removal, prevents double-free *)
}

type t = {
  sheet : Jv.t;
  mutable counter : int;
  (* mutable: monotonic counter incremented on each inject call *)
  interaction_cache : (string, interaction_entry) Hashtbl.t;
  base_entries : (int, base_entry) Hashtbl.t;
  (* id -> base_entry, for index adjustment on deletion *)
  mutable total_rules : int;
      (* mutable: current count of rules in the stylesheet *)
}

type base_id = base_entry
type interaction_id = interaction_entry

let create () =
  let doc = Jv.get Jv.global "document" in
  let head = Jv.get doc "head" in
  let style_el = Jv.call doc "createElement" [| Jv.of_string "style" |] in
  Jv.call style_el "setAttribute"
    [| Jv.of_string "data-nopal"; Jv.of_string "" |]
  |> ignore;
  ignore (Jv.call head "appendChild" [| style_el |]);
  let sheet = Jv.get style_el "sheet" in
  {
    sheet;
    counter = 0;
    interaction_cache = Hashtbl.create 16;
    base_entries = Hashtbl.create 16;
    total_rules = 0;
  }

let adjust_indices_after_delete t deleted_start deleted_count =
  Hashtbl.iter
    (fun _k (entry : interaction_entry) ->
      if (not entry.ie_removed) && entry.slots.start_index > deleted_start then
        entry.slots.start_index <- entry.slots.start_index - deleted_count)
    t.interaction_cache;
  Hashtbl.iter
    (fun _k (entry : base_entry) ->
      if (not entry.removed) && entry.slot.start_index > deleted_start then
        entry.slot.start_index <- entry.slot.start_index - deleted_count)
    t.base_entries

let inject_base t ~css_props =
  let n = t.counter in
  t.counter <- n + 1;
  let class_name = Printf.sprintf "_nopal_b_%d" n in
  let rule_text = Style_css.base_class_rule ~class_name css_props in
  let count =
    match rule_text with
    | "" -> 0
    | _ ->
        let idx = t.total_rules in
        ignore
          (Jv.call t.sheet "insertRule"
             [| Jv.of_string rule_text; Jv.of_int idx |]);
        1
  in
  let entry =
    {
      class_name;
      entry_key = n;
      slot = { start_index = t.total_rules; count };
      removed = false;
    }
  in
  t.total_rules <- t.total_rules + count;
  Hashtbl.replace t.base_entries n entry;
  entry

let inject_interaction t ~interaction =
  if not (Nopal_style.Interaction.has_any interaction) then
    Error "interaction has no states"
  else begin
    let n = t.counter in
    t.counter <- n + 1;
    let class_name = Printf.sprintf "_nopal_ix_%d" n in
    let css_text = Style_css.interaction_rules ~class_name interaction in
    let normalized = Style_css.normalize_key css_text class_name in
    match Hashtbl.find_opt t.interaction_cache normalized with
    | Some existing ->
        existing.refcount <- existing.refcount + 1;
        Ok existing
    | None ->
        let start_index = t.total_rules in
        let individual_rules = Style_css.split_css_rules css_text in
        List.iteri
          (fun i rule ->
            ignore
              (Jv.call t.sheet "insertRule"
                 [| Jv.of_string rule; Jv.of_int (start_index + i) |]))
          individual_rules;
        let count = List.length individual_rules in
        let entry =
          {
            class_name;
            css_key = normalized;
            refcount = 1;
            slots = { start_index; count };
            ie_removed = false;
          }
        in
        t.total_rules <- t.total_rules + count;
        Hashtbl.replace t.interaction_cache normalized entry;
        Ok entry
  end

let base_class_name (bid : base_id) = bid.class_name
let interaction_class_name (iid : interaction_id) = iid.class_name

let remove_base t (bid : base_id) =
  if not bid.removed then begin
    let start = bid.slot.start_index in
    let count = bid.slot.count in
    (* Delete rules from stylesheet in reverse order to keep indices stable *)
    for i = count - 1 downto 0 do
      Jv.call t.sheet "deleteRule" [| Jv.of_int (start + i) |] |> ignore
    done;
    bid.removed <- true;
    t.total_rules <- t.total_rules - count;
    Hashtbl.remove t.base_entries bid.entry_key;
    adjust_indices_after_delete t start count
  end

let remove_interaction t (iid : interaction_id) =
  if not iid.ie_removed then begin
    iid.refcount <- iid.refcount - 1;
    if iid.refcount <= 0 then begin
      let start = iid.slots.start_index in
      let count = iid.slots.count in
      for i = count - 1 downto 0 do
        Jv.call t.sheet "deleteRule" [| Jv.of_int (start + i) |] |> ignore
      done;
      iid.ie_removed <- true;
      t.total_rules <- t.total_rules - count;
      Hashtbl.remove t.interaction_cache iid.css_key;
      adjust_indices_after_delete t start count
    end
  end

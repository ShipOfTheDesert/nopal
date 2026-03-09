type class_id = {
  name : string;
  style_el : Jv.t;
  mutable removed : bool;
      (* mutable: set to true after remove to make double-remove a no-op *)
}

type t = {
  doc : Jv.t;
  head : Jv.t;
  mutable counter : int;
      (* mutable: monotonic counter incremented on each inject call *)
}

let create () =
  let doc = Jv.get Jv.global "document" in
  let head = Jv.get doc "head" in
  { doc; head; counter = 0 }

let inject t ~interaction =
  if not (Nopal_style.Interaction.has_any interaction) then
    Error "interaction has no states"
  else begin
    let n = t.counter in
    t.counter <- n + 1;
    let name = Printf.sprintf "_nopal_ix_%d" n in
    let style_el = Jv.call t.doc "createElement" [| Jv.of_string "style" |] in
    let css = Style_css.interaction_rules ~class_name:name interaction in
    Jv.set style_el "textContent" (Jv.of_string css);
    ignore (Jv.call t.head "appendChild" [| style_el |]);
    Ok { name; style_el; removed = false }
  end

let class_name cid = cid.name

let remove t cid =
  if not cid.removed then begin
    ignore (Jv.call t.head "removeChild" [| cid.style_el |]);
    cid.removed <- true
  end

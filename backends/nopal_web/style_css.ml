open Nopal_style.Style

type css_prop = { property : string; value : string }

let color_to_css c =
  match c with
  | Rgba { r; g; b; a } -> Printf.sprintf "rgba(%d,%d,%d,%g)" r g b a
  | Hex s -> s
  | Named s -> s
  | Transparent -> "transparent"

let border_style_to_css s =
  match s with
  | Solid -> "solid"
  | Dashed -> "dashed"
  | Dotted -> "dotted"
  | No_border -> "none"

let size_to_css s =
  match s with
  | Fill -> "100%"
  | Hug ->
      ""
      (* Hug = content-sized: no CSS property needed. The caller suppresses
         empty strings so Hug produces no width/height in the output. *)
  | Fixed f -> Printf.sprintf "%gpx" f
  | Fraction f -> Printf.sprintf "%g%%" (f *. 100.)

let align_to_justify a =
  match a with
  | Start -> "flex-start"
  | Center -> "center"
  | End_ -> "flex-end"
  | Stretch -> "stretch"
  | Space_between -> "space-between"

let align_to_items a =
  (* NOTE: Space_between is not a valid CSS value for align-items. The shared
     align type in nopal_style permits it, but no current view code uses it
     in cross_align. Flag for nopal_style follow-up. *)
  match a with
  | Start -> "flex-start"
  | Center -> "center"
  | End_ -> "flex-end"
  | Stretch -> "stretch"
  | Space_between -> "space-between"

let of_text (text : Nopal_style.Text.t) =
  let acc = [] in
  let add acc property value = { property; value } :: acc in
  let acc =
    match text.font_family with
    | Some f -> add acc "font-family" (Nopal_style.Font.family_to_css_string f)
    | None -> acc
  in
  let acc =
    match text.font_size with
    | Some s -> add acc "font-size" (Printf.sprintf "%grem" s)
    | None -> acc
  in
  let acc =
    match text.font_weight with
    | Some w -> add acc "font-weight" (Nopal_style.Font.weight_to_css_string w)
    | None -> acc
  in
  let acc =
    match text.italic with
    | Some true -> add acc "font-style" "italic"
    | Some false -> add acc "font-style" "normal"
    | None -> acc
  in
  let acc =
    match text.line_height with
    | Some Nopal_style.Text.Lh_normal -> add acc "line-height" "normal"
    | Some (Nopal_style.Text.Lh_multiplier m) ->
        add acc "line-height" (Printf.sprintf "%g" m)
    | Some (Nopal_style.Text.Lh_px px) ->
        add acc "line-height" (Printf.sprintf "%gpx" px)
    | None -> acc
  in
  let acc =
    match text.letter_spacing with
    | Some Nopal_style.Text.Ls_normal -> add acc "letter-spacing" "normal"
    | Some (Nopal_style.Text.Ls_em e) ->
        add acc "letter-spacing" (Printf.sprintf "%gem" e)
    | None -> acc
  in
  let acc =
    match text.text_align with
    | Some Nopal_style.Text.Align_left -> add acc "text-align" "left"
    | Some Nopal_style.Text.Align_center -> add acc "text-align" "center"
    | Some Nopal_style.Text.Align_right -> add acc "text-align" "right"
    | Some Nopal_style.Text.Align_justify -> add acc "text-align" "justify"
    | None -> acc
  in
  let acc =
    match text.text_decoration with
    | Some Nopal_style.Text.Underline -> add acc "text-decoration" "underline"
    | Some Nopal_style.Text.Line_through ->
        add acc "text-decoration" "line-through"
    | Some Nopal_style.Text.Overline -> add acc "text-decoration" "overline"
    | Some Nopal_style.Text.No_decoration -> add acc "text-decoration" "none"
    | None -> acc
  in
  let acc =
    match text.text_transform with
    | Some Nopal_style.Text.Uppercase -> add acc "text-transform" "uppercase"
    | Some Nopal_style.Text.Lowercase -> add acc "text-transform" "lowercase"
    | Some Nopal_style.Text.Capitalize -> add acc "text-transform" "capitalize"
    | Some Nopal_style.Text.No_transform -> add acc "text-transform" "none"
    | None -> acc
  in
  let acc =
    match text.text_overflow with
    | Some Nopal_style.Text.Ellipsis ->
        let acc = add acc "text-overflow" "ellipsis" in
        let acc = add acc "overflow" "hidden" in
        add acc "white-space" "nowrap"
    | Some Nopal_style.Text.Clip -> add acc "text-overflow" "clip"
    | Some Nopal_style.Text.Wrap -> add acc "white-space" "normal"
    | Some Nopal_style.Text.No_wrap -> add acc "white-space" "nowrap"
    | None -> acc
  in
  List.rev acc

let of_style (style : t) =
  let layout = style.layout in
  let paint = style.paint in
  let acc = [] in
  let add acc property value = { property; value } :: acc in
  (* Layout properties — emit per-field, only when Some *)
  let acc =
    match layout.direction with
    | Some Row_dir -> add acc "flex-direction" "row"
    | Some Column_dir -> add acc "flex-direction" "column"
    | None -> acc
  in
  let acc =
    match layout.main_align with
    | Some a -> add acc "justify-content" (align_to_justify a)
    | None -> acc
  in
  let acc =
    match layout.cross_align with
    | Some a -> add acc "align-items" (align_to_items a)
    | None -> acc
  in
  let acc =
    match layout.wrap with
    | Some true -> add acc "flex-wrap" "wrap"
    | Some false
    | None ->
        acc
  in
  let acc =
    match layout.gap with
    | Some g when not (Float.equal g 0.) ->
        add acc "gap" (Printf.sprintf "%gpx" g)
    | Some _
    | None ->
        acc
  in
  let acc =
    match
      ( layout.padding_top,
        layout.padding_right,
        layout.padding_bottom,
        layout.padding_left )
    with
    | Some pt, Some pr, Some pb, Some pl ->
        if
          not
            (Float.equal pt 0.
            && Float.equal pr 0.
            && Float.equal pb 0.
            && Float.equal pl 0.)
        then
          add acc "padding" (Printf.sprintf "%gpx %gpx %gpx %gpx" pt pr pb pl)
        else acc
    | _ ->
        (* Emit individual padding properties for partially-set padding *)
        let acc =
          match layout.padding_top with
          | Some v when not (Float.equal v 0.) ->
              add acc "padding-top" (Printf.sprintf "%gpx" v)
          | _ -> acc
        in
        let acc =
          match layout.padding_right with
          | Some v when not (Float.equal v 0.) ->
              add acc "padding-right" (Printf.sprintf "%gpx" v)
          | _ -> acc
        in
        let acc =
          match layout.padding_bottom with
          | Some v when not (Float.equal v 0.) ->
              add acc "padding-bottom" (Printf.sprintf "%gpx" v)
          | _ -> acc
        in
        let acc =
          match layout.padding_left with
          | Some v when not (Float.equal v 0.) ->
              add acc "padding-left" (Printf.sprintf "%gpx" v)
          | _ -> acc
        in
        acc
  in
  let acc =
    match layout.width with
    | Some s ->
        let w = size_to_css s in
        if not (String.equal w "") then add acc "width" w else acc
    | None -> acc
  in
  let acc =
    match layout.height with
    | Some s ->
        let h = size_to_css s in
        if not (String.equal h "") then add acc "height" h else acc
    | None -> acc
  in
  let acc =
    match layout.flex_grow with
    | Some g -> add acc "flex-grow" (Printf.sprintf "%g" g)
    | None -> acc
  in
  (* Paint properties — only emit when different from default *)
  let acc =
    if not (equal_paint paint default_paint) then
      let acc =
        match paint.background with
        | Some c -> add acc "background-color" (color_to_css c)
        | None -> acc
      in
      let acc =
        match paint.border with
        | Some b ->
            let acc =
              add acc "border"
                (Printf.sprintf "%gpx %s %s" b.width
                   (border_style_to_css b.style)
                   (color_to_css b.color))
            in
            if not (Float.equal b.radius 0.) then
              add acc "border-radius" (Printf.sprintf "%gpx" b.radius)
            else acc
        | None -> acc
      in
      let acc =
        if not (Float.equal paint.opacity 1.0) then
          add acc "opacity" (Printf.sprintf "%g" paint.opacity)
        else acc
      in
      let acc =
        match paint.shadow with
        | Some s ->
            add acc "box-shadow"
              (Printf.sprintf "%gpx %gpx %gpx %s" s.x s.y s.blur
                 (color_to_css s.color))
        | None -> acc
      in
      let acc =
        match paint.overflow with
        | Hidden -> add acc "overflow" "hidden"
        | Visible -> acc
      in
      acc
    else acc
  in
  (* Text properties — skip when all fields are None (common case) *)
  let acc =
    if not (Nopal_style.Text.equal style.text Nopal_style.Text.default) then
      let text_props = of_text style.text in
      List.rev_append text_props acc
    else acc
  in
  List.rev acc

let to_inline_string props =
  String.concat ";"
    (List.map (fun { property; value } -> property ^ ":" ^ value) props)

let apply_cursor el cursor =
  let value =
    match cursor with
    | Some c -> Jstr.v (Nopal_style.Cursor.to_css_string c)
    | None -> Jstr.v ""
  in
  Brr.El.set_inline_style (Jstr.v "cursor") value el

let to_rule_body props =
  String.concat ""
    (List.map (fun { property; value } -> property ^ ":" ^ value ^ ";") props)

let base_class_rule ~class_name props =
  match props with
  | [] -> ""
  | _ -> "." ^ class_name ^ "{" ^ to_rule_body props ^ "}"

let split_css_rules css =
  let len = String.length css in
  let rec scan_rule i depth =
    if i >= len then i
    else
      match css.[i] with
      | '{' -> scan_rule (i + 1) (depth + 1)
      | '}' when depth = 1 -> i + 1
      | '}' -> scan_rule (i + 1) (depth - 1)
      | _ -> scan_rule (i + 1) depth
  in
  let rec go i acc =
    if i >= len then List.rev acc
    else
      let rule_end = scan_rule i 0 in
      if rule_end > i then go rule_end (String.sub css i (rule_end - i) :: acc)
      else List.rev acc
  in
  go 0 []

let normalize_key css class_name =
  let clen = String.length class_name in
  let slen = String.length css in
  let placeholder = "__NOPAL_IX__" in
  let buf = Buffer.create slen in
  let rec go i =
    if i >= slen then ()
    else if i + clen <= slen && String.sub css i clen = class_name then begin
      Buffer.add_string buf placeholder;
      go (i + clen)
    end
    else begin
      Buffer.add_char buf css.[i];
      go (i + 1)
    end
  in
  go 0;
  Buffer.contents buf

let interaction_rules ~class_name (interaction : Nopal_style.Interaction.t) =
  let buf = Buffer.create 128 in
  let add_rule selector style =
    let props = of_style style in
    match props with
    | [] -> ()
    | _ ->
        let body = to_rule_body props in
        Buffer.add_string buf (selector ^ "{" ^ body ^ "}")
  in
  (* Precedence by rule order: hover first, focused second, pressed last.
     Later rules win for equal specificity. *)
  (match interaction.hover with
  | Some style -> add_rule ("." ^ class_name ^ ":hover") style
  | None -> ());
  (match interaction.focused with
  | Some style -> add_rule ("." ^ class_name ^ ":focus-visible") style
  | None -> ());
  (match interaction.pressed with
  | Some style -> add_rule ("." ^ class_name ^ ":active") style
  | None -> ());
  Buffer.contents buf

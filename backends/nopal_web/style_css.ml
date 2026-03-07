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

let of_style (style : t) =
  let layout = style.layout in
  let paint = style.paint in
  let acc = [] in
  let add acc property value = { property; value } :: acc in
  (* Layout properties — only emit when different from default.
     TODO(perf): this evaluates all layout fields when any single one differs.
     A per-field comparison would emit only changed properties. See ROADMAP.md
     "of_style Per-Field Comparison". *)
  let acc =
    if not (equal_layout layout default_layout) then
      let acc =
        match layout.direction with
        | Row_dir -> add acc "flex-direction" "row"
        | Column_dir -> acc
      in
      let acc =
        match layout.main_align with
        | Start -> acc
        | other -> add acc "justify-content" (align_to_justify other)
      in
      let acc =
        match layout.cross_align with
        | Start -> acc
        | other -> add acc "align-items" (align_to_items other)
      in
      let acc = if layout.wrap then add acc "flex-wrap" "wrap" else acc in
      let acc =
        if not (Float.equal layout.gap 0.) then
          add acc "gap" (Printf.sprintf "%gpx" layout.gap)
        else acc
      in
      let has_padding =
        not
          (Float.equal layout.padding_top 0.
          && Float.equal layout.padding_right 0.
          && Float.equal layout.padding_bottom 0.
          && Float.equal layout.padding_left 0.)
      in
      let acc =
        if has_padding then
          add acc "padding"
            (Printf.sprintf "%gpx %gpx %gpx %gpx" layout.padding_top
               layout.padding_right layout.padding_bottom layout.padding_left)
        else acc
      in
      let acc =
        let w = size_to_css layout.width in
        if not (String.equal w "") then add acc "width" w else acc
      in
      let acc =
        let h = size_to_css layout.height in
        if not (String.equal h "") then add acc "height" h else acc
      in
      let acc =
        match layout.flex_grow with
        | Some g -> add acc "flex-grow" (Printf.sprintf "%g" g)
        | None -> acc
      in
      acc
    else acc
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
  List.rev acc

let to_inline_string props =
  String.concat ";"
    (List.map (fun { property; value } -> property ^ ":" ^ value) props)

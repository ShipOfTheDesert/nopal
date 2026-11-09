module E = Nopal_element.Element
module S = Nopal_style.Style

type segment = { value : string; text : string }

let segment ~value text = { value; text }

type 'msg config = {
  label : string;
  segments : segment list;
  selected : string;
  on_select : string -> 'msg;
  id : string option;
  name : string option;
  attrs : (string * string) list;
  group_style : Nopal_style.Style.t option;
  label_style : Nopal_style.Style.t option;
  segments_style : Nopal_style.Style.t option;
  segment_style : Nopal_style.Style.t option;
  segment_label_style : Nopal_style.Style.t option;
  selected_segment_style : Nopal_style.Style.t option;
  selected_segment_label_style : Nopal_style.Style.t option;
  divider_style : Nopal_style.Style.t option;
  segment_interaction : Nopal_style.Interaction.t option;
}

let make ~label ~segments ~selected ~on_select =
  {
    label;
    segments;
    selected;
    on_select;
    id = None;
    name = None;
    attrs = [];
    group_style = None;
    label_style = None;
    segments_style = None;
    segment_style = None;
    segment_label_style = None;
    selected_segment_style = None;
    selected_segment_label_style = None;
    divider_style = None;
    segment_interaction = None;
  }

let with_id id config = { config with id = Some id }
let with_name name config = { config with name = Some name }
let with_attrs attrs config = { config with attrs }
let with_group_style style config = { config with group_style = Some style }
let with_label_style style config = { config with label_style = Some style }

let with_segments_style style config =
  { config with segments_style = Some style }

let with_segment_style style config = { config with segment_style = Some style }

let with_segment_label_style style config =
  { config with segment_label_style = Some style }

let with_selected_segment_style style config =
  { config with selected_segment_style = Some style }

let with_selected_segment_label_style style config =
  { config with selected_segment_label_style = Some style }

let with_divider_style style config = { config with divider_style = Some style }

let with_segment_interaction interaction config =
  { config with segment_interaction = Some interaction }

let semantics config =
  Radio_semantics.make ~id:config.id ~label:config.label ~name:config.name

let control_id config = Radio_semantics.control_id (semantics config)

let option_id config ~value =
  Radio_semantics.option_id (semantics config) ~value

let replacing ~plain selected =
  match selected with
  | Some _ -> selected
  | None -> plain

let rec with_dividers divider = function
  | [] -> []
  | [ last ] -> [ last ]
  | segment :: (_ :: _ as rest) ->
      segment :: divider :: with_dividers divider rest

let filled fill style = fill (Option.value style ~default:S.default)

let row_by_default =
  S.with_layout (fun l ->
      match l.S.direction with
      | Some (_ : S.direction) -> l
      | None -> { l with S.direction = Some S.Row_dir })

let positioned =
  S.with_layout (fun l ->
      match l.S.position with
      | Some (_ : S.position) -> l
      | None -> { l with S.position = Some S.Pos_relative })

let growing =
  S.with_layout (fun l ->
      match l.S.flex_grow with
      | Some (_ : float) -> l
      | None -> { l with S.flex_grow = Some 1. })

let raised_ring (interaction : Nopal_style.Interaction.t) =
  let raise_layer =
    S.with_layout (fun l ->
        match l.S.z_index with
        | Some (_ : int) -> l
        | None -> { l with S.z_index = Some 1 })
  in
  {
    interaction with
    focused_within = Option.map raise_layer interaction.focused_within;
  }

let segments_direction segments_style =
  match Option.bind segments_style (fun s -> s.S.layout.S.direction) with
  | Some S.Column_dir -> S.Column_dir
  | Some S.Row_dir
  | None ->
      S.Row_dir

let inner_radii segments_style : S.corners =
  match Option.bind segments_style (fun s -> s.S.paint.S.border) with
  | None ->
      { top_left = 0.; top_right = 0.; bottom_right = 0.; bottom_left = 0. }
  | Some b ->
      let outer : S.corners =
        match b.corners with
        | Some c -> c
        | None ->
            {
              top_left = b.radius;
              top_right = b.radius;
              bottom_right = b.radius;
              bottom_left = b.radius;
            }
      in
      let painted_width =
        match b.style with
        | S.No_border -> 0.
        | S.Solid
        | S.Dashed
        | S.Dotted ->
            b.width
      in
      let inside r = Float.max 0. (r -. painted_width) in
      {
        top_left = inside outer.top_left;
        top_right = inside outer.top_right;
        bottom_right = inside outer.bottom_right;
        bottom_left = inside outer.bottom_left;
      }

let end_corners ~direction ~first ~last (r : S.corners) : S.corners option =
  let keep at_end radius = if at_end then radius else 0. in
  match (first, last) with
  | false, false -> None
  | true, true
  | true, false
  | false, true -> (
      match direction with
      | S.Row_dir ->
          Some
            {
              top_left = keep first r.top_left;
              bottom_left = keep first r.bottom_left;
              top_right = keep last r.top_right;
              bottom_right = keep last r.bottom_right;
            }
      | S.Column_dir ->
          Some
            {
              top_left = keep first r.top_left;
              top_right = keep first r.top_right;
              bottom_left = keep last r.bottom_left;
              bottom_right = keep last r.bottom_right;
            })

let with_corners corners =
  S.with_paint (fun p ->
      let border : S.border =
        match p.S.border with
        | Some b -> { b with corners = Some corners }
        | None -> { S.default_border with corners = Some corners }
      in
      { p with S.border = Some border })

let view config =
  let group = semantics config in
  let direction = segments_direction config.segments_style in
  let radii = inner_radii config.segments_style in
  let interaction = Option.map raised_ring config.segment_interaction in
  let last_index = List.length config.segments - 1 in
  let render_segment index seg =
    let segment_style, label_style =
      if String.equal seg.value config.selected then
        ( replacing ~plain:config.segment_style config.selected_segment_style,
          replacing ~plain:config.segment_label_style
            config.selected_segment_label_style )
      else (config.segment_style, config.segment_label_style)
    in
    let segment_style =
      let style = row_by_default (filled positioned segment_style) in
      match
        end_corners ~direction ~first:(index = 0) ~last:(index = last_index)
          radii
      with
      | Some corners -> with_corners corners style
      | None -> style
    in
    let radio =
      Radio_semantics.option_radio group ~value:seg.value
        ~selected:config.selected ~disabled:false
        ~presentation:Nopal_style.Presentation.Visually_hidden
        ~on_select:(Some config.on_select)
    in
    let label =
      Radio_semantics.option_label
        ~style:(filled growing label_style)
        group ~value:seg.value
        [ Text_node.of_style ~style:label_style seg.text ]
    in
    E.box ~style:segment_style ?interaction [ radio; label ]
  in
  let divider = E.box ?style:config.divider_style [] in
  let group_label =
    E.box ?style:config.label_style
      ~attrs:[ ("id", Radio_semantics.group_label_id group) ]
      [ Text_node.of_style ~style:config.label_style config.label ]
  in
  let segments_box =
    E.box
      ~style:(filled row_by_default config.segments_style)
      (with_dividers divider (List.mapi render_segment config.segments))
  in
  E.box ?style:config.group_style
    ~attrs:
      (Radio_semantics.group_attrs group
         ~naming:Radio_semantics.Named_by_visible_label ~attrs:config.attrs)
    [ group_label; segments_box ]

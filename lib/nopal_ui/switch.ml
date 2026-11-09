module E = Nopal_element.Element
module S = Nopal_style.Style
module I = Nopal_style.Interaction

type availability = Enabled | Disabled of { reason : string }

(* One style for each state of a part that changes with the value. *)
type states = { off : S.t; on : S.t }

type 'msg t = {
  label : string;
  on : bool;
  on_toggle : bool -> 'msg;
  availability : availability;
  hint : 'msg E.t option;
  id : string option;
  attrs : (string * string) list;
  track : states;
  knob : states;
  disabled_track : states option;
  disabled_knob : states option;
  button_style : S.t option;
  row_style : S.t;
  label_style : S.t option;
  hint_style : S.t option;
  reason_style : S.t option;
  style : S.t;
  focus_ring : I.t;
}

let border ~width ~color ~radius : S.border =
  { width; style = S.Solid; color; radius; corners = None }

(* Every paint field is written, so no default behaviour rides along. *)
let paint ?background ?border ?shadow () : S.paint =
  { background; border; opacity = 1.0; shadow; overflow = S.Visible }

(* 36 by 16 content inside a 2px padding and a 2px border: 44 by 24 on the
   page, which holds the 16px knob with 2px clear of the border on every side.
   The direction and the alignment are set here as well as filled in, so the
   default reads complete on its own. *)
let track_style ~(main_align : S.align) background =
  {
    S.layout =
      {
        S.default_layout with
        direction = Some S.Row_dir;
        main_align = Some main_align;
        cross_align = Some S.Center;
        width = Some (S.Fixed 36.);
        height = Some (S.Fixed 16.);
        padding_top = Some 2.;
        padding_right = Some 2.;
        padding_bottom = Some 2.;
        padding_left = Some 2.;
      };
    paint =
      paint ~background
        ~border:(border ~width:2. ~color:(S.hex "#555555") ~radius:12.)
        ();
    text = S.default_text;
  }

let default_track =
  {
    off = track_style ~main_align:Start (S.hex "#cccccc");
    on = track_style ~main_align:End_ (S.hex "#00aa66");
  }

(* 14 by 14 content inside a 1px border: a 16px disc. *)
let knob_style =
  {
    S.layout =
      {
        S.default_layout with
        width = Some (S.Fixed 14.);
        height = Some (S.Fixed 14.);
      };
    paint =
      paint ~background:(S.hex "#ffffff")
        ~border:(border ~width:1. ~color:(S.hex "#333333") ~radius:8.)
        ();
    text = S.default_text;
  }

let default_knob = { off = knob_style; on = knob_style }

let default_row =
  {
    S.layout =
      {
        S.default_layout with
        direction = Some S.Row_dir;
        cross_align = Some S.Center;
        gap = Some 8.;
      };
    paint = paint ();
    text = S.default_text;
  }

let default_outer =
  {
    S.layout =
      { S.default_layout with direction = Some S.Column_dir; gap = Some 4. };
    paint = paint ();
    text = S.default_text;
  }

(* A ring drawn as a shadow, since a style has no outline: zero offset and zero
   blur, so the spread alone gives it its width. The button it lands on has no
   corners of its own, so the ring carries the default track's radius. *)
let default_focus_ring =
  {
    I.hover = None;
    pressed = None;
    focused =
      Some
        {
          S.layout = S.default_layout;
          paint =
            paint
              ~border:
                {
                  width = 0.;
                  style = S.No_border;
                  color = S.transparent;
                  radius = 12.;
                  corners = None;
                }
              ~shadow:
                {
                  x = 0.;
                  y = 0.;
                  blur = 0.;
                  spread = 2.;
                  color = S.hex "#1a73e8";
                }
              ();
          text = S.default_text;
        };
    focused_within = None;
  }

let make ~label ~on ~on_toggle =
  {
    label;
    on;
    on_toggle;
    availability = Enabled;
    hint = None;
    id = None;
    attrs = [];
    track = default_track;
    knob = default_knob;
    disabled_track = None;
    disabled_knob = None;
    button_style = None;
    row_style = default_row;
    label_style = None;
    hint_style = None;
    reason_style = None;
    style = default_outer;
    focus_ring = default_focus_ring;
  }

let with_availability availability t = { t with availability }
let with_hint hint t = { t with hint = Some hint }
let with_id id t = { t with id = Some id }
let with_attrs attrs t = { t with attrs }
let with_track_style ~off ~on t = { t with track = { off; on } }
let with_knob_style ~off ~on t = { t with knob = { off; on } }

let with_disabled_track_style ~off ~on t =
  { t with disabled_track = Some { off; on } }

let with_disabled_knob_style ~off ~on t =
  { t with disabled_knob = Some { off; on } }

let with_button_style style t = { t with button_style = Some style }
let with_row_style style t = { t with row_style = style }
let with_label_style style t = { t with label_style = Some style }
let with_hint_style style t = { t with hint_style = Some style }
let with_reason_style style t = { t with reason_style = Some style }
let with_style style t = { t with style }
let with_focus_ring interaction t = { t with focus_ring = interaction }
let control_id t = Slug.derive_id ~explicit:t.id ~label:t.label ()

let reason_id t =
  Slug.derive_id ~explicit:t.id ~label:t.label ~suffix:"reason" ()

let hint_id t = Slug.derive_id ~explicit:t.id ~label:t.label ~suffix:"hint" ()

(* The structural fill-ins. Each writes its value only where the caller's
   style holds no opinion, so a style naming its own value keeps it. *)
let fill current value =
  match current with
  | Some _ -> current
  | None -> Some value

let row_by_default =
  S.with_layout (fun l -> { l with S.direction = fill l.S.direction S.Row_dir })

(* The knob sits where the track aligns it, so a track style naming no
   alignment would freeze it: off fills in [Start] and on [End_]. *)
let positioning ~on =
  let main_align : S.align = if on then End_ else Start in
  S.with_layout (fun l ->
      {
        l with
        S.direction = fill l.S.direction S.Row_dir;
        main_align = fill l.S.main_align main_align;
      })

(* The track is the switch's look, so the platform's button chrome is cleared
   wherever the caller's button style is silent. *)
let without_chrome =
  let no_border : S.border =
    {
      width = 0.;
      style = S.No_border;
      color = S.transparent;
      radius = 0.;
      corners = None;
    }
  in
  fun style ->
    style
    |> S.with_paint (fun p ->
        {
          p with
          S.background = fill p.S.background S.transparent;
          border = fill p.S.border no_border;
        })
    |> S.with_layout (fun l ->
        {
          l with
          S.padding_top = fill l.S.padding_top 0.;
          padding_right = fill l.S.padding_right 0.;
          padding_bottom = fill l.S.padding_bottom 0.;
          padding_left = fill l.S.padding_left 0.;
        })

(* No opinion on any field: what the button carries when the caller sets no
   style, before the chrome is cleared. *)
let unstyled =
  { S.layout = S.default_layout; paint = paint (); text = S.default_text }

let for_state ~on (states : states) = if on then states.on else states.off

let view t =
  let id = control_id t in
  let reason =
    match t.availability with
    | Enabled -> None
    | Disabled { reason } -> Some reason
  in
  let reason_box =
    Option.map
      (fun reason ->
        E.box ?style:t.reason_style
          ~attrs:[ ("id", reason_id t) ]
          [ Text_node.of_style ~style:t.reason_style reason ])
      reason
  in
  let hint_box =
    Option.map
      (fun hint ->
        E.box ?style:t.hint_style ~attrs:[ ("id", hint_id t) ] [ hint ])
      t.hint
  in
  (* The reason first, then the hint: a reader hears why the switch is dead
     before the general guidance. Only boxes that render are named. *)
  let described_by =
    List.filter_map Fun.id
      [
        Option.map (fun (_ : string) -> reason_id t) reason;
        Option.map (fun (_ : 'msg E.t) -> hint_id t) t.hint;
      ]
  in
  let description =
    match described_by with
    | [] -> []
    | _ :: _ -> [ ("aria-describedby", String.concat " " described_by) ]
  in
  let switch = if t.on then E.Switch_on else E.Switch_off in
  (* A disabled part falls back to the enabled style for the same state:
     disabling changes no styling until the caller says otherwise. *)
  let track, knob =
    match reason with
    | None -> (t.track, t.knob)
    | Some (_ : string) ->
        ( Option.value t.disabled_track ~default:t.track,
          Option.value t.disabled_knob ~default:t.knob )
  in
  let button =
    E.button
      ~style:(without_chrome (Option.value t.button_style ~default:unstyled))
      ~interaction:t.focus_ring
      ~attrs:(("id", id) :: description)
      ~button_type:E.Push ~disabled:(Option.is_some reason) ~switch
      ~on_click:(t.on_toggle (not t.on))
      (E.box
         ~style:(positioning ~on:t.on (for_state ~on:t.on track))
         [ E.box ~style:(for_state ~on:t.on knob) [] ])
  in
  let row =
    E.box
      ~style:(row_by_default t.row_style)
      [
        E.label ?style:t.label_style ~control_id:id
          [ Text_node.of_style ~style:t.label_style t.label ];
        button;
      ]
  in
  (* [t.attrs] reaches this box only, so nothing a caller passes can replace
     the button's id, role, state or description. *)
  E.box ~style:t.style ~attrs:t.attrs
    (row :: List.filter_map Fun.id [ reason_box; hint_box ])

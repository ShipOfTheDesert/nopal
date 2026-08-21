open Nopal_element
open Nopal_style

type model = { marker : string; keys_enabled : bool; moves : int }

type msg =
  | Half_page_down
  | Half_page_up
  | Waypoint_advanced
  | Far_row_focused
  | Keys_toggled of bool

let container_id = "scroll-pane-viewport"
let paragraph_count = 32
let key_of_index index = Printf.sprintf "para-%02d" index
let row_keys = List.init paragraph_count key_of_index

(* Both waypoints sit well down the pane so reaching either is a real movement,
   and both stop short of the end so the half-viewport nudge that follows the
   reveal still has room to move. A waypoint at the top would make that nudge
   clamp to nothing, and the control would then exercise one writer on some
   presses and two on others. *)
let waypoint_keys = [ key_of_index 12; key_of_index 22 ]

(* The row the focus control aims at. Far enough down that it is not visible
   when the section loads — focusing a row already on screen moves nothing, and
   the stage this control exists to show would have nothing to show — and far
   enough from the end that the browser can align it without the pane clamping
   at its own maximum offset, which would put the pane somewhere neither writer
   asked for. *)
let focus_target_index = 16
let focus_target_id = "scroll-pane-focus-target"

let first_key =
  match row_keys with
  | key :: _ -> key
  | [] -> key_of_index 0

let filler =
  "Half-page keys move the viewport by a fraction of its own height, so this \
   paragraph does not have to be the same height as the one above it."

(* Heights vary on a five-paragraph cycle rather than growing with the index, so
   no arithmetic on a single paragraph height can predict where a paragraph
   starts. A uniform grid would let a fixed-row-height implementation pass this
   section. *)
let label_of index key =
  let repeats = 1 + (index * 2 mod 5) in
  String.concat " " (key :: List.init repeats (fun _ -> filler))

(* The cycle is over the waypoints alone, so the marker never returns to the
   first paragraph once the control has been used. Starting outside the cycle is
   what keeps the first render from moving the pane on page load. *)
let advance_waypoint marker keys =
  let wrap () =
    match keys with
    | first :: _ -> first
    | [] -> first_key
  in
  let rec step remaining =
    match remaining with
    | current :: (following :: _ as rest) ->
        if String.equal current marker then following else step rest
    | [ _ ]
    | [] ->
        wrap ()
  in
  step keys

let half_page_forward = Scroll_delta.viewports 0.5
let half_page_back = Scroll_delta.viewports (-0.5)

(* The focus control moves by a whole viewport where the chords move by half.
   The point of that control is that two writers of the same offset disagree and
   one of them wins, so the two candidate landings have to be impossible to
   confuse: a whole pane apart is the smallest movement that puts the position
   the movement alone would reach outside every position focus could leave the
   pane in, whatever alignment the browser's own scroll-into-view chooses. *)
let one_page_forward = Scroll_delta.viewports 1.0
let move_by delta = Nopal_mvu.Cmd.scroll_by container_id delta

let init () =
  ({ marker = first_key; keys_enabled = false; moves = 0 }, Nopal_mvu.Cmd.none)

let update model msg =
  match msg with
  | Half_page_down ->
      ({ model with moves = model.moves + 1 }, move_by half_page_forward)
  | Half_page_up ->
      ({ model with moves = model.moves + 1 }, move_by half_page_back)
  | Waypoint_advanced ->
      (* One update changing the revealed paragraph and asking for a relative
         movement of the same container. Both write the container's offset, and
         the backend applies the reveal first, so the pane comes to rest half a
         viewport back from the paragraph it was asked to show. *)
      ( {
          model with
          marker = advance_waypoint model.marker waypoint_keys;
          moves = model.moves + 1;
        },
        move_by half_page_back )
  | Far_row_focused ->
      (* The last stage of the order, and the one only a browser can settle. Two
         writers of the same offset leave this update: the relative movement is
         drained first and the focus after it, and the focus carries no
         [preventScroll], so the browser's own scroll-into-view has the final
         word and the pane comes to rest where focus put it rather than where
         the movement asked for. The revealed paragraph is deliberately left
         alone here, so exactly two of the three writers contend. *)
      ( { model with moves = model.moves + 1 },
        Nopal_mvu.Cmd.batch
          [ move_by one_page_forward; Nopal_mvu.Cmd.focus focus_target_id ] )
  | Keys_toggled keys_enabled ->
      ({ model with keys_enabled }, Nopal_mvu.Cmd.none)

let down_sub_key = "scroll-pane-down"
let up_sub_key = "scroll-pane-up"

let subscriptions model =
  if model.keys_enabled then
    Nopal_mvu.Sub.batch
      [
        Nopal_mvu.Sub.on_key down_sub_key ~key:"Ctrl+d" ~prevent:true
          Half_page_down;
        Nopal_mvu.Sub.on_key up_sub_key ~key:"Ctrl+u" ~prevent:true Half_page_up;
      ]
  else Nopal_mvu.Sub.none

let border_color = Style.hex "#dee2e6"

let container_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with height = Some (Fixed 220.0); width = Some (Fixed 360.0) })
  |> Style.with_paint (fun p ->
      {
        p with
        border =
          Some
            { width = 1.0; style = Solid; color = border_color; radius = 6.0 };
      })

let paragraph_style =
  Style.default
  |> Style.with_layout (fun l -> Style.padding 6.0 10.0 6.0 10.0 l)

let marked_paragraph_style =
  Style.default
  |> Style.with_layout (fun l -> Style.padding 6.0 10.0 6.0 10.0 l)
  |> Style.with_paint (fun p ->
      { p with background = Some (Style.hex "#e7f1fb") })

let control_row_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = Some 8.0; cross_align = Some Center })

(* One paragraph carries a focusable field, because [Cmd.focus] does nothing to
   a plain box: the row a focus names has to be something the platform will
   focus, which is the same shape the focus/keyboard section uses for its
   created-on-demand target. It holds no value and reports no change — it exists
   to be focused, and the section reads nothing back from it. *)
let paragraph_element ~marker index key =
  let style =
    if String.equal key marker then marked_paragraph_style else paragraph_style
  in
  let label = Element.text (label_of index key) in
  let children =
    if index = focus_target_index then
      [
        label;
        Element.input
          ~attrs:
            [
              ("id", focus_target_id);
              ("data-testid", "scroll-pane-focus-target");
            ]
          ~placeholder:"Focus target" "";
      ]
    else [ label ]
  in
  Element.keyed key
    (Element.box ~style
       ~attrs:[ ("data-testid", Printf.sprintf "scroll-pane-para-%d" index) ]
       children)

let view _vp model =
  let paragraphs =
    List.mapi
      (fun index key -> paragraph_element ~marker:model.marker index key)
      row_keys
  in
  Element.column
    ~attrs:[ ("data-testid", "scroll-pane-demo") ]
    [
      Element.row ~style:control_row_style
        [
          Element.checkbox
            ~attrs:[ ("data-field", "scroll-pane-keys") ]
            ~on_toggle:(fun enabled -> Keys_toggled enabled)
            model.keys_enabled;
          Element.text "Ctrl+D and Ctrl+U move the pane half a viewport";
        ];
      Element.row ~style:control_row_style
        [
          Element.button
            ~attrs:[ ("data-action", "scroll-pane-waypoint") ]
            ~on_click:Waypoint_advanced
            (Element.text "Reveal the next waypoint, then back off half a page");
        ];
      Element.row ~style:control_row_style
        [
          Element.button
            ~attrs:[ ("data-action", "scroll-pane-focus") ]
            ~on_click:Far_row_focused
            (Element.text "Move a whole page on, and focus a field further down");
        ];
      Element.box
        ~attrs:[ ("data-testid", "scroll-pane-readout") ]
        [
          Element.text
            (Printf.sprintf "Marker %s, %d movement(s) requested" model.marker
               model.moves);
        ];
      (* The pane carries its own id, so a request names it directly instead of
         reaching it through a wrapper around it. The reveal beside it is
         re-derived from the model on every view call and acted on only when it
         changes; the relative movements are commands and are acted on once
         each, which is why two identical presses move the pane twice. *)
      Element.scroll ~style:container_style
        ~attrs:
          [ ("id", container_id); ("data-testid", "scroll-pane-container") ]
        ~reveal:(Reveal.start model.marker)
        (* The inner column carries no padding of its own, so the first
           paragraph starts at offset zero and the marker's opening position is
           the position the pane is already in. Padding here would make the
           first render write a few pixels, which reads as a jump on load. *)
        (Element.column paragraphs);
    ]

let serialize_model model =
  Printf.sprintf "pane_marker=%S; pane_moves=%d; pane_keys=%b;" model.marker
    model.moves model.keys_enabled

let serialize_msg msg =
  match msg with
  | Half_page_down -> "ScrollPane:Half_page_down;"
  | Half_page_up -> "ScrollPane:Half_page_up;"
  | Waypoint_advanced -> "ScrollPane:Waypoint_advanced;"
  | Far_row_focused -> "ScrollPane:Far_row_focused;"
  | Keys_toggled enabled -> Printf.sprintf "ScrollPane:Keys:%b;" enabled

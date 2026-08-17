open Nopal_element
open Nopal_style

type model = { selected : string; align : Reveal.align; keys_enabled : bool }

type msg =
  | Select_next
  | Select_previous
  | Align_selected of Reveal.align
  | Keys_toggled of bool

let row_count = 40

(* Far enough down that reaching it is a scroll rather than a formality, so the
   row that carries punctuation in its key is also the row that proves a reveal
   moved the container. *)
let hostile_position = 27
let hostile_key = {|notes/quote"and\slash.md|}

let key_of_index index =
  if Int.equal index hostile_position then hostile_key
  else Printf.sprintf "notes/%02d.md" index

let filler =
  "This row is deliberately not the same height as its neighbours: it wraps \
   across as many lines as its own text needs."

(* Heights vary on a four-row cycle rather than growing with the index, so no
   arithmetic on a single row height can predict where a row starts. A uniform
   grid would let a fixed-row-height implementation pass this section. *)
let label_of index key =
  let repeats = 1 + (index * 3 mod 4) in
  String.concat " " (key :: List.init repeats (fun _ -> filler))

let row_keys = List.init row_count key_of_index

let first_key =
  match row_keys with
  | key :: _ -> key
  | [] -> key_of_index 0

let rec next_after key keys =
  match keys with
  | current :: (following :: _ as rest) ->
      if String.equal current key then following else next_after key rest
  | [ _ ]
  | [] ->
      key

let rec previous_before key keys =
  match keys with
  | preceding :: (current :: _ as rest) ->
      if String.equal current key then preceding else previous_before key rest
  | [ _ ]
  | [] ->
      key

let init () =
  ( { selected = first_key; align = Reveal.Nearest; keys_enabled = false },
    Nopal_mvu.Cmd.none )

let update model msg =
  match msg with
  | Select_next ->
      ( { model with selected = next_after model.selected row_keys },
        Nopal_mvu.Cmd.none )
  | Select_previous ->
      ( { model with selected = previous_before model.selected row_keys },
        Nopal_mvu.Cmd.none )
  | Align_selected align -> ({ model with align }, Nopal_mvu.Cmd.none)
  | Keys_toggled keys_enabled ->
      ({ model with keys_enabled }, Nopal_mvu.Cmd.none)

let down_sub_key = "reveal-list-down"
let up_sub_key = "reveal-list-up"

let subscriptions model =
  match model.keys_enabled with
  | false -> Nopal_mvu.Sub.none
  | true ->
      Nopal_mvu.Sub.batch
        [
          Nopal_mvu.Sub.on_key down_sub_key ~key:"ArrowDown" ~prevent:true
            Select_next;
          Nopal_mvu.Sub.on_key up_sub_key ~key:"ArrowUp" ~prevent:true
            Select_previous;
        ]

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

let list_style =
  Style.default |> Style.with_layout (fun l -> Style.padding_all 4.0 l)

let row_style =
  Style.default
  |> Style.with_layout (fun l -> Style.padding 6.0 10.0 6.0 10.0 l)

let selected_row_style =
  Style.default
  |> Style.with_layout (fun l -> Style.padding 6.0 10.0 6.0 10.0 l)
  |> Style.with_paint (fun p ->
      { p with background = Some (Style.hex "#e7f1fb") })

let control_row_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = Some 8.0; cross_align = Some Center })

let align_control ~action ~label align =
  Element.button
    ~attrs:[ ("data-action", action) ]
    ~on_click:(Align_selected align) (Element.text label)

let request model =
  match model.align with
  | Reveal.Nearest -> Reveal.nearest model.selected
  | Reveal.Start -> Reveal.start model.selected
  | Reveal.Center -> Reveal.center model.selected
  | Reveal.End_ -> Reveal.end_ model.selected

let row_element ~selected index key =
  let style =
    if String.equal key selected then selected_row_style else row_style
  in
  Element.keyed key
    (Element.box ~style
       ~attrs:[ ("data-testid", Printf.sprintf "reveal-list-row-%d" index) ]
       [ Element.text (label_of index key) ])

let view _vp model =
  let rows =
    List.mapi
      (fun index key -> row_element ~selected:model.selected index key)
      row_keys
  in
  Element.column
    ~attrs:[ ("data-testid", "reveal-list-demo") ]
    [
      Element.row ~style:control_row_style
        [
          Element.checkbox
            ~attrs:[ ("data-field", "reveal-keys") ]
            ~on_toggle:(fun enabled -> Keys_toggled enabled)
            model.keys_enabled;
          Element.text "Arrow keys move the selection";
        ];
      Element.row ~style:control_row_style
        [
          align_control ~action:"reveal-align-nearest" ~label:"Nearest"
            Reveal.Nearest;
          align_control ~action:"reveal-align-start" ~label:"Start" Reveal.Start;
          align_control ~action:"reveal-align-center" ~label:"Center"
            Reveal.Center;
          align_control ~action:"reveal-align-end" ~label:"End" Reveal.End_;
        ];
      Element.box
        ~attrs:[ ("data-testid", "reveal-list-readout") ]
        [
          Element.text
            (Printf.sprintf "Selected %s, aligned %s" model.selected
               (Reveal.align_token model.align));
        ];
      Element.box
        ~attrs:[ ("data-testid", "reveal-list-frame") ]
        [
          (* The request is re-derived from the model on every view call, so it
             cannot fall out of step with the selection. It is a request, not an
             invariant: the container moves when it changes, so a reader who
             scrolls away from the selected row keeps their position. *)
          Element.scroll ~style:container_style ~reveal:(request model)
            (Element.column ~style:list_style rows);
        ];
    ]

let serialize_model model =
  Printf.sprintf "reveal_key=%S; reveal_align=%s; reveal_keys=%b;"
    model.selected
    (Reveal.align_token model.align)
    model.keys_enabled

let serialize_msg msg =
  match msg with
  | Select_next -> "Reveal:Select_next;"
  | Select_previous -> "Reveal:Select_previous;"
  | Align_selected align ->
      Printf.sprintf "Reveal:Align:%s;" (Reveal.align_token align)
  | Keys_toggled enabled -> Printf.sprintf "Reveal:Keys:%b;" enabled

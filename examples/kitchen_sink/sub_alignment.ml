open Nopal_element
open Nopal_style

(* The fixtures' sizes. They are private on purpose: the structural suite and
   the browser case state these numbers themselves, so a size changed here
   reddens them instead of being read back out of the section and compared with
   itself. *)
let main_row_width = 300.0
let cross_row_height = 100.0
let box_width = 40.0
let main_box_height = 24.0
let cross_box_heights = [ 20.0; 40.0; 60.0 ]
let gap = 8.0
let row_fill = Style.hex "#e9ecef"
let box_fill = Style.hex "#bcd8f3"

(* [opacity] and [overflow] are the two paint fields that are not options, so
   they are spelled out rather than inherited from the default paint. *)
let filled color p =
  {
    p with
    Style.background = Some color;
    opacity = 1.0;
    overflow = Style.Visible;
  }

let main_name : Style.align -> string = function
  | Start -> "start"
  | Center -> "center"
  | End_ -> "end"
  | Space_between -> "space-between"

let cross_name : Style.cross_align -> string = function
  | Start -> "start"
  | Center -> "center"
  | End_ -> "end"
  | Stretch -> "stretch"

let box height =
  Element.box
    ~style:
      (Style.default
      |> Style.with_layout (fun l ->
          { l with width = Some (Fixed box_width); height })
      |> Style.with_paint (filled box_fill))
    []

let labelled label testid style children =
  Element.column
    [
      Element.text label;
      Element.row ~style ~attrs:[ ("data-testid", testid) ] children;
    ]

let row_style set_layout =
  Style.default
  |> Style.with_layout (fun l -> set_layout { l with gap = Some gap })
  |> Style.with_paint (filled row_fill)

let main_row (a : Style.align) =
  let name = main_name a in
  labelled ("Main axis: " ^ name) ("align-main-" ^ name)
    (row_style (fun l ->
         { l with main_align = Some a; width = Some (Fixed main_row_width) }))
    (List.init 3 (fun _ -> box (Some (Fixed main_box_height))))

(* A box that declares a height keeps it under stretch, so the stretch row's
   boxes declare none and take the row's height instead. *)
let cross_children (a : Style.cross_align) =
  match a with
  | Stretch -> List.init 3 (fun _ -> box None)
  | Start
  | Center
  | End_ ->
      List.map (fun h -> box (Some (Fixed h))) cross_box_heights

let cross_row (a : Style.cross_align) =
  let name = cross_name a in
  labelled ("Cross axis: " ^ name) ("align-cross-" ^ name)
    (row_style (fun l ->
         { l with cross_align = Some a; height = Some (Fixed cross_row_height) }))
    (cross_children a)

let view () =
  Element.column
    ~style:
      (Style.default |> Style.with_layout (fun l -> { l with gap = Some 16.0 }))
    [
      main_row Start;
      main_row Center;
      main_row End_;
      main_row Space_between;
      cross_row Start;
      cross_row Center;
      cross_row End_;
      cross_row Stretch;
    ]

open Nopal_element
open Nopal_style

type model = { chosen : string; align : Reveal.align }
type msg = Tab_chosen of string | Align_selected of Reveal.align

(* Ten tabs of 100px in a 320px strip: 1000px of content over a 320px window,
   so the strip scrolls sideways through [0, 680] and at most three whole tabs
   are in view at once. The tabs sit edge to edge with no gap or padding, so
   tab [i] starts at exactly [i * tab_width]. *)
let tab_count = 10
let tab_width = 100.0
let tab_height = 40.0
let strip_width = 320.0
let tab_key index = Printf.sprintf "tab-%02d" index
let tab_keys = List.init tab_count tab_key

(* The last key rather than an index into the list, so the initial choice is
   the tab rendered last whatever the count, with no lookup that could fail. *)
let last_tab_key =
  match List.rev tab_keys with
  | key :: _ -> key
  | [] -> tab_key 0

(* Eight columns of 120px and twelve rows of 60px in a 240px by 200px window,
   so the content is 960px by 720px and overflows both ways. The requested cell
   is short of the last row and the last column, so revealing it stops before
   either axis reaches its limit — a container that merely scrolled to its far
   corner would not put it where a reveal does. *)
let grid_columns = 8
let grid_rows = 12
let cell_width = 120.0
let cell_height = 60.0
let grid_width = 240.0
let grid_height = 200.0
let far_row = 9
let far_column = 6
let row_key row = Printf.sprintf "row-%02d" row
let cell_key ~row ~column = Printf.sprintf "cell-%02d-%02d" row column
let far_cell_key = cell_key ~row:far_row ~column:far_column

(* A vertical list whose rows are wider than it is: ten rows of 40px in a 240px
   by 200px window, each as wide as a column of 700.4px. The width is not a whole
   number of pixels, so a browser measures every row's rect at a fraction, and a
   row covers the window's width from edge to edge wherever the list is scrolled
   sideways. *)
let cover_width = 240.0
let cover_height = 200.0
let cover_content_width = 700.4
let cover_row_height = 40.0

let init () =
  ({ chosen = last_tab_key; align = Reveal.Nearest }, Nopal_mvu.Cmd.none)

let update model msg =
  match msg with
  | Tab_chosen chosen -> ({ model with chosen }, Nopal_mvu.Cmd.none)
  | Align_selected align -> ({ model with align }, Nopal_mvu.Cmd.none)

let sized ~width ~height =
  Style.default
  |> Style.with_layout (fun l ->
      { l with width = Some (Fixed width); height = Some (Fixed height) })

(* Every paint field is written out rather than inherited from a default, so no
   border, shadow, clipping or transparency arrives here unasked. *)
let painted color style =
  Style.set_paint
    {
      background = Some color;
      border = None;
      opacity = 1.0;
      shadow = None;
      overflow = Visible;
    }
    style

let centred style =
  style
  |> Style.with_layout (fun l ->
      { l with main_align = Some Center; cross_align = Some Center })

let strip_style =
  Style.default
  |> Style.with_layout (fun l -> { l with width = Some (Fixed strip_width) })
  |> painted (Style.hex "#f8f9fa")

let grid_style = sized ~width:grid_width ~height:grid_height
let tab_style = sized ~width:tab_width ~height:tab_height |> centred

let control_row_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = Some 8.0; cross_align = Some Center })

let cover_list_style = sized ~width:cover_width ~height:cover_height

let cover_column_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with width = Some (Fixed cover_content_width) })

let cover_row_style =
  Style.default
  |> Style.with_layout (fun l ->
      {
        l with
        width = Some (Fraction 1.0);
        height = Some (Fixed cover_row_height);
      })
  |> centred

let tab_element ~prefix ~chosen index key =
  let color =
    if String.equal key chosen then Style.hex "#cfe2ff" else Style.hex "#e9ecef"
  in
  Element.keyed key
    (Element.box ~style:(painted color tab_style)
       ~attrs:[ ("data-testid", Printf.sprintf "%s-tab-%d" prefix index) ]
       [ Element.text (Printf.sprintf "Tab %d" index) ])

(* A checkerboard, so a movement along either axis is visible, with the
   requested cell picked out. *)
let cell_color ~row ~column =
  match
    (Int.equal row far_row && Int.equal column far_column, (row + column) mod 2)
  with
  | true, _ -> Style.hex "#ffd8a8"
  | false, 0 -> Style.hex "#f1f3f5"
  | false, _ -> Style.hex "#dee2e6"

let cell_element ~row column =
  Element.keyed (cell_key ~row ~column)
    (Element.box
       ~style:
         (painted (cell_color ~row ~column)
            (sized ~width:cell_width ~height:cell_height |> centred))
       ~attrs:
         [ ("data-testid", Printf.sprintf "reveal-tabs-cell-%d-%d" row column) ]
       [ Element.text (Printf.sprintf "%d, %d" row column) ])

(* Rows are keyed as well as cells: a column holding one keyed row beside an
   unkeyed one would be reconciled by position, replacing every keyed row on
   every render. *)
let grid_row row =
  Element.keyed (row_key row)
    (Element.row (List.init grid_columns (cell_element ~row)))

let cover_row ~chosen index key =
  let color =
    if String.equal key chosen then Style.hex "#cfe2ff" else Style.hex "#e9ecef"
  in
  Element.keyed key
    (Element.box
       ~style:(painted color cover_row_style)
       ~attrs:
         [ ("data-testid", Printf.sprintf "reveal-tabs-cover-row-%d" index) ]
       [ Element.text (Printf.sprintf "Row %d" index) ])

let align_control ~action ~label align =
  Element.button
    ~attrs:[ ("data-action", action) ]
    ~on_click:(Align_selected align) (Element.text label)

let view _vp model =
  Element.column
    ~attrs:[ ("data-testid", "reveal-tabs-demo") ]
    [
      Element.row ~style:control_row_style
        [
          Element.text "Chosen tab";
          Element.select
            ~attrs:[ ("data-field", "reveal-tabs-choice") ]
            ~on_change:(fun key -> Tab_chosen key)
            ~selected:model.chosen
            (List.mapi
               (fun index key ->
                 Element.select_option ~value:key
                   (Printf.sprintf "Tab %d" index))
               tab_keys);
        ];
      Element.row ~style:control_row_style
        [
          align_control ~action:"reveal-tabs-align-nearest" ~label:"Nearest"
            Reveal.Nearest;
          align_control ~action:"reveal-tabs-align-start" ~label:"Start"
            Reveal.Start;
          align_control ~action:"reveal-tabs-align-center" ~label:"Center"
            Reveal.Center;
          align_control ~action:"reveal-tabs-align-end" ~label:"End" Reveal.End_;
        ];
      Element.box
        ~attrs:[ ("data-testid", "reveal-tabs-readout") ]
        [
          Element.text
            (Printf.sprintf "Chosen %s, aligned %s" model.chosen
               (Reveal.align_token model.align));
        ];
      (* Both requests are re-derived from the model on every view call, so
         neither can fall out of step with it. The strip's is already present
         on its first render, which is what reveals the last tab on arrival. *)
      Element.scroll ~style:strip_style
        ~attrs:[ ("data-testid", "reveal-tabs-strip") ]
        ~reveal:{ Reveal.key = model.chosen; align = model.align }
        (Element.row
           (List.mapi
              (tab_element ~prefix:"reveal-tabs" ~chosen:model.chosen)
              tab_keys));
      (* The same strip right to left: horizontal-tb under [dir=rtl], whose x
         axis runs reversed. The renderer must leave its scrollLeft alone. *)
      Element.scroll ~style:strip_style
        ~attrs:[ ("data-testid", "reveal-tabs-rtl-strip"); ("dir", "rtl") ]
        ~reveal:{ Reveal.key = model.chosen; align = model.align }
        (Element.row
           (List.mapi
              (tab_element ~prefix:"reveal-tabs-rtl" ~chosen:model.chosen)
              tab_keys));
      (* Rendered with no writing mode: a browser-level test sets vertical-rl
         on this element itself, with direction left to-right, which reverses
         its x axis although its direction is not rtl. The tabs are a column
         because a column's main axis is the horizontal one in that mode, so
         the content then overflows along x. *)
      Element.text
        "Vertical strip: a column that scrolls along x in vertical-rl";
      Element.scroll ~style:strip_style
        ~attrs:[ ("data-testid", "reveal-tabs-vertical-strip") ]
        ~reveal:{ Reveal.key = model.chosen; align = model.align }
        (Element.column
           (List.mapi
              (tab_element ~prefix:"reveal-tabs-vertical" ~chosen:model.chosen)
              tab_keys));
      (* A vertical list whose rows overflow sideways and are wider than the
         list: under nearest, a row that covers the list's width is already
         where it needs to be along x, so choosing one moves the list down or
         up and leaves its scrollLeft alone. *)
      Element.text "Cover list: a vertical list of rows wider than the list";
      Element.scroll ~style:cover_list_style
        ~attrs:[ ("data-testid", "reveal-tabs-cover-list") ]
        ~reveal:{ Reveal.key = model.chosen; align = model.align }
        (Element.column ~style:cover_column_style
           (List.mapi (cover_row ~chosen:model.chosen) tab_keys));
      Element.scroll ~style:grid_style
        ~attrs:[ ("data-testid", "reveal-tabs-grid") ]
        ~reveal:{ Reveal.key = far_cell_key; align = model.align }
        (Element.column (List.init grid_rows grid_row));
    ]

let serialize_model model =
  Printf.sprintf "reveal_tab=%S; reveal_tabs_align=%s;" model.chosen
    (Reveal.align_token model.align)

let serialize_msg msg =
  match msg with
  | Tab_chosen key -> Printf.sprintf "Reveal_tabs:Choose:%S;" key
  | Align_selected align ->
      Printf.sprintf "Reveal_tabs:Align:%s;" (Reveal.align_token align)

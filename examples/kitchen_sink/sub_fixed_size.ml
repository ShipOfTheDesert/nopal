open Nopal_element
open Nopal_style

type model = { sibling_wraps : bool; stacked : bool }
type msg = Wrap_toggled of bool | Stack_toggled of bool

(* The two fixtures' sizes. They are private on purpose: a browser case and the
   structural suite both state these numbers themselves, so a size changed here
   reddens them instead of being read back out of the section and compared with
   itself. *)
let pair_width = 360.0
let pair_height = 140.0
let fixed_width = 120.0
let fixed_height = 56.0
let columns_row_width = 300.0
let column_width = 140.0
let column_height = 40.0
let column_count = 3
let unbreakable_token = "RCPT7F3AB19C4DE2"

(* The token supplies a stretch of text a line cannot be divided anywhere
   inside; the words around it supply the ones it can. Both are needed: with
   wrapping off the whole sentence is one unbroken line and the sibling demands
   several times the room the pair has, and with wrapping on the sibling's
   minimum is the token alone, which is narrow enough to fit the room left over
   so the flexible half of the rule stays measurable. *)
let sibling_content =
  "Scan " ^ unbreakable_token
  ^ " is waiting on the counter clerk to reconcile it against the morning \
     shift takings."

let init () = ({ sibling_wraps = false; stacked = false }, Nopal_mvu.Cmd.none)

let update model msg =
  match msg with
  | Wrap_toggled sibling_wraps ->
      ({ model with sibling_wraps }, Nopal_mvu.Cmd.none)
  | Stack_toggled stacked -> ({ model with stacked }, Nopal_mvu.Cmd.none)

let frame_fill = Style.hex "#e9ecef"
let fixed_fill = Style.hex "#bcd8f3"
let flexible_fill = Style.hex "#f8f9fa"
let column_fill = Style.hex "#cfe6c4"

(* [opacity] and [overflow] are the two paint fields that are not options, so
   they carry a concrete value whether or not a caller names one. Both are
   spelled out at every fixture here rather than inherited from the default
   paint: a hidden overflow would clip the very thing these fixtures exist to
   show, which is content demanding more room than its container has. *)
let filled color p =
  {
    p with
    Style.background = Some color;
    opacity = 1.0;
    overflow = Style.Visible;
  }

let pair_direction stacked =
  match stacked with
  | true -> Style.Column_dir
  | false -> Style.Row_dir

(* The pair's own axis comes from its style, because a Box is the one container
   whose direction is not already decided by its constructor: Row and Column
   write theirs inline after the style is applied, so a style asking either of
   them for the opposite axis loses. A Box with no direction at all is laid out
   down the page by this backend, so the across-the-page arm has to say so
   rather than leave the field absent. *)
let pair_style stacked =
  Style.default
  |> Style.with_layout (fun l ->
      {
        l with
        direction = Some (pair_direction stacked);
        width = Some (Fixed pair_width);
        height = Some (Fixed pair_height);
      })
  |> Style.with_paint (filled frame_fill)

(* No padding and no border on anything a browser case measures. Sizes here are
   content-box, so trim would put the measured bounding box a few pixels above
   the size the style declares and every geometry assertion would need a
   tolerance that hides the thing it is looking for. *)
let centred_box ~width ~height ~fill =
  Style.default
  |> Style.with_layout (fun l ->
      {
        l with
        direction = Some Style.Column_dir;
        main_align = Some Center;
        cross_align = Some Center;
        width = Some (Fixed width);
        height = Some (Fixed height);
      })
  |> Style.with_paint (filled fill)

let fixed_box_style =
  centred_box ~width:fixed_width ~height:fixed_height ~fill:fixed_fill

(* The sibling declares it will take whatever room is left on both axes, which
   is what makes the pair overconstrained whichever way round it is laid out:
   the declared sizes of the two children add up to more than the pair has, so
   one of them has to give way. *)
let flexible_box_style =
  Style.default
  |> Style.with_layout (fun l ->
      {
        l with
        direction = Some Style.Column_dir;
        width = Some Fill;
        height = Some Fill;
      })
  |> Style.with_paint (filled flexible_fill)

(* Whether a line may break and whether runs of whitespace collapse resolve to
   one declaration whose every value sets both, so the collapsing axis is stated
   here too rather than left absent and answered by whichever value the wrapping
   axis happens to emit. *)
let sibling_text_style wraps =
  Text.default
  |> Text.whitespace Text.Collapse
  |> Text.text_overflow
       (match wraps with
       | true -> Text.Wrap
       | false -> Text.No_wrap)

let columns_row_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with width = Some (Fixed columns_row_width) })
  |> Style.with_paint (filled frame_fill)

let column_style =
  centred_box ~width:column_width ~height:column_height ~fill:column_fill

let control_row_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = Some 8.0; cross_align = Some Center })

let demo_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = Some 12.0; cross_align = Some Start })

let control ~field ~label ~checked ~on_toggle =
  Element.row ~style:control_row_style
    [
      Element.checkbox ~attrs:[ ("data-field", field) ] ~on_toggle checked;
      Element.text label;
    ]

let column index =
  Element.box ~style:column_style
    ~attrs:[ ("data-testid", Printf.sprintf "fixed-size-column-%d" index) ]
    [ Element.text (Printf.sprintf "Column %d" (index + 1)) ]

let view _vp model =
  Element.column ~style:demo_style
    ~attrs:[ ("data-testid", "fixed-size-demo") ]
    [
      control ~field:"fixed-size-wrap" ~label:"Let the sibling's line break"
        ~checked:model.sibling_wraps ~on_toggle:(fun wraps ->
          Wrap_toggled wraps);
      control ~field:"fixed-size-stack" ~label:"Stack the pair down the page"
        ~checked:model.stacked ~on_toggle:(fun stacked -> Stack_toggled stacked);
      Element.box ~style:(pair_style model.stacked)
        ~attrs:[ ("data-testid", "fixed-size-pair") ]
        [
          Element.box ~style:fixed_box_style
            ~attrs:[ ("data-testid", "fixed-size-fixed") ]
            [
              Element.text
                (Printf.sprintf "Fixed %g x %g" fixed_width fixed_height);
            ];
          Element.box ~style:flexible_box_style
            ~attrs:[ ("data-testid", "fixed-size-flexible") ]
            [
              Element.styled_text
                ~text_style:(sibling_text_style model.sibling_wraps)
                sibling_content;
            ];
        ];
      Element.text "Three columns declared wider than the row that holds them:";
      Element.row ~style:columns_row_style
        ~attrs:[ ("data-testid", "fixed-size-columns") ]
        (List.init column_count column);
    ]

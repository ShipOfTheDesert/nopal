open Nopal_element
open Nopal_style

type model = { floor_lifted : bool }
type msg = Floor_toggled of bool

(* The fixture's sizes. They are private on purpose: a browser case and the
   structural suite both state these numbers themselves, so a size changed here
   reddens them instead of being read back out of the section and compared with
   itself. *)
let demo_height = 420.0
let frame_width = 360.0
let bounded_height = 200.0
let band_height = 32.0
let content_height = 260.0
let content_rows = 8
let init () = ({ floor_lifted = false }, Nopal_mvu.Cmd.none)

(* The whole model is the flag, so the new state is built rather than updated
   from the old one: a functional update over a single-field record is a warning
   here, and a model that grows a second field will stop compiling at this line
   rather than silently dropping it. *)
let update _model msg =
  match msg with
  | Floor_toggled floor_lifted -> ({ floor_lifted }, Nopal_mvu.Cmd.none)

let frame_fill = Style.hex "#e9ecef"
let holding_fill = Style.hex "#f8f9fa"
let content_fill = Style.hex "#cfe6c4"
let band_fill = Style.hex "#bcd8f3"

(* [opacity] and [overflow] are the two paint fields that are not options, so
   they carry a concrete value whether or not a caller names one. Both are
   spelled out at every fixture here rather than inherited from the default
   paint: a hidden overflow would clip the very thing this section exists to
   show, which is a band laid out past the bottom edge of the container that is
   supposed to hold it. *)
let filled color p =
  {
    p with
    Style.background = Some color;
    opacity = 1.0;
    overflow = Style.Visible;
  }

(* The section's own root reserves the room the reported shape needs. In that
   shape the band is laid out well past the bounded column's bottom edge, and
   the overflow is visible by design, so without the reservation the escaped
   band would paint over the section below and take its pointer events. It
   cannot compress the fixture: the bounded column declares a height on the axis
   this root lays its children out along, which is not reduced. *)
let demo_style =
  Style.default
  |> Style.with_layout (fun l ->
      {
        l with
        gap = Some 12.0;
        cross_align = Some Start;
        height = Some (Fixed demo_height);
      })

(* No padding and no border on anything a browser case measures, nor on anything
   holding it. Sizes here are content-box, so trim would put a measured bounding
   box a few pixels away from the geometry the style declares and every
   assertion would need a tolerance wide enough to hide what it is looking
   for. *)
let bounded_style =
  Style.default
  |> Style.with_layout (fun l ->
      {
        l with
        width = Some (Fixed frame_width);
        height = Some (Fixed bounded_height);
      })
  |> Style.with_paint (filled frame_fill)

(* The column the control reaches, and the only element in the fixture that can
   give way. It declares no height, so the room it is given is the room left in
   the bounded column; without a floor it cannot be reduced below its own
   content, which is the whole pane, so it takes the fixture instead. A floor
   here is not inert the way a floor on either of its neighbours would be: the
   pane below it is a scrolling container whose automatic minimum already
   resolves to zero, and the bounded column above it declares a height that
   already caps its own. *)
let holding_style floor_lifted =
  Style.default
  |> Style.with_layout (fun l ->
      {
        l with
        width = Some Fill;
        min_height =
          (match floor_lifted with
          | true -> Some 0.0
          | false -> None);
      })
  |> Style.with_paint (filled holding_fill)

let content_style =
  Style.default
  |> Style.with_layout (fun l ->
      {
        l with
        gap = Some 6.0;
        width = Some Fill;
        height = Some (Fixed content_height);
      })
  |> Style.with_paint (filled content_fill)

let band_style =
  Style.default
  |> Style.with_layout (fun l ->
      {
        l with
        main_align = Some Center;
        cross_align = Some Center;
        width = Some Fill;
        height = Some (Fixed band_height);
      })
  |> Style.with_paint (filled band_fill)

let control_row_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = Some 8.0; cross_align = Some Center })

let content_row index =
  Element.text (Printf.sprintf "Line %d of the pane's content" (index + 1))

let view _vp model =
  Element.column ~style:demo_style
    ~attrs:[ ("data-testid", "min-size-demo") ]
    [
      Element.row ~style:control_row_style
        [
          Element.checkbox
            ~attrs:[ ("data-field", "min-size-floor") ]
            ~on_toggle:(fun lifted -> Floor_toggled lifted)
            model.floor_lifted;
          Element.text
            "Let the column holding the pane be reduced below its own content";
        ];
      Element.column ~style:bounded_style
        ~attrs:[ ("data-testid", "min-size-bounded") ]
        [
          Element.column
            ~style:(holding_style model.floor_lifted)
            ~attrs:[ ("data-testid", "min-size-holding") ]
            [
              (* The pane declares nothing at all. What it is given is what the
                 column above it has left, which is the point: a pane handed a
                 height of its own would scroll whether or not the column could
                 be reduced, and the section would demonstrate nothing. *)
              Element.scroll
                ~attrs:[ ("data-testid", "min-size-pane") ]
                (Element.column ~style:content_style
                   ~attrs:[ ("data-testid", "min-size-content") ]
                   (List.init content_rows content_row));
            ];
          Element.box ~style:band_style
            ~attrs:[ ("data-testid", "min-size-band") ]
            [ Element.text "This band belongs inside the frame" ];
        ];
    ]

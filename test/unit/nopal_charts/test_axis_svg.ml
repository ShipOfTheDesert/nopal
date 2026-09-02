open Nopal_charts

(* The scene the two SVG fixtures are taken from. Both axes carry a label, so
   every node kind the appearance record will eventually reach — axis line, tick
   mark, tick label, axis label — is present in each orientation. *)

let chart_x = 50.0
let chart_top = 60.0
let chart_bottom = 260.0
let chart_width = 400.0
let chart_height = 200.0
let svg_width = 500.0
let svg_height = 300.0

let x_scale =
  Nopal_draw.Scale.create ~domain:(0.0, 100.0) ~range:(0.0, chart_width)

let y_scale =
  Nopal_draw.Scale.create ~domain:(0.0, 50.0) ~range:(chart_bottom, chart_top)

(* [Axis.default_config] is the subject here, not an incidental base: the
   guarantee under test is that a caller who never mentions appearance gets the
   output this module produced before appearance existed. *)
let default_x_config = { Axis.default_config with label = Some "Time" }
let default_y_config = { Axis.default_config with label = Some "Value" }

let scene_of_configs ~(x_config : Axis.config) ~(y_config : Axis.config) =
  let x_ticks = Axis.compute_ticks x_config ~data_min:0.0 ~data_max:100.0 in
  let y_ticks = Axis.compute_ticks y_config ~data_min:0.0 ~data_max:50.0 in
  Axis.render_x x_config ~ticks:x_ticks ~scale:x_scale ~chart_x
    ~chart_y:chart_bottom ~chart_width
  @ Axis.render_y y_config ~ticks:y_ticks ~scale:y_scale ~chart_x
      ~chart_y:chart_top ~chart_height

(* Both fixtures below pin two packages, not one. Every byte after the scene is
   built comes from [Nopal_svg]: its attribute order within an element, its
   [fmt_float] rendering of every coordinate and size, and its [color_to_css]
   0-255 rounding of every colour. A change to [lib/nopal_svg/svg_fmt.ml] will
   therefore redden this suite with a single-line multi-kilobyte diff even
   though [Axis] is untouched — that is expected, and the fixtures are
   re-recorded from the renderer rather than hand-edited. *)

(* Captured while [render_x] / [render_y] still read the module-level
   constants, so this is by construction the output the module produced
   before the appearance record existed. It is a quoted string literal so
   that no formatter can insert a backslash continuation and eat a
   significant space. *)
let default_svg =
  {svg|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 300"><line x1="50" y1="260" x2="450" y2="260" stroke="rgba(51,51,51,1)" stroke-width="1" stroke-linecap="butt" stroke-linejoin="miter"/><line x1="50" y1="260" x2="50" y2="266" stroke="rgba(51,51,51,1)" stroke-width="1" stroke-linecap="butt" stroke-linejoin="miter"/><text x="50" y="276" font-size="11" font-family="sans-serif" font-weight="400" fill="rgba(0,0,0,1)" text-anchor="middle" dominant-baseline="text-before-edge">0.</text><line x1="130" y1="260" x2="130" y2="266" stroke="rgba(51,51,51,1)" stroke-width="1" stroke-linecap="butt" stroke-linejoin="miter"/><text x="130" y="276" font-size="11" font-family="sans-serif" font-weight="400" fill="rgba(0,0,0,1)" text-anchor="middle" dominant-baseline="text-before-edge">20.</text><line x1="210" y1="260" x2="210" y2="266" stroke="rgba(51,51,51,1)" stroke-width="1" stroke-linecap="butt" stroke-linejoin="miter"/><text x="210" y="276" font-size="11" font-family="sans-serif" font-weight="400" fill="rgba(0,0,0,1)" text-anchor="middle" dominant-baseline="text-before-edge">40.</text><line x1="290" y1="260" x2="290" y2="266" stroke="rgba(51,51,51,1)" stroke-width="1" stroke-linecap="butt" stroke-linejoin="miter"/><text x="290" y="276" font-size="11" font-family="sans-serif" font-weight="400" fill="rgba(0,0,0,1)" text-anchor="middle" dominant-baseline="text-before-edge">60.</text><line x1="370" y1="260" x2="370" y2="266" stroke="rgba(51,51,51,1)" stroke-width="1" stroke-linecap="butt" stroke-linejoin="miter"/><text x="370" y="276" font-size="11" font-family="sans-serif" font-weight="400" fill="rgba(0,0,0,1)" text-anchor="middle" dominant-baseline="text-before-edge">80.</text><line x1="450" y1="260" x2="450" y2="266" stroke="rgba(51,51,51,1)" stroke-width="1" stroke-linecap="butt" stroke-linejoin="miter"/><text x="450" y="276" font-size="11" font-family="sans-serif" font-weight="400" fill="rgba(0,0,0,1)" text-anchor="middle" dominant-baseline="text-before-edge">100.</text><text x="250" y="292" font-size="12" font-family="sans-serif" font-weight="400" fill="rgba(0,0,0,1)" text-anchor="middle" dominant-baseline="text-before-edge">Time</text><line x1="50" y1="60" x2="50" y2="260" stroke="rgba(51,51,51,1)" stroke-width="1" stroke-linecap="butt" stroke-linejoin="miter"/><line x1="44" y1="260" x2="50" y2="260" stroke="rgba(51,51,51,1)" stroke-width="1" stroke-linecap="butt" stroke-linejoin="miter"/><text x="34" y="260" font-size="11" font-family="sans-serif" font-weight="400" fill="rgba(0,0,0,1)" text-anchor="end" dominant-baseline="central">0.</text><line x1="44" y1="220" x2="50" y2="220" stroke="rgba(51,51,51,1)" stroke-width="1" stroke-linecap="butt" stroke-linejoin="miter"/><text x="34" y="220" font-size="11" font-family="sans-serif" font-weight="400" fill="rgba(0,0,0,1)" text-anchor="end" dominant-baseline="central">10.</text><line x1="44" y1="180" x2="50" y2="180" stroke="rgba(51,51,51,1)" stroke-width="1" stroke-linecap="butt" stroke-linejoin="miter"/><text x="34" y="180" font-size="11" font-family="sans-serif" font-weight="400" fill="rgba(0,0,0,1)" text-anchor="end" dominant-baseline="central">20.</text><line x1="44" y1="140" x2="50" y2="140" stroke="rgba(51,51,51,1)" stroke-width="1" stroke-linecap="butt" stroke-linejoin="miter"/><text x="34" y="140" font-size="11" font-family="sans-serif" font-weight="400" fill="rgba(0,0,0,1)" text-anchor="end" dominant-baseline="central">30.</text><line x1="44" y1="100" x2="50" y2="100" stroke="rgba(51,51,51,1)" stroke-width="1" stroke-linecap="butt" stroke-linejoin="miter"/><text x="34" y="100" font-size="11" font-family="sans-serif" font-weight="400" fill="rgba(0,0,0,1)" text-anchor="end" dominant-baseline="central">40.</text><line x1="44" y1="60" x2="50" y2="60" stroke="rgba(51,51,51,1)" stroke-width="1" stroke-linecap="butt" stroke-linejoin="miter"/><text x="34" y="60" font-size="11" font-family="sans-serif" font-weight="400" fill="rgba(0,0,0,1)" text-anchor="end" dominant-baseline="central">50.</text><text x="18" y="160" font-size="12" font-family="sans-serif" font-weight="400" fill="rgba(0,0,0,1)" text-anchor="end" dominant-baseline="central">Value</text></svg>|svg}

let test_default_scene_is_byte_identical () =
  let rendered =
    Nopal_svg.render ~width:svg_width ~height:svg_height
      (scene_of_configs ~x_config:default_x_config ~y_config:default_y_config)
  in
  Alcotest.(check string)
    "default-config axis chrome is unchanged" default_svg rendered

(* Every field carries a value that differs from its own default and from every
   other field of the same type, so a routing that crosses two fields cannot
   render the same bytes as a routing that does not. The four colours stay
   distinct after the 0-255 rounding [Nopal_svg] applies, and none of them is
   the default grey or black. Stated as literals rather than derived from
   [Axis.default_appearance], so this fixture cannot agree with the value it
   exists to police. [tick_length] and [tick_label_size] stay under the 16.0
   ceiling [Axis.appearance] documents — the module-private label offsets are
   not configurable, so a larger value would make this pin record overlapping
   text as correct. *)
let themed_appearance =
  {
    Axis.line_color = Nopal_draw.Color.rgb ~r:0.9 ~g:0.1 ~b:0.1;
    line_width = 3.0;
    tick_color = Nopal_draw.Color.rgb ~r:0.1 ~g:0.7 ~b:0.2;
    tick_length = 9.0;
    tick_label_color = Nopal_draw.Color.rgb ~r:0.2 ~g:0.3 ~b:0.8;
    tick_label_size = 14.0;
    axis_label_color = Nopal_draw.Color.rgb ~r:0.6 ~g:0.0 ~b:0.6;
    axis_label_size = 23.0;
  }

(* Written out in full rather than as [{ Axis.default_config with appearance }]:
   nothing that feeds [compute_ticks] or the renderers may be inherited unseen.
   The labels, tick count and formatter deliberately match the default fixture's,
   so the only thing that can differ between the two recorded strings is
   appearance. *)
let themed_x_config : Axis.config =
  {
    label = Some "Time";
    min = None;
    max = None;
    tick_count = 5;
    format_tick = string_of_float;
    appearance = themed_appearance;
  }

let themed_y_config : Axis.config =
  {
    label = Some "Value";
    min = None;
    max = None;
    tick_count = 5;
    format_tick = string_of_float;
    appearance = themed_appearance;
  }

(* Unlike [default_svg] this is a capture of the fully-wired renderer, taken
   after every appearance field was routed, and recording it is the point of
   this fixture rather than a hazard. It was read value by value before being
   committed: all eight fields are visible in it and no default survives -
   rgba(230,26,26,1) on the two axis lines (line_color), stroke-width="3"
   on every stroke (line_width), rgba(26,179,51,1) on the tick marks
   (tick_color), X ticks ending at y2="269" and Y ticks starting at x1="41"
   (tick_length, 9.0 from a base of 260 and 50), rgba(51,77,204,1) with
   font-size="14" on the tick labels, and rgba(153,0,153,1) with
   font-size="23" on the two axis labels. The default grey, black,
   stroke-width="1", font-size="11" and font-size="12" appear nowhere. *)
let themed_svg =
  {svg|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 300"><line x1="50" y1="260" x2="450" y2="260" stroke="rgba(230,26,26,1)" stroke-width="3" stroke-linecap="butt" stroke-linejoin="miter"/><line x1="50" y1="260" x2="50" y2="269" stroke="rgba(26,179,51,1)" stroke-width="3" stroke-linecap="butt" stroke-linejoin="miter"/><text x="50" y="276" font-size="14" font-family="sans-serif" font-weight="400" fill="rgba(51,77,204,1)" text-anchor="middle" dominant-baseline="text-before-edge">0.</text><line x1="130" y1="260" x2="130" y2="269" stroke="rgba(26,179,51,1)" stroke-width="3" stroke-linecap="butt" stroke-linejoin="miter"/><text x="130" y="276" font-size="14" font-family="sans-serif" font-weight="400" fill="rgba(51,77,204,1)" text-anchor="middle" dominant-baseline="text-before-edge">20.</text><line x1="210" y1="260" x2="210" y2="269" stroke="rgba(26,179,51,1)" stroke-width="3" stroke-linecap="butt" stroke-linejoin="miter"/><text x="210" y="276" font-size="14" font-family="sans-serif" font-weight="400" fill="rgba(51,77,204,1)" text-anchor="middle" dominant-baseline="text-before-edge">40.</text><line x1="290" y1="260" x2="290" y2="269" stroke="rgba(26,179,51,1)" stroke-width="3" stroke-linecap="butt" stroke-linejoin="miter"/><text x="290" y="276" font-size="14" font-family="sans-serif" font-weight="400" fill="rgba(51,77,204,1)" text-anchor="middle" dominant-baseline="text-before-edge">60.</text><line x1="370" y1="260" x2="370" y2="269" stroke="rgba(26,179,51,1)" stroke-width="3" stroke-linecap="butt" stroke-linejoin="miter"/><text x="370" y="276" font-size="14" font-family="sans-serif" font-weight="400" fill="rgba(51,77,204,1)" text-anchor="middle" dominant-baseline="text-before-edge">80.</text><line x1="450" y1="260" x2="450" y2="269" stroke="rgba(26,179,51,1)" stroke-width="3" stroke-linecap="butt" stroke-linejoin="miter"/><text x="450" y="276" font-size="14" font-family="sans-serif" font-weight="400" fill="rgba(51,77,204,1)" text-anchor="middle" dominant-baseline="text-before-edge">100.</text><text x="250" y="292" font-size="23" font-family="sans-serif" font-weight="400" fill="rgba(153,0,153,1)" text-anchor="middle" dominant-baseline="text-before-edge">Time</text><line x1="50" y1="60" x2="50" y2="260" stroke="rgba(230,26,26,1)" stroke-width="3" stroke-linecap="butt" stroke-linejoin="miter"/><line x1="41" y1="260" x2="50" y2="260" stroke="rgba(26,179,51,1)" stroke-width="3" stroke-linecap="butt" stroke-linejoin="miter"/><text x="34" y="260" font-size="14" font-family="sans-serif" font-weight="400" fill="rgba(51,77,204,1)" text-anchor="end" dominant-baseline="central">0.</text><line x1="41" y1="220" x2="50" y2="220" stroke="rgba(26,179,51,1)" stroke-width="3" stroke-linecap="butt" stroke-linejoin="miter"/><text x="34" y="220" font-size="14" font-family="sans-serif" font-weight="400" fill="rgba(51,77,204,1)" text-anchor="end" dominant-baseline="central">10.</text><line x1="41" y1="180" x2="50" y2="180" stroke="rgba(26,179,51,1)" stroke-width="3" stroke-linecap="butt" stroke-linejoin="miter"/><text x="34" y="180" font-size="14" font-family="sans-serif" font-weight="400" fill="rgba(51,77,204,1)" text-anchor="end" dominant-baseline="central">20.</text><line x1="41" y1="140" x2="50" y2="140" stroke="rgba(26,179,51,1)" stroke-width="3" stroke-linecap="butt" stroke-linejoin="miter"/><text x="34" y="140" font-size="14" font-family="sans-serif" font-weight="400" fill="rgba(51,77,204,1)" text-anchor="end" dominant-baseline="central">30.</text><line x1="41" y1="100" x2="50" y2="100" stroke="rgba(26,179,51,1)" stroke-width="3" stroke-linecap="butt" stroke-linejoin="miter"/><text x="34" y="100" font-size="14" font-family="sans-serif" font-weight="400" fill="rgba(51,77,204,1)" text-anchor="end" dominant-baseline="central">40.</text><line x1="41" y1="60" x2="50" y2="60" stroke="rgba(26,179,51,1)" stroke-width="3" stroke-linecap="butt" stroke-linejoin="miter"/><text x="34" y="60" font-size="14" font-family="sans-serif" font-weight="400" fill="rgba(51,77,204,1)" text-anchor="end" dominant-baseline="central">50.</text><text x="18" y="160" font-size="23" font-family="sans-serif" font-weight="400" fill="rgba(153,0,153,1)" text-anchor="end" dominant-baseline="central">Value</text></svg>|svg}

let test_themed_scene_renders_every_field () =
  let rendered =
    Nopal_svg.render ~width:svg_width ~height:svg_height
      (scene_of_configs ~x_config:themed_x_config ~y_config:themed_y_config)
  in
  Alcotest.(check string)
    "themed axis chrome carries every appearance field" themed_svg rendered

let () =
  Alcotest.run "Axis.svg"
    [
      ( "svg",
        [
          Alcotest.test_case "default_scene_is_byte_identical" `Quick
            test_default_scene_is_byte_identical;
          Alcotest.test_case "themed_scene_renders_every_field" `Quick
            test_themed_scene_renders_every_field;
        ] );
    ]

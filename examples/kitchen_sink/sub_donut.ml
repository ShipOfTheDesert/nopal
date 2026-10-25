module Element = Nopal_element.Element
module Style = Nopal_style.Style
module Color = Nopal_scene.Color
module Scene = Nopal_scene.Scene

let cell = 40.0
let columns = 14
let rows = 7
let width = cell *. float_of_int columns
let height = cell *. float_of_int rows
let donut_size = height
let inner_radius = 70.0

let checker_light =
  Color.rgb ~r:(250.0 /. 255.0) ~g:(214.0 /. 255.0) ~b:(165.0 /. 255.0)

let checker_dark =
  Color.rgb ~r:(74.0 /. 255.0) ~g:(108.0 /. 255.0) ~b:(111.0 /. 255.0)

let checker_colour i j =
  match (i + j) mod 2 with
  | 0 -> checker_light
  | _ -> checker_dark

let checkerboard =
  List.concat
    (List.init rows (fun j ->
         List.init columns (fun i ->
             Scene.rect
               ~fill:(Nopal_scene.Paint.solid (checker_colour i j))
               ~x:(cell *. float_of_int i)
               ~y:(cell *. float_of_int j)
               ~w:cell ~h:cell ())))

let donut data =
  Nopal_charts.Pie.scene ~data
    ~value:(fun (_, v, _) -> v)
    ~label:(fun (l, _, _) -> l)
    ~color:(fun (_, _, c) -> c)
    ~width:donut_size ~height:donut_size ~inner_radius ()

let cat = Color.categorical

let scene =
  checkerboard
  @ donut
      [
        ("Desktop", 45.0, cat.(0));
        ("Mobile", 35.0, cat.(1));
        ("Tablet", 15.0, cat.(2));
        ("Other", 5.0, cat.(3));
      ]
  @ [
      Scene.group
        ~transforms:[ Nopal_scene.Transform.translate ~dx:donut_size ~dy:0.0 ]
        (donut [ ("All", 1.0, cat.(4)) ]);
    ]

let svg_src =
  "data:image/svg+xml,"
  ^ Nopal_fs_key.encode_key
      (Nopal_svg.render ~name:Nopal_element.Graphic_name.decorative ~width
         ~height scene)

let image_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with width = Some (Fixed width); height = Some (Fixed height) })

let view () =
  Element.column
    ~attrs:[ ("data-testid", "donut-section") ]
    [
      Element.text
        "Donut holes over a checkerboard, on canvas and as SVG (multi-segment, \
         then a single full turn):";
      Element.box
        ~attrs:[ ("data-testid", "donut-canvas") ]
        [
          Named_graphic.named_graphic
            "Device share donut and a single full ring, on a canvas over a \
             checkerboard" (fun name -> Element.draw ~name ~width ~height scene);
        ];
      Element.box
        ~attrs:[ ("data-testid", "donut-svg") ]
        [
          Named_graphic.named_graphic
            "Device share donut and a single full ring, as an SVG image over a \
             checkerboard" (fun name ->
              Element.image ~style:image_style ~src:svg_src ~name ());
        ];
    ]

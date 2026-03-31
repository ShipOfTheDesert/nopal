open Nopal_charts

let sample_data = [ (0.0, 10.0); (1.0, 20.0); (2.0, 15.0) ]

let series_a =
  Line.series ~smooth:false ~area_fill:false ~show_points:false ~label:"A"
    ~color:Nopal_draw.Color.categorical.(0)
    ~y:(fun (_, v) -> v)
    sample_data

let test_line_scene_to_svg () =
  let scene =
    Line.scene ~series:[ series_a ] ~x:fst ~width:400.0 ~height:300.0 ()
  in
  let svg = Nopal_svg.render ~width:400.0 ~height:300.0 scene in
  Alcotest.(check bool)
    "starts with <svg" true
    (String.length svg > 0 && String.sub svg 0 4 = "<svg");
  Alcotest.(check bool)
    "contains xmlns" true
    (let pat = "xmlns=" in
     let rec find i =
       if i + String.length pat > String.length svg then false
       else if String.sub svg i (String.length pat) = pat then true
       else find (i + 1)
     in
     find 0);
  Alcotest.(check bool)
    "contains viewBox" true
    (let pat = "viewBox=" in
     let rec find i =
       if i + String.length pat > String.length svg then false
       else if String.sub svg i (String.length pat) = pat then true
       else find (i + 1)
     in
     find 0);
  Alcotest.(check bool)
    "contains path or polyline" true
    (let has pat =
       let rec find i =
         if i + String.length pat > String.length svg then false
         else if String.sub svg i (String.length pat) = pat then true
         else find (i + 1)
       in
       find 0
     in
     has "<path" || has "<polyline");
  Alcotest.(check bool)
    "ends with </svg>" true
    (let suffix = "</svg>" in
     let len = String.length svg in
     let slen = String.length suffix in
     len >= slen && String.sub svg (len - slen) slen = suffix)

let test_sparkline_scene_to_svg () =
  let data = [ 10.0; 20.0; 15.0; 25.0; 18.0 ] in
  let scene = Sparkline.scene ~data ~width:100.0 ~height:30.0 () in
  let svg = Nopal_svg.render ~width:100.0 ~height:30.0 scene in
  Alcotest.(check bool)
    "starts with <svg" true
    (String.length svg > 0 && String.sub svg 0 4 = "<svg");
  Alcotest.(check bool)
    "contains polyline" true
    (let pat = "<polyline" in
     let rec find i =
       if i + String.length pat > String.length svg then false
       else if String.sub svg i (String.length pat) = pat then true
       else find (i + 1)
     in
     find 0);
  Alcotest.(check bool)
    "ends with </svg>" true
    (let suffix = "</svg>" in
     let len = String.length svg in
     let slen = String.length suffix in
     len >= slen && String.sub svg (len - slen) slen = suffix)

let () =
  Alcotest.run "Chart → SVG integration"
    [
      ( "integration",
        [
          Alcotest.test_case "line_scene_to_svg" `Quick test_line_scene_to_svg;
          Alcotest.test_case "sparkline_scene_to_svg" `Quick
            test_sparkline_scene_to_svg;
        ] );
    ]

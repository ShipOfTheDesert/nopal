open Nopal_element

type msg = Click | DblClick | Blur | KeyDown of string [@@warning "-37"]

let test_button_dblclick_some () =
  Alcotest.(check bool)
    "button with on_dblclick has Some" true
    (match Element.button ~on_dblclick:DblClick (Element.text "ok") with
    | Element.Button { on_dblclick = Some DblClick; _ } -> true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Checkbox _
    | Element.Radio _
    | Element.Select _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _
    | Element.Virtual_list _ ->
        false)

let test_input_blur_some () =
  Alcotest.(check bool)
    "input with on_blur has Some" true
    (match Element.input ~on_blur:Blur "val" with
    | Element.Input { on_blur = Some Blur; _ } -> true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Checkbox _
    | Element.Radio _
    | Element.Select _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _
    | Element.Virtual_list _ ->
        false)

let test_input_keydown_some () =
  let handler key = Some (KeyDown key) in
  Alcotest.(check bool)
    "input with on_keydown has Some" true
    (match Element.input ~on_keydown:handler "val" with
    | Element.Input { on_keydown = Some f; _ } -> (
        match f "Escape" with
        | Some (KeyDown "Escape") -> true
        | Some (Click | DblClick | Blur | KeyDown _)
        | None ->
            false)
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Checkbox _
    | Element.Radio _
    | Element.Select _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _
    | Element.Virtual_list _ ->
        false)

type wrapper = Wrapped of msg

let test_map_preserves_dblclick () =
  let el = Element.button ~on_dblclick:DblClick (Element.text "ok") in
  let mapped = Element.map (fun m -> Wrapped m) el in
  Alcotest.(check bool)
    "map transforms on_dblclick" true
    (match mapped with
    | Element.Button { on_dblclick = Some (Wrapped DblClick); _ } -> true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Checkbox _
    | Element.Radio _
    | Element.Select _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _
    | Element.Virtual_list _ ->
        false)

let test_map_preserves_blur () =
  let el = Element.input ~on_blur:Blur "val" in
  let mapped = Element.map (fun m -> Wrapped m) el in
  Alcotest.(check bool)
    "map transforms on_blur" true
    (match mapped with
    | Element.Input { on_blur = Some (Wrapped Blur); _ } -> true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Checkbox _
    | Element.Radio _
    | Element.Select _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _
    | Element.Virtual_list _ ->
        false)

let test_map_preserves_keydown () =
  let handler key = Some (KeyDown key) in
  let el = Element.input ~on_keydown:handler "val" in
  let mapped = Element.map (fun m -> Wrapped m) el in
  Alcotest.(check bool)
    "map transforms on_keydown" true
    (match mapped with
    | Element.Input { on_keydown = Some f; _ } -> (
        match f "Enter" with
        | Some (Wrapped (KeyDown "Enter")) -> true
        | Some (Wrapped (Click | DblClick | Blur | KeyDown _))
        | None ->
            false)
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Checkbox _
    | Element.Radio _
    | Element.Select _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _
    | Element.Virtual_list _ ->
        false)

let () =
  Alcotest.run "nopal_element_events"
    [
      ( "button_events",
        [ Alcotest.test_case "dblclick_some" `Quick test_button_dblclick_some ]
      );
      ( "input_events",
        [
          Alcotest.test_case "blur_some" `Quick test_input_blur_some;
          Alcotest.test_case "keydown_some" `Quick test_input_keydown_some;
        ] );
      ( "map_events",
        [
          Alcotest.test_case "map_preserves_dblclick" `Quick
            test_map_preserves_dblclick;
          Alcotest.test_case "map_preserves_blur" `Quick test_map_preserves_blur;
          Alcotest.test_case "map_preserves_keydown" `Quick
            test_map_preserves_keydown;
        ] );
    ]

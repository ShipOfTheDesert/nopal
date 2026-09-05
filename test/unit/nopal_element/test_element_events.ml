open Nopal_element

type msg = Click | DblClick | Focus | Blur | KeyDown of string
[@@warning "-37"]

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
    | Element.File_input _
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
    | Element.File_input _
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
        | Some (Click | DblClick | Focus | Blur | KeyDown _)
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
    | Element.File_input _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _
    | Element.Virtual_list _ ->
        false)

let test_box_focus_handlers_some () =
  Alcotest.(check bool)
    "box carries focusable, on_focus and on_blur" true
    (match
       Element.box ~focusable:true ~on_focus:Focus ~on_blur:Blur
         [ Element.text "panel" ]
     with
    | Element.Box
        { focusable = true; on_focus = Some Focus; on_blur = Some Blur; _ } ->
        true
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
    | Element.File_input _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _
    | Element.Virtual_list _ ->
        false)

let test_input_focus_some () =
  Alcotest.(check bool)
    "input carries on_focus alongside its existing on_blur" true
    (match Element.input ~on_focus:Focus ~on_blur:Blur "val" with
    | Element.Input { on_focus = Some Focus; on_blur = Some Blur; _ } -> true
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
    | Element.File_input _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _
    | Element.Virtual_list _ ->
        false)

type wrapper = Wrapped of msg

let test_map_preserves_box_focus () =
  let el =
    Element.box ~focusable:true ~on_focus:Focus ~on_blur:Blur
      [ Element.text "panel" ]
  in
  let mapped = Element.map (fun m -> Wrapped m) el in
  Alcotest.(check bool)
    "map transforms both box focus edges" true
    (match mapped with
    | Element.Box
        {
          focusable = true;
          on_focus = Some (Wrapped Focus);
          on_blur = Some (Wrapped Blur);
          _;
        } ->
        true
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
    | Element.File_input _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _
    | Element.Virtual_list _ ->
        false)

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
    | Element.File_input _
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
    | Element.File_input _
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
        | Some (Wrapped (Click | DblClick | Focus | Blur | KeyDown _))
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
    | Element.File_input _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _
    | Element.Virtual_list _ ->
        false)

let test_map_rewrites_file_input_handler () =
  let selection =
    [
      Element.file_info ~blob_id:"nopal-blob-1" ~name:"receipt.png" ~size:512
        ~mime:"image/png" ~last_modified:1_700_000_000_000.0;
    ]
  in
  let el =
    Element.file_input
      ~on_change:(fun files ->
        KeyDown (String.concat "," (List.map (fun f -> f.Element.name) files)))
      ()
  in
  let mapped = Element.map (fun m -> Wrapped m) el in
  Alcotest.(check bool)
    "map rewrites the file_info list handler" true
    (match mapped with
    | Element.File_input { on_change = Some f; _ } -> (
        match f selection with
        | Wrapped (KeyDown "receipt.png") -> true
        | Wrapped (Click | DblClick | Focus | Blur | KeyDown _) -> false)
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
    | Element.File_input _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _
    | Element.Virtual_list _ ->
        false)

(* The handler-absent arm of the same [map] case: a handlerless picker must
   survive the rewrite with its configuration intact and its handler still
   [None], rather than acquiring one or losing its config. *)
let test_map_preserves_handlerless_file_input () =
  let el =
    Element.file_input
      ~attrs:[ ("data-field", "receipt") ]
      ~accept:[ "image/*" ] ~capture:Element.Environment ~multiple:true ()
  in
  let mapped = Element.map (fun m -> Wrapped m) el in
  Alcotest.(check bool)
    "map preserves a file input with no handler" true
    (match mapped with
    | Element.File_input
        { on_change = None; accept; capture; multiple; attrs; _ } ->
        List.equal String.equal accept [ "image/*" ]
        && (match capture with
          | Some Element.Environment -> true
          | Some Element.User
          | None ->
              false)
        && multiple
        && List.equal
             (fun (k1, v1) (k2, v2) -> String.equal k1 k2 && String.equal v1 v2)
             attrs
             [ ("data-field", "receipt") ]
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
    | Element.File_input _
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
      ( "box_events",
        [
          Alcotest.test_case "box_focus_handlers_some" `Quick
            test_box_focus_handlers_some;
        ] );
      ( "input_events",
        [
          Alcotest.test_case "blur_some" `Quick test_input_blur_some;
          Alcotest.test_case "focus_some" `Quick test_input_focus_some;
          Alcotest.test_case "keydown_some" `Quick test_input_keydown_some;
        ] );
      ( "map_events",
        [
          Alcotest.test_case "map_preserves_dblclick" `Quick
            test_map_preserves_dblclick;
          Alcotest.test_case "map_preserves_blur" `Quick test_map_preserves_blur;
          Alcotest.test_case "map_preserves_box_focus" `Quick
            test_map_preserves_box_focus;
          Alcotest.test_case "map_preserves_keydown" `Quick
            test_map_preserves_keydown;
          Alcotest.test_case "map rewrites file_input handler" `Quick
            test_map_rewrites_file_input_handler;
          Alcotest.test_case "map preserves handlerless file_input" `Quick
            test_map_preserves_handlerless_file_input;
        ] );
    ]

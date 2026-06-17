open Nopal_test.Test_renderer

(* A native-clean platform instantiating the kitchen sink functor: navigation is
   stubbed and storage is the in-memory backend so the structural test stays
   browser-free (the tray section exercises neither). *)
module Test_platform : Nopal_platform.Platform.S = struct
  let current_path () = "/"
  let push_state (_ : string) = ()
  let replace_state (_ : string) = ()
  let back () = ()
  let on_popstate (_ : string -> unit) () = ()

  module Store = Nopal_storage.In_memory ()

  let storage = (module Store : Nopal_storage.S)
end

module K = Kitchen_sink_app.Make (Test_platform)
open K

let model0 () =
  let m, _ = init () in
  m

let present t (key, value) = Option.is_some (find (By_attr (key, value)) t)

(* REQ-F7 shrinks the tray surface to [on_click] only: the icon/tooltip/visibility
   controls (whose backends could never resolve) are gone. The single-click
   hide/restore flow is all that remains. A removed control's anchor reappearing
   in the section is a real regression — the surface-reduction guarantee broke. *)
let test_tray_section_has_no_removed_controls () =
  let t = tree (render (view_tauri_tray (model0 ()))) in
  List.iter
    (fun anchor ->
      Alcotest.(check bool) (snd anchor ^ " present") true (present t anchor))
    [ ("data-action", "tauri-tray-hide-window") ];
  List.iter
    (fun anchor ->
      Alcotest.(check bool) (snd anchor ^ " removed") false (present t anchor))
    [
      ("data-field", "tauri-tray-tooltip");
      ("data-action", "tauri-tray-set-tooltip");
      ("data-action", "tauri-tray-show-icon");
      ("data-action", "tauri-tray-hide-icon");
    ]

let () =
  Alcotest.run "kitchen_sink_tray_section"
    [
      ( "structure",
        [
          Alcotest.test_case "no removed controls" `Quick
            test_tray_section_has_no_removed_controls;
        ] );
    ]

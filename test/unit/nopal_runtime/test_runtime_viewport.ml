let sample_view rt view_fn =
  let root = Lwd.observe (view_fn rt) in
  let v = Lwd.quick_sample root in
  Lwd.quick_release root;
  v

(* App that renders viewport width into the view, so tests can verify
   which viewport was passed to view. *)
module Viewport_app : Nopal_mvu.App.S with type model = int and type msg = int =
struct
  type model = int
  type msg = int

  let init () = (0, Nopal_mvu.Cmd.none)
  let update model msg = (model + msg, Nopal_mvu.Cmd.none)

  let view vp _model =
    Nopal_element.Element.text (string_of_int (Nopal_element.Viewport.width vp))

  let subscriptions _model = Nopal_mvu.Sub.none
end

module R = Nopal_runtime.Runtime.Make (Viewport_app)

let test_initial_viewport () =
  let rt = R.create () in
  R.start rt;
  let v = sample_view rt R.view in
  Alcotest.(check bool)
    "initial view uses desktop viewport (1440)" true
    (Nopal_element.Element.equal v (Nopal_element.Element.text "1440"))

let test_viewport_passed_to_view () =
  let rt = R.create () in
  R.start rt;
  R.set_viewport rt Nopal_element.Viewport.phone;
  let v = sample_view rt R.view in
  Alcotest.(check bool)
    "view receives phone viewport (375)" true
    (Nopal_element.Element.equal v (Nopal_element.Element.text "375"))

let test_set_viewport_triggers_rerender () =
  let view_count = ref 0 in
  let module Counting_app :
    Nopal_mvu.App.S with type model = int and type msg = int = struct
    type model = int
    type msg = int

    let init () = (0, Nopal_mvu.Cmd.none)
    let update model msg = (model + msg, Nopal_mvu.Cmd.none)

    let view vp _model =
      incr view_count;
      Nopal_element.Element.text
        (string_of_int (Nopal_element.Viewport.width vp))

    let subscriptions _model = Nopal_mvu.Sub.none
  end in
  let module RC = Nopal_runtime.Runtime.Make (Counting_app) in
  let rt = RC.create () in
  RC.start rt;
  (* Sample initial view to establish baseline *)
  let _ = sample_view rt RC.view in
  view_count := 0;
  RC.set_viewport rt Nopal_element.Viewport.phone;
  let v = sample_view rt RC.view in
  Alcotest.(check bool)
    "view recomputed with phone viewport" true
    (Nopal_element.Element.equal v (Nopal_element.Element.text "375"));
  Alcotest.(check bool) "view was called at least once" true (!view_count > 0)

let test_set_viewport_noop_on_equal () =
  let view_count = ref 0 in
  let module Noop_app :
    Nopal_mvu.App.S with type model = int and type msg = int = struct
    type model = int
    type msg = int

    let init () = (0, Nopal_mvu.Cmd.none)
    let update model msg = (model + msg, Nopal_mvu.Cmd.none)

    let view vp _model =
      incr view_count;
      Nopal_element.Element.text
        (string_of_int (Nopal_element.Viewport.width vp))

    let subscriptions _model = Nopal_mvu.Sub.none
  end in
  let module RN = Nopal_runtime.Runtime.Make (Noop_app) in
  let rt = RN.create () in
  RN.start rt;
  (* Use a persistent observer so re-sampling only evaluates if dirty *)
  let root = Lwd.observe (RN.view rt) in
  let _ = Lwd.quick_sample root in
  view_count := 0;
  (* Set same viewport — desktop is the default *)
  RN.set_viewport rt Nopal_element.Viewport.desktop;
  let _ = Lwd.quick_sample root in
  Lwd.quick_release root;
  Alcotest.(check int)
    "view not recomputed when viewport unchanged" 0 !view_count

let test_set_viewport_fires_on_viewport_change_sub () =
  let received_widths = ref [] in
  let module Sub_app :
    Nopal_mvu.App.S with type model = int and type msg = int = struct
    type model = int
    type msg = int

    let init () = (0, Nopal_mvu.Cmd.none)

    let update model msg =
      received_widths := msg :: !received_widths;
      (model + msg, Nopal_mvu.Cmd.none)

    let view _vp model = Nopal_element.Element.text (string_of_int model)

    let subscriptions _model =
      Nopal_mvu.Sub.on_viewport_change "vp" (fun vp ->
          Nopal_element.Viewport.width vp)
  end in
  let module RS = Nopal_runtime.Runtime.Make (Sub_app) in
  let rt = RS.create () in
  RS.start rt;
  received_widths := [];
  RS.set_viewport rt Nopal_element.Viewport.phone;
  Alcotest.(check (list int))
    "on_viewport_change fires with phone width" [ 375 ] !received_widths;
  RS.set_viewport rt Nopal_element.Viewport.tablet;
  Alcotest.(check (list int))
    "on_viewport_change fires again with tablet width" [ 768; 375 ]
    !received_widths

let test_set_viewport_does_not_fire_sub_on_equal () =
  let fire_count = ref 0 in
  let module No_fire_app :
    Nopal_mvu.App.S with type model = int and type msg = int = struct
    type model = int
    type msg = int

    let init () = (0, Nopal_mvu.Cmd.none)
    let update model msg = (model + msg, Nopal_mvu.Cmd.none)
    let view _vp model = Nopal_element.Element.text (string_of_int model)

    let subscriptions _model =
      Nopal_mvu.Sub.on_viewport_change "vp" (fun _vp ->
          incr fire_count;
          0)
  end in
  let module RNF = Nopal_runtime.Runtime.Make (No_fire_app) in
  let rt = RNF.create () in
  RNF.start rt;
  fire_count := 0;
  (* Set same viewport — desktop is the default *)
  RNF.set_viewport rt Nopal_element.Viewport.desktop;
  Alcotest.(check int)
    "on_viewport_change does not fire when viewport unchanged" 0 !fire_count

let () =
  Alcotest.run "runtime_viewport"
    [
      ( "Viewport tracking",
        [
          Alcotest.test_case "initial viewport" `Quick test_initial_viewport;
          Alcotest.test_case "viewport passed to view" `Quick
            test_viewport_passed_to_view;
          Alcotest.test_case "set_viewport triggers rerender" `Quick
            test_set_viewport_triggers_rerender;
          Alcotest.test_case "set_viewport noop on equal" `Quick
            test_set_viewport_noop_on_equal;
          Alcotest.test_case "set_viewport fires on_viewport_change sub" `Quick
            test_set_viewport_fires_on_viewport_change_sub;
          Alcotest.test_case "set_viewport does not fire sub on equal" `Quick
            test_set_viewport_does_not_fire_sub_on_equal;
        ] );
    ]

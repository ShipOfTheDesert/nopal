let test_make_derives_size_class () =
  let open Nopal_element in
  let vp = Viewport.make ~width:375 ~height:812 () in
  Alcotest.(check bool)
    "375px is Compact" true
    (Size_class.equal (Viewport.size_class vp) Size_class.Compact)

let test_make_derives_portrait () =
  let open Nopal_element in
  let vp = Viewport.make ~width:375 ~height:812 () in
  Alcotest.(check bool)
    "375x812 is Portrait" true
    (Viewport.orientation vp = Viewport.Portrait)

let test_make_derives_landscape () =
  let open Nopal_element in
  let vp = Viewport.make ~width:1440 ~height:900 () in
  Alcotest.(check bool)
    "1440x900 is Landscape" true
    (Viewport.orientation vp = Viewport.Landscape)

let test_safe_area_defaults_to_zero () =
  let open Nopal_element in
  let vp = Viewport.make ~width:375 ~height:812 () in
  let sa = Viewport.safe_area vp in
  Alcotest.(check bool) "top = 0" true (Viewport.safe_area_top sa = 0);
  Alcotest.(check bool) "right = 0" true (Viewport.safe_area_right sa = 0);
  Alcotest.(check bool) "bottom = 0" true (Viewport.safe_area_bottom sa = 0);
  Alcotest.(check bool) "left = 0" true (Viewport.safe_area_left sa = 0)

let test_safe_area_custom () =
  let open Nopal_element in
  let sa = Viewport.make_safe_area ~top:44 ~right:0 ~bottom:34 ~left:0 () in
  let vp = Viewport.make ~width:375 ~height:812 ~safe_area:sa () in
  let sa' = Viewport.safe_area vp in
  Alcotest.(check int) "top = 44" 44 (Viewport.safe_area_top sa');
  Alcotest.(check int) "bottom = 34" 34 (Viewport.safe_area_bottom sa')

let test_is_compact () =
  let open Nopal_element in
  let vp = Viewport.make ~width:375 ~height:812 () in
  Alcotest.(check bool) "is_compact" true (Viewport.is_compact vp)

let test_is_medium () =
  let open Nopal_element in
  let vp = Viewport.make ~width:768 ~height:1024 () in
  Alcotest.(check bool) "is_medium" true (Viewport.is_medium vp)

let test_is_expanded () =
  let open Nopal_element in
  let vp = Viewport.make ~width:1440 ~height:900 () in
  Alcotest.(check bool) "is_expanded" true (Viewport.is_expanded vp)

let test_equal_same_viewport () =
  let open Nopal_element in
  let vp1 = Viewport.make ~width:375 ~height:812 () in
  let vp2 = Viewport.make ~width:375 ~height:812 () in
  Alcotest.(check bool) "same viewport" true (Viewport.equal vp1 vp2)

let test_equal_different_dimensions () =
  let open Nopal_element in
  let vp1 = Viewport.make ~width:375 ~height:812 () in
  let vp2 = Viewport.make ~width:768 ~height:1024 () in
  Alcotest.(check bool) "different dims" false (Viewport.equal vp1 vp2)

let test_equal_different_safe_area () =
  let open Nopal_element in
  let sa = Viewport.make_safe_area ~top:44 ~right:0 ~bottom:34 ~left:0 () in
  let vp1 = Viewport.make ~width:375 ~height:812 () in
  let vp2 = Viewport.make ~width:375 ~height:812 ~safe_area:sa () in
  Alcotest.(check bool) "different safe area" false (Viewport.equal vp1 vp2)

let test_preset_phone () =
  let open Nopal_element in
  let vp = Viewport.phone in
  Alcotest.(check int) "width = 375" 375 (Viewport.width vp);
  Alcotest.(check int) "height = 812" 812 (Viewport.height vp);
  Alcotest.(check bool)
    "is Compact" true
    (Size_class.equal (Viewport.size_class vp) Size_class.Compact)

let test_preset_phone_landscape () =
  let open Nopal_element in
  let vp = Viewport.phone_landscape in
  Alcotest.(check int) "width = 812" 812 (Viewport.width vp);
  Alcotest.(check int) "height = 375" 375 (Viewport.height vp);
  Alcotest.(check bool)
    "is Medium" true
    (Size_class.equal (Viewport.size_class vp) Size_class.Medium);
  Alcotest.(check bool)
    "is Landscape" true
    (Viewport.orientation vp = Viewport.Landscape)

let test_preset_tablet () =
  let open Nopal_element in
  let vp = Viewport.tablet in
  Alcotest.(check int) "width = 768" 768 (Viewport.width vp);
  Alcotest.(check int) "height = 1024" 1024 (Viewport.height vp);
  Alcotest.(check bool)
    "is Medium" true
    (Size_class.equal (Viewport.size_class vp) Size_class.Medium)

let test_preset_desktop () =
  let open Nopal_element in
  let vp = Viewport.desktop in
  Alcotest.(check int) "width = 1440" 1440 (Viewport.width vp);
  Alcotest.(check int) "height = 900" 900 (Viewport.height vp);
  Alcotest.(check bool)
    "is Expanded" true
    (Size_class.equal (Viewport.size_class vp) Size_class.Expanded)

let () =
  Alcotest.run "Viewport"
    [
      ( "make",
        [
          Alcotest.test_case "derives size class" `Quick
            test_make_derives_size_class;
          Alcotest.test_case "derives portrait" `Quick
            test_make_derives_portrait;
          Alcotest.test_case "derives landscape" `Quick
            test_make_derives_landscape;
        ] );
      ( "safe_area",
        [
          Alcotest.test_case "defaults to zero" `Quick
            test_safe_area_defaults_to_zero;
          Alcotest.test_case "custom" `Quick test_safe_area_custom;
        ] );
      ( "convenience",
        [
          Alcotest.test_case "is_compact" `Quick test_is_compact;
          Alcotest.test_case "is_medium" `Quick test_is_medium;
          Alcotest.test_case "is_expanded" `Quick test_is_expanded;
        ] );
      ( "equal",
        [
          Alcotest.test_case "same viewport" `Quick test_equal_same_viewport;
          Alcotest.test_case "different dimensions" `Quick
            test_equal_different_dimensions;
          Alcotest.test_case "different safe area" `Quick
            test_equal_different_safe_area;
        ] );
      ( "presets",
        [
          Alcotest.test_case "phone" `Quick test_preset_phone;
          Alcotest.test_case "phone_landscape" `Quick
            test_preset_phone_landscape;
          Alcotest.test_case "tablet" `Quick test_preset_tablet;
          Alcotest.test_case "desktop" `Quick test_preset_desktop;
        ] );
    ]

let test_on_viewport_change_key () =
  let sub = Nopal_mvu.Sub.on_viewport_change "vp" (fun _vp -> `Changed) in
  Alcotest.(check (list string))
    "on_viewport_change has key" [ "vp" ] (Nopal_mvu.Sub.keys sub)

let test_on_viewport_change_extract () =
  let sub =
    Nopal_mvu.Sub.on_viewport_change "vp" (fun vp ->
        Nopal_element.Viewport.width vp)
  in
  match Nopal_mvu.Sub.extract_on_viewport_change sub with
  | Some f ->
      let vp = Nopal_element.Viewport.phone in
      Alcotest.(check int) "extract roundtrips" 375 (f vp)
  | None -> Alcotest.fail "expected Some from extract_on_viewport_change"

let test_on_viewport_change_map () =
  let sub =
    Nopal_mvu.Sub.on_viewport_change "vp" (fun vp ->
        Nopal_element.Viewport.width vp)
  in
  let mapped = Nopal_mvu.Sub.map (fun w -> w * 2) sub in
  match Nopal_mvu.Sub.extract_on_viewport_change mapped with
  | Some f ->
      let vp = Nopal_element.Viewport.phone in
      Alcotest.(check int) "map transforms on_viewport_change" 750 (f vp)
  | None ->
      Alcotest.fail "expected Some from extract_on_viewport_change on mapped"

let test_extract_on_viewport_changes_flattens_batch () =
  let sub =
    Nopal_mvu.Sub.batch
      [
        Nopal_mvu.Sub.on_viewport_change "vp1" (fun vp ->
            Nopal_element.Viewport.width vp);
        Nopal_mvu.Sub.on_viewport_change "vp2" (fun vp ->
            Nopal_element.Viewport.height vp);
        Nopal_mvu.Sub.none;
      ]
  in
  let entries = Nopal_mvu.Sub.extract_on_viewport_changes sub in
  Alcotest.(check int) "two entries extracted" 2 (List.length entries);
  let keys = List.map fst entries in
  Alcotest.(check (list string)) "keys match" [ "vp1"; "vp2" ] keys;
  let vp = Nopal_element.Viewport.phone in
  let values = List.map (fun (_k, f) -> f vp) entries in
  Alcotest.(check (list int)) "values match" [ 375; 812 ] values

let () =
  Alcotest.run "nopal_mvu_sub_viewport"
    [
      ( "Sub.on_viewport_change",
        [
          Alcotest.test_case "key" `Quick test_on_viewport_change_key;
          Alcotest.test_case "extract roundtrips" `Quick
            test_on_viewport_change_extract;
          Alcotest.test_case "map transforms" `Quick test_on_viewport_change_map;
          Alcotest.test_case "extract_changes flattens batch" `Quick
            test_extract_on_viewport_changes_flattens_batch;
        ] );
    ]

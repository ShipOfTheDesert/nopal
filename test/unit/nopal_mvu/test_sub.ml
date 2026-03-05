let test_sub_none_has_no_keys () =
  Alcotest.(check (list string))
    "none has no keys" []
    (Nopal_mvu.Sub.keys Nopal_mvu.Sub.none)

let test_sub_batch_merges_keys () =
  let a = Nopal_mvu.Sub.every "tick" 1000 (fun () -> `Tick) in
  let b = Nopal_mvu.Sub.on_keydown "kd" (fun k -> `Key k) in
  let sub = Nopal_mvu.Sub.batch [ a; b ] in
  let ks = Nopal_mvu.Sub.keys sub in
  Alcotest.(check (list string)) "batch merges keys" [ "tick"; "kd" ] ks

let test_sub_every_key () =
  let sub = Nopal_mvu.Sub.every "tick" 1000 (fun () -> `Tick) in
  Alcotest.(check (list string))
    "every has key" [ "tick" ] (Nopal_mvu.Sub.keys sub)

let test_sub_every_fires () =
  let sub = Nopal_mvu.Sub.every "tick" 1000 (fun () -> 42) in
  match Nopal_mvu.Sub.extract_every sub with
  | Some (ms, f) ->
      Alcotest.(check int) "interval is 1000" 1000 ms;
      Alcotest.(check int) "fires expected message" 42 (f ())
  | None -> Alcotest.fail "expected Some from extract_every"

let test_sub_on_keydown_key () =
  let sub = Nopal_mvu.Sub.on_keydown "kd" (fun _k -> `Down) in
  Alcotest.(check (list string))
    "on_keydown has key" [ "kd" ] (Nopal_mvu.Sub.keys sub)

let test_sub_on_keydown_callback () =
  let sub = Nopal_mvu.Sub.on_keydown "kd" (fun k -> "pressed:" ^ k) in
  match Nopal_mvu.Sub.extract_on_keydown sub with
  | Some f ->
      Alcotest.(check string)
        "callback produces msg" "pressed:Enter" (f "Enter")
  | None -> Alcotest.fail "expected Some from extract_on_keydown"

let test_sub_on_keyup_key () =
  let sub = Nopal_mvu.Sub.on_keyup "ku" (fun _k -> `Up) in
  Alcotest.(check (list string))
    "on_keyup has key" [ "ku" ] (Nopal_mvu.Sub.keys sub)

let test_sub_on_resize_key () =
  let sub = Nopal_mvu.Sub.on_resize "rs" (fun _w _h -> `Resized) in
  Alcotest.(check (list string))
    "on_resize has key" [ "rs" ] (Nopal_mvu.Sub.keys sub)

let test_sub_on_resize_callback () =
  let sub = Nopal_mvu.Sub.on_resize "rs" (fun w h -> (w, h)) in
  match Nopal_mvu.Sub.extract_on_resize sub with
  | Some f ->
      Alcotest.(check (pair int int))
        "callback produces msg" (800, 600) (f 800 600)
  | None -> Alcotest.fail "expected Some from extract_on_resize"

let test_sub_on_visibility_change_key () =
  let sub = Nopal_mvu.Sub.on_visibility_change "vc" (fun _v -> `Vis) in
  Alcotest.(check (list string))
    "on_visibility_change has key" [ "vc" ] (Nopal_mvu.Sub.keys sub)

let test_sub_on_visibility_change_callback () =
  let sub = Nopal_mvu.Sub.on_visibility_change "vc" (fun v -> v) in
  match Nopal_mvu.Sub.extract_on_visibility_change sub with
  | Some f -> Alcotest.(check bool) "callback produces msg" true (f true)
  | None -> Alcotest.fail "expected Some from extract_on_visibility_change"

let test_sub_custom_key () =
  let sub = Nopal_mvu.Sub.custom "c" (fun _dispatch -> fun () -> ()) in
  Alcotest.(check (list string))
    "custom has key" [ "c" ] (Nopal_mvu.Sub.keys sub)

let test_sub_custom_setup_cleanup () =
  let cleaned_up = ref false in
  let sub =
    Nopal_mvu.Sub.custom "c" (fun _dispatch -> fun () -> cleaned_up := true)
  in
  match Nopal_mvu.Sub.extract_custom sub with
  | Some setup ->
      let cleanup = setup (fun _msg -> ()) in
      cleanup ();
      Alcotest.(check bool) "cleanup was called" true !cleaned_up
  | None -> Alcotest.fail "expected Some from extract_custom"

let test_sub_keys_deduplication () =
  let a = Nopal_mvu.Sub.every "same" 1000 (fun () -> `A) in
  let b = Nopal_mvu.Sub.every "same" 2000 (fun () -> `B) in
  let sub = Nopal_mvu.Sub.batch [ a; b ] in
  let ks = Nopal_mvu.Sub.keys sub in
  Alcotest.(check (list string)) "deduplicated keys" [ "same" ] ks

let test_sub_map_transforms () =
  let sub = Nopal_mvu.Sub.every "tick" 1000 (fun () -> 10) in
  let mapped = Nopal_mvu.Sub.map (fun n -> n * 3) sub in
  match Nopal_mvu.Sub.extract_every mapped with
  | Some (_ms, f) -> Alcotest.(check int) "map transforms" 30 (f ())
  | None -> Alcotest.fail "expected Some from extract_every on mapped"

let test_sub_on_keyup_callback () =
  let sub = Nopal_mvu.Sub.on_keyup "ku" (fun k -> "released:" ^ k) in
  match Nopal_mvu.Sub.extract_on_keyup sub with
  | Some f ->
      Alcotest.(check string)
        "callback produces msg" "released:Escape" (f "Escape")
  | None -> Alcotest.fail "expected Some from extract_on_keyup"

let test_sub_map_on_keydown () =
  let sub = Nopal_mvu.Sub.on_keydown "kd" (fun k -> k) in
  let mapped = Nopal_mvu.Sub.map (fun s -> String.uppercase_ascii s) sub in
  match Nopal_mvu.Sub.extract_on_keydown mapped with
  | Some f ->
      Alcotest.(check string) "map transforms on_keydown" "ENTER" (f "Enter")
  | None -> Alcotest.fail "expected Some from extract_on_keydown on mapped"

let test_sub_map_on_keyup () =
  let sub = Nopal_mvu.Sub.on_keyup "ku" (fun k -> k) in
  let mapped = Nopal_mvu.Sub.map (fun s -> String.length s) sub in
  match Nopal_mvu.Sub.extract_on_keyup mapped with
  | Some f -> Alcotest.(check int) "map transforms on_keyup" 6 (f "Escape")
  | None -> Alcotest.fail "expected Some from extract_on_keyup on mapped"

let test_sub_map_on_resize () =
  let sub = Nopal_mvu.Sub.on_resize "rs" (fun w h -> w * h) in
  let mapped = Nopal_mvu.Sub.map (fun area -> area / 100) sub in
  match Nopal_mvu.Sub.extract_on_resize mapped with
  | Some f -> Alcotest.(check int) "map transforms on_resize" 4800 (f 800 600)
  | None -> Alcotest.fail "expected Some from extract_on_resize on mapped"

let test_sub_map_on_visibility_change () =
  let sub = Nopal_mvu.Sub.on_visibility_change "vc" (fun v -> v) in
  let mapped = Nopal_mvu.Sub.map (fun b -> not b) sub in
  match Nopal_mvu.Sub.extract_on_visibility_change mapped with
  | Some f ->
      Alcotest.(check bool) "map transforms on_visibility_change" false (f true)
  | None ->
      Alcotest.fail "expected Some from extract_on_visibility_change on mapped"

let test_sub_map_custom () =
  let dispatched = ref [] in
  let sub =
    Nopal_mvu.Sub.custom "c" (fun dispatch ->
        dispatch 10;
        fun () -> ())
  in
  let mapped = Nopal_mvu.Sub.map (fun n -> n * 5) sub in
  match Nopal_mvu.Sub.extract_custom mapped with
  | Some setup ->
      let _cleanup = setup (fun msg -> dispatched := msg :: !dispatched) in
      Alcotest.(check (list int)) "map transforms custom" [ 50 ] !dispatched
  | None -> Alcotest.fail "expected Some from extract_custom on mapped"

let test_sub_map_batch () =
  let sub =
    Nopal_mvu.Sub.batch
      [
        Nopal_mvu.Sub.every "a" 100 (fun () -> 1);
        Nopal_mvu.Sub.every "b" 200 (fun () -> 2);
      ]
  in
  let mapped = Nopal_mvu.Sub.map (fun n -> n + 10) sub in
  let ks = Nopal_mvu.Sub.keys mapped in
  Alcotest.(check (list string)) "map preserves batch keys" [ "a"; "b" ] ks

(* sub_is_opaque: REQ-F17 is enforced at compile time by sub.mli.
   User code cannot pattern-match on Sub.t because the type is abstract. *)

let () =
  Alcotest.run "nopal_mvu_sub"
    [
      ( "Sub",
        [
          Alcotest.test_case "none has no keys" `Quick test_sub_none_has_no_keys;
          Alcotest.test_case "batch merges keys" `Quick
            test_sub_batch_merges_keys;
          Alcotest.test_case "every key" `Quick test_sub_every_key;
          Alcotest.test_case "every fires" `Quick test_sub_every_fires;
          Alcotest.test_case "on_keydown key" `Quick test_sub_on_keydown_key;
          Alcotest.test_case "on_keydown callback" `Quick
            test_sub_on_keydown_callback;
          Alcotest.test_case "on_keyup key" `Quick test_sub_on_keyup_key;
          Alcotest.test_case "on_keyup callback" `Quick
            test_sub_on_keyup_callback;
          Alcotest.test_case "on_resize key" `Quick test_sub_on_resize_key;
          Alcotest.test_case "on_resize callback" `Quick
            test_sub_on_resize_callback;
          Alcotest.test_case "on_visibility_change key" `Quick
            test_sub_on_visibility_change_key;
          Alcotest.test_case "on_visibility_change callback" `Quick
            test_sub_on_visibility_change_callback;
          Alcotest.test_case "custom key" `Quick test_sub_custom_key;
          Alcotest.test_case "custom setup/cleanup" `Quick
            test_sub_custom_setup_cleanup;
          Alcotest.test_case "keys deduplication" `Quick
            test_sub_keys_deduplication;
          Alcotest.test_case "map transforms" `Quick test_sub_map_transforms;
          Alcotest.test_case "map on_keydown" `Quick test_sub_map_on_keydown;
          Alcotest.test_case "map on_keyup" `Quick test_sub_map_on_keyup;
          Alcotest.test_case "map on_resize" `Quick test_sub_map_on_resize;
          Alcotest.test_case "map on_visibility_change" `Quick
            test_sub_map_on_visibility_change;
          Alcotest.test_case "map custom" `Quick test_sub_map_custom;
          Alcotest.test_case "map batch" `Quick test_sub_map_batch;
        ] );
    ]

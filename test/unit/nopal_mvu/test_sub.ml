let test_sub_none_has_no_keys () =
  Alcotest.(check (list string))
    "none has no keys" []
    (Nopal_mvu.Sub.keys Nopal_mvu.Sub.none)

let test_sub_batch_merges_keys () =
  let a = Nopal_mvu.Sub.every "tick" 1000 (fun () -> `Tick) in
  let b = Nopal_mvu.Sub.on_keydown "kd" (fun k -> Some (`Key k, false)) in
  let sub = Nopal_mvu.Sub.batch [ a; b ] in
  let ks = Nopal_mvu.Sub.keys sub in
  Alcotest.(check (list string)) "batch merges keys" [ "tick"; "kd" ] ks

let test_sub_every_key () =
  let sub = Nopal_mvu.Sub.every "tick" 1000 (fun () -> `Tick) in
  Alcotest.(check (list string))
    "every has key" [ "tick" ] (Nopal_mvu.Sub.keys sub)

let test_sub_every_fires () =
  let sub = Nopal_mvu.Sub.every "tick" 1000 (fun () -> 42) in
  match Nopal_mvu.Sub.atoms sub with
  | [ Every { interval_ms; tick; _ } ] ->
      Alcotest.(check int) "interval is 1000" 1000 interval_ms;
      Alcotest.(check int) "fires expected message" 42 (tick ())
  | _ -> Alcotest.fail "expected a single Every atom"

let test_sub_on_keydown_key () =
  let sub = Nopal_mvu.Sub.on_keydown "kd" (fun _k -> Some (`Down, false)) in
  Alcotest.(check (list string))
    "on_keydown has key" [ "kd" ] (Nopal_mvu.Sub.keys sub)

let test_sub_on_keydown_callback () =
  let sub =
    Nopal_mvu.Sub.on_keydown "kd" (fun k -> Some ("pressed:" ^ k, false))
  in
  match Nopal_mvu.Sub.atoms sub with
  | [ Keydown { handler; _ } ] ->
      Alcotest.(check (option (pair string bool)))
        "handler produces (msg, prevent)"
        (Some ("pressed:Enter", false))
        (handler "Enter")
  | _ -> Alcotest.fail "expected a single Keydown atom"

let test_sub_on_keydown_prevent_and_ignore () =
  (* The unified on_keydown carries the preventDefault flag and may ignore a
     key with None. *)
  let sub =
    Nopal_mvu.Sub.on_keydown "kd" (fun k ->
        match k with
        | "Tab" -> Some ("trap", true)
        | _ -> Option.none)
  in
  match Nopal_mvu.Sub.atoms sub with
  | [ Keydown { handler; _ } ] ->
      Alcotest.(check (option (pair string bool)))
        "matched key dispatches and prevents"
        (Some ("trap", true))
        (handler "Tab");
      Alcotest.(check (option (pair string bool)))
        "unmatched key is ignored" Option.none (handler "Escape")
  | _ -> Alcotest.fail "expected a single Keydown atom"

let test_sub_on_key_matches_only_target () =
  let sub = Nopal_mvu.Sub.on_key "esc" ~key:"Escape" ~prevent:true `Closed in
  Alcotest.(check (list string))
    "on_key has key" [ "esc" ] (Nopal_mvu.Sub.keys sub);
  match Nopal_mvu.Sub.atoms sub with
  | [ Keydown { handler; _ } ] ->
      (match handler "Escape" with
      | Some (msg, prevent) ->
          Alcotest.(check bool) "target key dispatches" true (msg = `Closed);
          Alcotest.(check bool) "target key prevents default" true prevent
      | Option.None -> Alcotest.fail "expected Some for the target key");
      Alcotest.(check bool)
        "non-target key ignored" true
        (Option.is_none (handler "Tab"))
  | _ -> Alcotest.fail "expected a single Keydown atom"

let test_sub_on_keyup_key () =
  let sub = Nopal_mvu.Sub.on_keyup "ku" (fun _k -> Some `Up) in
  Alcotest.(check (list string))
    "on_keyup has key" [ "ku" ] (Nopal_mvu.Sub.keys sub)

let test_sub_on_keyup_filters_none () =
  let sub =
    Nopal_mvu.Sub.on_keyup "ku" (fun k ->
        if String.equal k "a" then Some `A else Option.none)
  in
  match Nopal_mvu.Sub.atoms sub with
  | [ Keyup { handler; _ } ] ->
      Alcotest.(check bool)
        "matched keyup dispatches" true
        (handler "a" = Some `A);
      Alcotest.(check bool)
        "unmatched keyup is dropped" true
        (Option.is_none (handler "b"))
  | _ -> Alcotest.fail "expected a single Keyup atom"

let test_sub_on_resize_key () =
  let sub = Nopal_mvu.Sub.on_resize "rs" (fun _w _h -> `Resized) in
  Alcotest.(check (list string))
    "on_resize has key" [ "rs" ] (Nopal_mvu.Sub.keys sub)

let test_sub_on_resize_callback () =
  let sub = Nopal_mvu.Sub.on_resize "rs" (fun w h -> (w, h)) in
  match Nopal_mvu.Sub.atoms sub with
  | [ Resize { handler; _ } ] ->
      Alcotest.(check (pair int int))
        "handler produces msg" (800, 600) (handler 800 600)
  | _ -> Alcotest.fail "expected a single Resize atom"

let test_sub_on_visibility_change_key () =
  let sub = Nopal_mvu.Sub.on_visibility_change "vc" (fun _v -> `Vis) in
  Alcotest.(check (list string))
    "on_visibility_change has key" [ "vc" ] (Nopal_mvu.Sub.keys sub)

let test_sub_on_visibility_change_callback () =
  let sub = Nopal_mvu.Sub.on_visibility_change "vc" (fun v -> v) in
  match Nopal_mvu.Sub.atoms sub with
  | [ Visibility { handler; _ } ] ->
      Alcotest.(check bool) "handler produces msg" true (handler true)
  | _ -> Alcotest.fail "expected a single Visibility atom"

let test_sub_custom_key () =
  let sub = Nopal_mvu.Sub.custom "c" (fun _dispatch -> fun () -> ()) in
  Alcotest.(check (list string))
    "custom has key" [ "c" ] (Nopal_mvu.Sub.keys sub)

let test_sub_custom_setup_cleanup () =
  let cleaned_up = ref false in
  let sub =
    Nopal_mvu.Sub.custom "c" (fun _dispatch -> fun () -> cleaned_up := true)
  in
  match Nopal_mvu.Sub.atoms sub with
  | [ Custom { setup; _ } ] ->
      let cleanup = setup (fun _msg -> ()) in
      cleanup ();
      Alcotest.(check bool) "cleanup was called" true !cleaned_up
  | _ -> Alcotest.fail "expected a single Custom atom"

let test_sub_keys_deduplication () =
  let a = Nopal_mvu.Sub.every "same" 1000 (fun () -> `A) in
  let b = Nopal_mvu.Sub.every "same" 2000 (fun () -> `B) in
  let sub = Nopal_mvu.Sub.batch [ a; b ] in
  let ks = Nopal_mvu.Sub.keys sub in
  Alcotest.(check (list string)) "deduplicated keys" [ "same" ] ks

let test_sub_map_transforms () =
  let sub = Nopal_mvu.Sub.every "tick" 1000 (fun () -> 10) in
  let mapped = Nopal_mvu.Sub.map (fun n -> n * 3) sub in
  match Nopal_mvu.Sub.atoms mapped with
  | [ Every { tick; _ } ] -> Alcotest.(check int) "map transforms" 30 (tick ())
  | _ -> Alcotest.fail "expected a single Every atom on mapped"

let test_sub_on_keyup_callback () =
  let sub = Nopal_mvu.Sub.on_keyup "ku" (fun k -> Some ("released:" ^ k)) in
  match Nopal_mvu.Sub.atoms sub with
  | [ Keyup { handler; _ } ] ->
      Alcotest.(check (option string))
        "handler produces msg" (Some "released:Escape") (handler "Escape")
  | _ -> Alcotest.fail "expected a single Keyup atom"

let test_sub_map_on_keydown () =
  let sub = Nopal_mvu.Sub.on_keydown "kd" (fun k -> Some (k, false)) in
  let mapped = Nopal_mvu.Sub.map (fun s -> String.uppercase_ascii s) sub in
  match Nopal_mvu.Sub.atoms mapped with
  | [ Keydown { handler; _ } ] ->
      Alcotest.(check (option (pair string bool)))
        "map transforms keydown msg, preserves prevent"
        (Some ("ENTER", false))
        (handler "Enter")
  | _ -> Alcotest.fail "expected a single Keydown atom on mapped"

let test_sub_map_on_keyup () =
  let sub = Nopal_mvu.Sub.on_keyup "ku" (fun k -> Some k) in
  let mapped = Nopal_mvu.Sub.map (fun s -> String.length s) sub in
  match Nopal_mvu.Sub.atoms mapped with
  | [ Keyup { handler; _ } ] ->
      Alcotest.(check (option int))
        "map transforms keyup msg" (Some 6) (handler "Escape")
  | _ -> Alcotest.fail "expected a single Keyup atom on mapped"

let test_sub_map_on_resize () =
  let sub = Nopal_mvu.Sub.on_resize "rs" (fun w h -> w * h) in
  let mapped = Nopal_mvu.Sub.map (fun area -> area / 100) sub in
  match Nopal_mvu.Sub.atoms mapped with
  | [ Resize { handler; _ } ] ->
      Alcotest.(check int) "map transforms on_resize" 4800 (handler 800 600)
  | _ -> Alcotest.fail "expected a single Resize atom on mapped"

let test_sub_map_on_visibility_change () =
  let sub = Nopal_mvu.Sub.on_visibility_change "vc" (fun v -> v) in
  let mapped = Nopal_mvu.Sub.map (fun b -> not b) sub in
  match Nopal_mvu.Sub.atoms mapped with
  | [ Visibility { handler; _ } ] ->
      Alcotest.(check bool)
        "map transforms on_visibility_change" false (handler true)
  | _ -> Alcotest.fail "expected a single Visibility atom on mapped"

let test_sub_map_custom () =
  let dispatched = ref [] in
  let sub =
    Nopal_mvu.Sub.custom "c" (fun dispatch ->
        dispatch 10;
        fun () -> ())
  in
  let mapped = Nopal_mvu.Sub.map (fun n -> n * 5) sub in
  match Nopal_mvu.Sub.atoms mapped with
  | [ Custom { setup; _ } ] ->
      let _cleanup = setup (fun msg -> dispatched := msg :: !dispatched) in
      Alcotest.(check (list int)) "map transforms custom" [ 50 ] !dispatched
  | _ -> Alcotest.fail "expected a single Custom atom on mapped"

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

let atom_key (type msg) (a : msg Nopal_mvu.Sub.atom) =
  let open Nopal_mvu.Sub in
  match a with
  | Every { key; _ } -> key
  | Keydown { key; _ } -> key
  | Keyup { key; _ } -> key
  | Resize { key; _ } -> key
  | Visibility { key; _ } -> key
  | Viewport { key; _ } -> key
  | Custom { key; _ } -> key

let test_atoms_of_none_is_empty () =
  Alcotest.(check int)
    "atoms of none is empty" 0
    (List.length (Nopal_mvu.Sub.atoms Nopal_mvu.Sub.none))

let test_atoms_flattens_nested_batches () =
  let sub =
    Nopal_mvu.Sub.batch
      [
        Nopal_mvu.Sub.batch
          [
            Nopal_mvu.Sub.every "a" 100 (fun () -> `A);
            Nopal_mvu.Sub.on_keydown "b" (fun _ -> Some (`B, false));
          ];
        Nopal_mvu.Sub.batch
          [
            Nopal_mvu.Sub.on_keyup "c" (fun _ -> Some `C);
            Nopal_mvu.Sub.custom "d" (fun _dispatch -> fun () -> ());
          ];
      ]
  in
  let ks = List.map atom_key (Nopal_mvu.Sub.atoms sub) in
  Alcotest.(check (list string))
    "atoms flattens nested batches preserving order" [ "a"; "b"; "c"; "d" ] ks

let test_atoms_applies_map_to_handler_results () =
  let sub = Nopal_mvu.Sub.on_keydown "kd" (fun k -> Some ("got:" ^ k, false)) in
  let mapped = Nopal_mvu.Sub.map String.uppercase_ascii sub in
  match Nopal_mvu.Sub.atoms mapped with
  | [ Keydown { handler; _ } ] -> (
      match handler "enter" with
      | Some (msg, prevent) ->
          Alcotest.(check string)
            "mapped message comes out of the keydown atom handler" "GOT:ENTER"
            msg;
          Alcotest.(check bool)
            "prevent flag is carried through map" false prevent
      | Option.None -> Alcotest.fail "expected Some from keydown atom handler")
  | _ -> Alcotest.fail "expected a single Keydown atom"

let test_describe_atom_labels_each_constructor () =
  let open Nopal_mvu.Sub in
  let label_of sub =
    match atoms sub with
    | [ atom ] -> describe_atom atom
    | _ -> Alcotest.fail "expected a single atom"
  in
  Alcotest.(check string)
    "every" "every"
    (label_of (every "k" 100 (fun () -> 0)));
  Alcotest.(check string)
    "keydown" "keydown"
    (label_of (on_keydown "k" (fun _ -> Some (0, false))));
  Alcotest.(check string)
    "keyup" "keyup"
    (label_of (on_keyup "k" (fun _ -> Some 0)));
  Alcotest.(check string)
    "resize" "resize"
    (label_of (on_resize "k" (fun _ _ -> 0)));
  Alcotest.(check string)
    "visibility" "visibility"
    (label_of (on_visibility_change "k" (fun _ -> 0)));
  Alcotest.(check string)
    "viewport" "viewport"
    (label_of
       (on_viewport_change "k" (fun (_ : Nopal_element.Viewport.t) -> 0)));
  Alcotest.(check string)
    "custom" "custom"
    (label_of (custom "k" (fun _dispatch -> fun () -> ())))

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
          Alcotest.test_case "on_keydown prevent and ignore" `Quick
            test_sub_on_keydown_prevent_and_ignore;
          Alcotest.test_case "on_key matches only target" `Quick
            test_sub_on_key_matches_only_target;
          Alcotest.test_case "on_keyup key" `Quick test_sub_on_keyup_key;
          Alcotest.test_case "on_keyup filters none" `Quick
            test_sub_on_keyup_filters_none;
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
          Alcotest.test_case "atoms of none is empty" `Quick
            test_atoms_of_none_is_empty;
          Alcotest.test_case "atoms flattens nested batches" `Quick
            test_atoms_flattens_nested_batches;
          Alcotest.test_case "atoms applies map to handler results" `Quick
            test_atoms_applies_map_to_handler_results;
          Alcotest.test_case "describe_atom labels each constructor" `Quick
            test_describe_atom_labels_each_constructor;
        ] );
    ]

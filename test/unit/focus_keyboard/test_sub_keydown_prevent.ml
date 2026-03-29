type msg = Got of string * bool | Wrapped of msg

let test_keydown_prevent_extract () =
  let f key =
    match key with
    | "Tab" -> Some (Got ("Tab", true), true)
    | _ -> Option.none
  in
  let sub = Nopal_mvu.Sub.on_keydown_prevent "trap" f in
  match Nopal_mvu.Sub.extract_on_keydown_prevent sub with
  | Some extracted ->
      Alcotest.(check bool) "callback is extractable" true (extracted == f)
  | Option.None -> Alcotest.fail "expected Some, got None"

let test_keydown_prevent_callback_some_true () =
  let f key =
    match key with
    | "Tab" -> Some (Got ("Tab", true), true)
    | _ -> Option.none
  in
  let sub = Nopal_mvu.Sub.on_keydown_prevent "trap" f in
  match Nopal_mvu.Sub.extract_on_keydown_prevent sub with
  | Some extracted -> (
      match extracted "Tab" with
      | Some (Got ("Tab", true), true) ->
          Alcotest.(check pass) "callback returns Some (msg, true)" () ()
      | Some _ -> Alcotest.fail "unexpected callback result"
      | Option.None -> Alcotest.fail "expected Some, got None from callback")
  | Option.None -> Alcotest.fail "expected Some from extract"

let test_keydown_prevent_callback_none () =
  let f key =
    match key with
    | "Tab" -> Some (Got ("Tab", true), true)
    | _ -> Option.none
  in
  let sub = Nopal_mvu.Sub.on_keydown_prevent "trap" f in
  match Nopal_mvu.Sub.extract_on_keydown_prevent sub with
  | Some extracted -> (
      match extracted "Escape" with
      | Option.None ->
          Alcotest.(check pass)
            "callback returns None for non-matching key" () ()
      | Some _ -> Alcotest.fail "expected None from callback for Escape")
  | Option.None -> Alcotest.fail "expected Some from extract"

let test_keydown_prevent_keys () =
  let sub =
    Nopal_mvu.Sub.on_keydown_prevent "trap-keys" (fun _ -> Option.none)
  in
  Alcotest.(check (list string))
    "keys includes the key" [ "trap-keys" ] (Nopal_mvu.Sub.keys sub)

let test_keydown_prevent_map () =
  let f key =
    match key with
    | "Tab" -> Some (Got ("Tab", true), true)
    | _ -> Option.none
  in
  let sub = Nopal_mvu.Sub.on_keydown_prevent "trap" f in
  let mapped = Nopal_mvu.Sub.map (fun msg -> Wrapped msg) sub in
  match Nopal_mvu.Sub.extract_on_keydown_prevent mapped with
  | Some extracted -> (
      match extracted "Tab" with
      | Some (Wrapped (Got ("Tab", true)), true) ->
          Alcotest.(check pass) "map transforms msg in callback" () ()
      | Some _ -> Alcotest.fail "unexpected mapped result"
      | Option.None -> Alcotest.fail "expected Some from mapped callback")
  | Option.None -> Alcotest.fail "expected Some from extract after map"

let test_extract_on_keydown_prevents_batch () =
  let f1 _key = Option.none in
  let f2 _key = Option.none in
  let sub =
    Nopal_mvu.Sub.batch
      [
        Nopal_mvu.Sub.on_keydown_prevent "a" f1;
        Nopal_mvu.Sub.none;
        Nopal_mvu.Sub.on_keydown_prevent "b" f2;
      ]
  in
  let result = Nopal_mvu.Sub.extract_on_keydown_prevents sub in
  Alcotest.(check (list string))
    "extracts all keys from batch" [ "a"; "b" ] (List.map fst result)

let () =
  Alcotest.run "sub_keydown_prevent"
    [
      ( "Sub.on_keydown_prevent",
        [
          Alcotest.test_case "extract" `Quick test_keydown_prevent_extract;
          Alcotest.test_case "callback Some true" `Quick
            test_keydown_prevent_callback_some_true;
          Alcotest.test_case "callback None" `Quick
            test_keydown_prevent_callback_none;
          Alcotest.test_case "keys" `Quick test_keydown_prevent_keys;
          Alcotest.test_case "map" `Quick test_keydown_prevent_map;
          Alcotest.test_case "extract_on_keydown_prevents batch" `Quick
            test_extract_on_keydown_prevents_batch;
        ] );
    ]

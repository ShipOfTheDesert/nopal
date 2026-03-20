let all_platforms =
  Nopal_tauri.Os.
    [
      (Windows, "windows");
      (MacOS, "macos");
      (Linux, "linux");
      (IOS, "ios");
      (Android, "android");
    ]

let platform_testable =
  Alcotest.testable
    (fun fmt p -> Format.pp_print_string fmt (Nopal_tauri.Os.to_string p))
    ( = )

let test_to_string_round_trips () =
  let names =
    List.map (fun (p, _) -> Nopal_tauri.Os.to_string p) all_platforms
  in
  List.iter
    (fun name ->
      Alcotest.(check bool)
        (name ^ " is non-empty") true
        (String.length name > 0))
    names;
  let unique = List.sort_uniq String.compare names in
  Alcotest.(check int)
    "all names distinct" (List.length names) (List.length unique)

let test_platform_of_string_valid () =
  List.iter
    (fun (expected, api_string) ->
      let result = Nopal_tauri.Os.platform_of_string api_string in
      Alcotest.(check (option platform_testable))
        ("parse " ^ api_string) (Some expected) result)
    all_platforms

let test_platform_of_string_unknown () =
  let result = Nopal_tauri.Os.platform_of_string "haiku" in
  Alcotest.(check (option platform_testable)) "unknown returns None" None result

let () =
  Alcotest.run "nopal_tauri_os"
    [
      ( "os",
        [
          Alcotest.test_case "to_string round trips" `Quick
            test_to_string_round_trips;
          Alcotest.test_case "platform_of_string valid" `Quick
            test_platform_of_string_valid;
          Alcotest.test_case "platform_of_string unknown" `Quick
            test_platform_of_string_unknown;
        ] );
    ]

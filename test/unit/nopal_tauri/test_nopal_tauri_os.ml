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

(* [is_ios] is the synchronous mount-time carve-out: it reads the Tauri os-plugin
   global [__TAURI_OS_PLUGIN_INTERNALS__] directly (the same source as the async
   [platform] task). Drive that global to present each platform. Because the
   global is present only under a Tauri host, an absent global stands in for the
   plain-browser case. iOS is the one target that must carve the native
   safe-area source out; every other Tauri host keeps it (Android real insets,
   desktop harmless zero inset — NFR-1). *)
let set_os_platform value =
  Jv.set Jv.global "__TAURI_OS_PLUGIN_INTERNALS__"
    (Jv.obj [| ("platform", Jv.of_string value) |])

let clear_os_platform () =
  Jv.set Jv.global "__TAURI_OS_PLUGIN_INTERNALS__" Jv.undefined

let test_is_ios_probe () =
  set_os_platform "ios";
  Alcotest.(check bool)
    "ios Tauri global => true (carve out native source, use CSS env)" true
    (Nopal_tauri.Os.is_ios ());
  set_os_platform "android";
  Alcotest.(check bool)
    "android => false (native insets source kept)" false
    (Nopal_tauri.Os.is_ios ());
  set_os_platform "linux";
  Alcotest.(check bool)
    "desktop linux => false (zero-inset source kept, NFR-1)" false
    (Nopal_tauri.Os.is_ios ());
  clear_os_platform ();
  Alcotest.(check bool)
    "no Tauri global (plain browser) => false" false (Nopal_tauri.Os.is_ios ())

(* FFI hardening: [read_platform_string] guards on [typeof = "string"], so a
   malformed global (numeric or absent [platform] field) reads [None] rather than
   letting [Jv.to_string] coerce it — and [is_ios] safe-defaults to [false]
   instead of misreading. Drives the guard directly and through [is_ios]. *)
let test_read_platform_string_guards_non_string () =
  Jv.set Jv.global "__TAURI_OS_PLUGIN_INTERNALS__"
    (Jv.obj [| ("platform", Jv.of_int 42) |]);
  Alcotest.(check bool)
    "numeric platform field => read None" true
    (Option.is_none
       (Nopal_tauri.Os.read_platform_string
          (Jv.get Jv.global "__TAURI_OS_PLUGIN_INTERNALS__")));
  Alcotest.(check bool)
    "numeric platform field => is_ios false (safe default, no coercion)" false
    (Nopal_tauri.Os.is_ios ());
  Jv.set Jv.global "__TAURI_OS_PLUGIN_INTERNALS__" (Jv.obj [||]);
  Alcotest.(check bool)
    "absent platform field => read None" true
    (Option.is_none
       (Nopal_tauri.Os.read_platform_string
          (Jv.get Jv.global "__TAURI_OS_PLUGIN_INTERNALS__")));
  clear_os_platform ()

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
          Alcotest.test_case "is_ios probe" `Quick test_is_ios_probe;
          Alcotest.test_case "read_platform_string guards non-string" `Quick
            test_read_platform_string_guards_non_string;
        ] );
    ]

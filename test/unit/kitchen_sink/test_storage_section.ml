open Nopal_test.Test_renderer

(* A native-clean platform instantiating the kitchen sink functor: navigation is
   stubbed (the storage section exercises none of it) and storage is the
   in-memory backend so the structural tests stay browser-free. *)
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

let pp_selector fmt sel =
  match sel with
  | By_tag t -> Format.fprintf fmt "By_tag %S" t
  | By_text t -> Format.fprintf fmt "By_text %S" t
  | By_attr (k, v) -> Format.fprintf fmt "By_attr (%S, %S)" k v
  | First_child -> Format.fprintf fmt "First_child"
  | Nth_child n -> Format.fprintf fmt "Nth_child %d" n

let error_testable =
  Alcotest.testable
    (fun fmt e ->
      match e with
      | Not_found sel -> Format.fprintf fmt "Not_found (%a)" pp_selector sel
      | No_handler { tag; event } ->
          Format.fprintf fmt "No_handler { tag = %S; event = %S }" tag event)
    ( = )

let model0 () =
  let m, _ = init () in
  m

let result_text model =
  let t = tree (render (view_storage model)) in
  match find (By_attr ("data-testid", "storage-result")) t with
  | Some node -> text_content node
  | None -> Alcotest.fail "storage-result element missing"

let codec_result_text model =
  let t = tree (render (view_storage model)) in
  match find (By_attr ("data-testid", "codec-result")) t with
  | Some node -> text_content node
  | None -> Alcotest.fail "codec-result element missing"

(* The storage controls plus the typed-counter (With_codec) controls must render
   with the data-testids the E2E spec drives. A missing or misnamed control is a
   real break, not cosmetic. *)
let test_view_renders_controls () =
  let t = tree (render (view_storage (model0 ()))) in
  let present testid =
    Option.is_some (find (By_attr ("data-testid", testid)) t)
  in
  List.iter
    (fun testid ->
      Alcotest.(check bool) (testid ^ " present") true (present testid))
    [
      "storage-key-input";
      "storage-value-input";
      "storage-set-btn";
      "storage-get-btn";
      "storage-delete-btn";
      "storage-list-btn";
      "storage-clear-btn";
      "storage-reload-btn";
      "storage-result";
      "codec-count";
      "codec-increment-btn";
      "codec-save-btn";
      "codec-load-btn";
      "codec-corrupt-btn";
      "codec-result";
    ]

let click_dispatches testid expected () =
  let r = render (view_storage (model0 ())) in
  let outcome = click (By_attr ("data-testid", testid)) r in
  Alcotest.(check (result unit error_testable)) "click succeeds" (Ok ()) outcome;
  match messages r with
  | [ m ] ->
      Alcotest.(check bool)
        (testid ^ " dispatches expected message")
        true (m = expected)
  | _ -> Alcotest.fail "expected exactly one dispatched message"

(* Result messages drive the visible result text — this is pure display logic
   in [update] that the E2E only checks indirectly. *)
let apply msg = fst (update (model0 ()) msg)

let test_get_some_shows_value () =
  Alcotest.(check string)
    "shows retrieved value" "hello"
    (result_text (apply (StorageGetResult (Ok (Some "hello")))))

let test_get_none_shows_not_found () =
  Alcotest.(check string)
    "shows not found" "Not found"
    (result_text (apply (StorageGetResult (Ok None))))

let test_get_error_shows_error () =
  let model = apply (StorageGetResult (Error (Backend_error "boom"))) in
  Alcotest.(check bool)
    "shows error text" true
    (Test_util.string_contains (result_text model) ~sub:"boom")

(* The init-time restore re-read (REQ-F3 persistence proof) is otherwise only
   exercised by storage.spec.ts; cover its three result arms natively. *)
let test_restored_some_shows_value () =
  Alcotest.(check string)
    "restored value surfaces" "kept"
    (result_text (apply (StorageRestored (Ok (Some "kept")))))

let test_restored_none_is_noop () =
  Alcotest.(check string)
    "empty restore leaves idle text" "No operation yet"
    (result_text (apply (StorageRestored (Ok None))))

let test_restored_error_shows_error () =
  let model = apply (StorageRestored (Error (Backend_error "boom"))) in
  Alcotest.(check bool)
    "restore error surfaces" true
    (Test_util.string_contains (result_text model) ~sub:"boom")

let test_set_result_shows_stored () =
  Alcotest.(check string)
    "shows Stored" "Stored"
    (result_text (apply (StorageSetResult (Ok ()))))

let test_delete_result_shows_deleted () =
  Alcotest.(check string)
    "shows Deleted" "Deleted"
    (result_text (apply (StorageDeleteResult (Ok ()))))

let test_clear_result_shows_cleared () =
  Alcotest.(check string)
    "shows Cleared" "Cleared"
    (result_text (apply (StorageClearResult (Ok ()))))

let test_list_result_shows_keys () =
  let text = result_text (apply (StorageListResult (Ok [ "a:1"; "a:2" ]))) in
  Alcotest.(check bool)
    "lists first key" true
    (Test_util.string_contains text ~sub:"a:1");
  Alcotest.(check bool)
    "lists second key" true
    (Test_util.string_contains text ~sub:"a:2")

let test_codec_save_result_shows_saved () =
  Alcotest.(check string)
    "shows Saved" "Saved"
    (codec_result_text (apply (CodecSaveResult (Ok ()))))

let test_codec_load_some_shows_value () =
  Alcotest.(check string)
    "shows Loaded N" "Loaded 7"
    (codec_result_text (apply (CodecLoadResult (Ok (Some 7)))))

let test_codec_load_none_shows_not_found () =
  Alcotest.(check string)
    "shows Not found" "Not found"
    (codec_result_text (apply (CodecLoadResult (Ok None))))

let test_codec_decode_error_shows_decode () =
  let text =
    codec_result_text (apply (CodecLoadResult (Error (Codec.Decode "bad int"))))
  in
  Alcotest.(check bool)
    "shows decode error" true
    (Test_util.string_contains text ~sub:"Decode error");
  Alcotest.(check bool)
    "includes the decode message" true
    (Test_util.string_contains text ~sub:"bad int")

let () =
  Alcotest.run "kitchen_sink_storage_section"
    [
      ( "structure",
        [
          Alcotest.test_case "renders controls" `Quick
            test_view_renders_controls;
        ] );
      ( "dispatch",
        [
          Alcotest.test_case "set" `Quick
            (click_dispatches "storage-set-btn" StorageSet);
          Alcotest.test_case "get" `Quick
            (click_dispatches "storage-get-btn" StorageGet);
          Alcotest.test_case "delete" `Quick
            (click_dispatches "storage-delete-btn" StorageDelete);
          Alcotest.test_case "list" `Quick
            (click_dispatches "storage-list-btn" StorageList);
          Alcotest.test_case "clear" `Quick
            (click_dispatches "storage-clear-btn" StorageClear);
          Alcotest.test_case "reload" `Quick
            (click_dispatches "storage-reload-btn" StorageReload);
          Alcotest.test_case "codec increment" `Quick
            (click_dispatches "codec-increment-btn" CodecIncrement);
          Alcotest.test_case "codec save" `Quick
            (click_dispatches "codec-save-btn" CodecSave);
          Alcotest.test_case "codec load" `Quick
            (click_dispatches "codec-load-btn" CodecLoad);
          Alcotest.test_case "codec corrupt" `Quick
            (click_dispatches "codec-corrupt-btn" CodecCorrupt);
        ] );
      ( "result display",
        [
          Alcotest.test_case "get Some shows value" `Quick
            test_get_some_shows_value;
          Alcotest.test_case "get None shows not found" `Quick
            test_get_none_shows_not_found;
          Alcotest.test_case "get error shows error" `Quick
            test_get_error_shows_error;
          Alcotest.test_case "restored Some shows value" `Quick
            test_restored_some_shows_value;
          Alcotest.test_case "restored None is noop" `Quick
            test_restored_none_is_noop;
          Alcotest.test_case "restored error shows error" `Quick
            test_restored_error_shows_error;
          Alcotest.test_case "set shows Stored" `Quick
            test_set_result_shows_stored;
          Alcotest.test_case "delete shows Deleted" `Quick
            test_delete_result_shows_deleted;
          Alcotest.test_case "clear shows Cleared" `Quick
            test_clear_result_shows_cleared;
          Alcotest.test_case "list shows keys" `Quick
            test_list_result_shows_keys;
          Alcotest.test_case "codec save shows Saved" `Quick
            test_codec_save_result_shows_saved;
          Alcotest.test_case "codec load Some shows value" `Quick
            test_codec_load_some_shows_value;
          Alcotest.test_case "codec load None shows not found" `Quick
            test_codec_load_none_shows_not_found;
          Alcotest.test_case "codec decode error shows decode" `Quick
            test_codec_decode_error_shows_decode;
        ] );
    ]

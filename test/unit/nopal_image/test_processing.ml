open Nopal_image.Processing

(* One detail string is fed to every constructor, so a passing run proves the
   constructor itself discriminates the message rather than the payload leaking
   through an identity [message]. *)
let detail = "the store holds no entry under that handle"

(* Adding a sixth constructor makes this match non-exhaustive, and warning 8 is
   fatal here, so the build fails until [all] below is extended too. Without
   this, a new arm would ship with [message] covered by the library's own
   exhaustive [function] but covered by no test. *)
let _every_constructor_is_listed_below : error -> unit = function
  | Blob_not_found _
  | Decode_failed _
  | Canvas_unavailable _
  | Pixel_read_failed _
  | Encode_failed _ ->
      ()

let all =
  [
    ("blob not found", Blob_not_found detail, "Image blob not found: " ^ detail);
    ("decode failed", Decode_failed detail, "Image decode failed: " ^ detail);
    ( "canvas unavailable",
      Canvas_unavailable detail,
      "Image canvas unavailable: " ^ detail );
    ( "pixel read failed",
      Pixel_read_failed detail,
      "Image pixel read failed: " ^ detail );
    ("encode failed", Encode_failed detail, "Image encode failed: " ^ detail);
  ]

let test_message_covers_every_arm () =
  List.iter
    (fun (name, error, expected) ->
      Alcotest.(check string)
        (name ^ " names its stage and carries the detail verbatim")
        expected (message error))
    all;
  let messages = List.map (fun (_, error, _) -> message error) all in
  List.iter
    (fun rendered ->
      Alcotest.(check bool)
        "every arm renders something displayable" true
        (String.length rendered > 0))
    messages;
  (* Pairwise, not [List.sort_uniq] on a length check: a copy-pasted arm that
     forgot to change its prefix must name the pair it collides with. *)
  List.iter
    (fun (left_name, left, _) ->
      List.iter
        (fun (right_name, right, _) ->
          match String.equal left_name right_name with
          | true -> ()
          | false ->
              Alcotest.(check bool)
                (left_name ^ " reads differently from " ^ right_name)
                false
                (String.equal (message left) (message right)))
        all)
    all

(* Names the constructor without its detail, so a case can pin which stage a
   failure was attributed to without also pinning the sentence. Bare [function]
   so a sixth constructor is a compile error here too. *)
let stage_of_error = function
  | Blob_not_found _ -> "Blob_not_found"
  | Decode_failed _ -> "Decode_failed"
  | Canvas_unavailable _ -> "Canvas_unavailable"
  | Pixel_read_failed _ -> "Pixel_read_failed"
  | Encode_failed _ -> "Encode_failed"

let detail_of_error = function
  | Blob_not_found detail
  | Decode_failed detail
  | Canvas_unavailable detail
  | Pixel_read_failed detail
  | Encode_failed detail ->
      detail

let format_name = function
  | Nopal_image.Config.Jpeg -> "Jpeg"
  | Nopal_image.Config.Png -> "Png"
  | Nopal_image.Config.Webp -> "Webp"

(* Exact, not [Alcotest.float eps]: the seam must hand the backend the number it
   was given, and a tolerance would hide a rescale. *)
let exact_float = Alcotest.testable Format.pp_print_float Float.equal

let pp_result_info fmt info =
  Format.fprintf fmt
    "{ blob_id = %S; width = %d; height = %d; byte_size = %d; sharpness = %h }"
    info.blob_id info.width info.height info.byte_size info.sharpness

(* Field-wise with [Float.equal] on [sharpness]; structural [=] on a record
   holding a float is the comparison this codebase forbids. *)
let equal_result_info left right =
  String.equal left.blob_id right.blob_id
  && Int.equal left.width right.width
  && Int.equal left.height right.height
  && Int.equal left.byte_size right.byte_size
  && Float.equal left.sharpness right.sharpness

let result_info = Alcotest.testable pp_result_info equal_result_info

(* Every value differs from [Config.recommended], so a seam that dropped the
   caller's parameters and substituted the preset could not pass. The quality is
   exactly representable, so an accessor round trip is not the thing under
   test. *)
let sample_config () =
  match
    Nopal_image.Config.make ~max_edge:2048 ~metric_edge:512 ~quality:0.4375
      ~format:Nopal_image.Config.Png
  with
  | Ok config -> config
  | Error error ->
      Alcotest.failf "the fixture config was rejected: %s"
        (Nopal_image.message error)

let stub_info =
  {
    blob_id = "processed-9f2";
    width = 1280;
    height = 853;
    byte_size = 214_007;
    sharpness = 37.5;
  }

(* [record] observes what the seam handed the backend, [info] is what the
   backend answers. Both are required rather than defaulted so no case inherits
   an unstated value. *)
let capturing_backend ~record ~info =
  {
    process =
      (fun ~blob_id ~config ->
        record ~blob_id ~config;
        Nopal_mvu.Task.return (Ok info));
  }

(* Installs [backend] for the duration of [f] and restores the default
   afterwards, so a failing assertion cannot leak a stub into the next case. *)
let with_backend backend f =
  Fun.protect
    ~finally:(fun () -> register_backend default_backend)
    (fun () ->
      register_backend backend;
      f ())

(* Builds the command and interprets it, collecting every message it dispatched.
   [Cmd.execute] rather than [Cmd.interpret] because the two take the same path
   through a task node and this seam produces nothing else. A list rather than an
   [option] because a seam that resolved twice is invisible to an option that
   simply overwrites. *)
let outcomes_of ~blob_id ~config =
  let collected = ref [] in
  Nopal_mvu.Cmd.execute
    (fun outcome -> collected := outcome :: !collected)
    (process ~blob_id ~config Fun.id);
  List.rev !collected

let single_outcome ~context outcomes =
  match outcomes with
  | [ outcome ] -> outcome
  | [] ->
      Alcotest.failf "%s: the command dispatched nothing, expected one message"
        context
  | _ :: _ :: _ ->
      Alcotest.failf "%s: the command dispatched %d messages, expected one"
        context (List.length outcomes)

(* Runs against whatever the module initialised itself to, which is what "no
   backend registered" means at startup. Every other case restores
   [default_backend] under [Fun.protect], so ordering cannot make this one pass
   spuriously. A seam that left the task unresolved would report zero dispatched
   messages here rather than hanging. *)
let test_default_backend_resolves_error () =
  let outcome =
    single_outcome ~context:"no backend registered"
      (outcomes_of ~blob_id:"any-handle" ~config:(sample_config ()))
  in
  match outcome with
  | Ok info ->
      Alcotest.failf
        "expected an Error with no backend registered, got a result for handle \
         %s"
        info.blob_id
  | Error error ->
      Alcotest.(check string)
        "an absent backend is attributed to the canvas stage"
        "Canvas_unavailable" (stage_of_error error);
      let detail = detail_of_error error in
      Alcotest.(check bool)
        "the absent backend explains itself in a sentence, not a token" true
        (String.length detail > 0 && String.contains detail ' ')

let test_register_backend_swaps_and_restores () =
  let config = sample_config () in
  let installed =
    with_backend
      (capturing_backend
         ~record:(fun ~blob_id:_ ~config:_ -> ())
         ~info:stub_info)
      (fun () ->
        single_outcome ~context:"registered backend"
          (outcomes_of ~blob_id:"selected-1" ~config))
  in
  (match installed with
  | Ok info ->
      Alcotest.check result_info
        "the registered backend's answer reaches the caller unchanged" stub_info
        info
  | Error error ->
      Alcotest.failf "expected a result from the registered backend, got %s"
        (message error));
  let restored =
    single_outcome ~context:"restored default"
      (outcomes_of ~blob_id:"selected-1" ~config)
  in
  match restored with
  | Ok info ->
      Alcotest.failf "the stub outlived its scope: got a result for handle %s"
        info.blob_id
  | Error error ->
      Alcotest.(check string)
        "restoring the default un-swaps the stub" "Canvas_unavailable"
        (stage_of_error error)

let test_process_passes_blob_id_and_config () =
  let config = sample_config () in
  let calls = ref [] in
  let outcome =
    with_backend
      (capturing_backend
         ~record:(fun ~blob_id ~config -> calls := (blob_id, config) :: !calls)
         ~info:stub_info)
      (fun () ->
        single_outcome ~context:"argument capture"
          (outcomes_of ~blob_id:"selected-7c" ~config))
  in
  (match outcome with
  | Ok _ -> ()
  | Error error ->
      Alcotest.failf "the capturing backend should have answered, got %s"
        (message error));
  match List.rev !calls with
  | [] -> Alcotest.fail "the registered backend was never called"
  | _ :: _ :: _ ->
      Alcotest.failf "the registered backend was called %d times, expected once"
        (List.length !calls)
  | [ (seen_blob_id, seen_config) ] ->
      Alcotest.(check string)
        "the caller's handle reaches the backend unmodified" "selected-7c"
        seen_blob_id;
      Alcotest.(check int)
        "the caller's stored long edge reaches the backend" 2048
        (Nopal_image.Config.max_edge seen_config);
      Alcotest.(check int)
        "the caller's metric long edge reaches the backend" 512
        (Nopal_image.Config.metric_edge seen_config);
      Alcotest.check exact_float "the caller's quality reaches the backend"
        0.4375
        (Nopal_image.Config.quality seen_config);
      Alcotest.(check string)
        "the caller's format reaches the backend" "Png"
        (format_name (Nopal_image.Config.format seen_config))

let tests =
  [
    Alcotest.test_case "message covers every arm" `Quick
      test_message_covers_every_arm;
    Alcotest.test_case "default backend resolves an error" `Quick
      test_default_backend_resolves_error;
    Alcotest.test_case "register_backend swaps and restores" `Quick
      test_register_backend_swaps_and_restores;
    Alcotest.test_case "process passes blob_id and config" `Quick
      test_process_passes_blob_id_and_config;
  ]

let () = Alcotest.run "Nopal_image" [ ("Processing", tests) ]

(* A clipboard write as it travels through a command tree.

   [Cmd.t] is abstract, so every assertion reads the request back through the
   public extractor or through an interpreter, never by pattern-matching a
   constructor. The text a fixture copies is a distinctive fake key so that an
   assertion that it appears nowhere can only be satisfied by its absence, not
   by a near miss. *)

module Cmd = Nopal_mvu.Cmd
module Clipboard = Nopal_mvu.Clipboard

let fake_key = "nopal-test-key-7Q2"

type msg = Copied of string * (unit, Clipboard.error) result | Other of string
type wrapped = Wrapped of msg

let pp_error fmt (e : Clipboard.error) =
  match e with
  | Not_permitted -> Format.pp_print_string fmt "Not_permitted"
  | Unavailable -> Format.pp_print_string fmt "Unavailable"
  | Failed reason -> Format.fprintf fmt "Failed %S" reason

let pp_outcome fmt = function
  | Ok () -> Format.pp_print_string fmt "Ok ()"
  | Error e -> Format.fprintf fmt "Error (%a)" pp_error e

let pp_msg fmt = function
  | Copied (tag, r) -> Format.fprintf fmt "Copied (%S, %a)" tag pp_outcome r
  | Other s -> Format.fprintf fmt "Other %S" s

let msg = Alcotest.testable pp_msg ( = )

let wrapped =
  Alcotest.testable
    (fun fmt (Wrapped m) -> Format.fprintf fmt "Wrapped (%a)" pp_msg m)
    ( = )

(* Every outcome an interpreter can hand back, one per arm of the error type,
   so a callback that special-cased one arm shows up as a mismatch. *)
let every_outcome : (unit, Clipboard.error) result list =
  [
    Ok ();
    Error Not_permitted;
    Error Unavailable;
    Error (Failed "platform reason");
  ]

let copy tag text =
  Cmd.write_clipboard text ~on_result:(fun r -> Copied (tag, r))

(* ------------------------------------------------------------------ *)
(* Reading every request out of a tree                                  *)
(* ------------------------------------------------------------------ *)

let test_extract_clipboard_writes_in_batch_order () =
  let cmd =
    Cmd.batch
      [
        copy "first" "text one";
        Cmd.batch
          [
            Cmd.none;
            Cmd.focus "an unrelated field";
            Cmd.batch [ copy "second" "text two" ];
          ];
        copy "third" "text three";
      ]
  in
  let writes = Cmd.extract_clipboard_writes cmd in
  Alcotest.(check (list string))
    "every write's text, in issue order"
    [ "text one"; "text two"; "text three" ]
    (List.map fst writes);
  Alcotest.(check (list msg))
    "each write keeps its own callback"
    [
      Copied ("first", Ok ()); Copied ("second", Ok ()); Copied ("third", Ok ());
    ]
    (List.map (fun (_text, on_result) -> on_result (Ok ())) writes)

(* ------------------------------------------------------------------ *)
(* The telemetry label                                                  *)
(* ------------------------------------------------------------------ *)

(* The label is what telemetry records for the command, so it is the one place
   the copied text could leak into Nopal's own output. The equality is the
   affirmative arm: it proves [describe] answered for this very fixture, so the
   absence below is not the absence of an answer. *)
let test_describe_is_label_never_text () =
  let label = Cmd.describe (copy "key" fake_key) in
  Alcotest.(check string) "the label names the command" "write_clipboard" label;
  Alcotest.(check bool)
    "and never carries the copied text" false
    (Test_util.string_contains label ~sub:fake_key)

(* ------------------------------------------------------------------ *)
(* Mapping the message type                                             *)
(* ------------------------------------------------------------------ *)

let test_map_applies_to_outcome_message () =
  let mapped = Cmd.map (fun m -> Wrapped m) (copy "key" fake_key) in
  match Cmd.extract_clipboard_writes mapped with
  | [ (text, on_result) ] ->
      Alcotest.(check string) "the text survives the mapping" fake_key text;
      Alcotest.(check (list wrapped))
        "every outcome passes through the original callback, then the mapping"
        (List.map (fun r -> Wrapped (Copied ("key", r))) every_outcome)
        (List.map on_result every_outcome)
  | writes ->
      Alcotest.failf "expected exactly one write after map, got %d"
        (List.length writes)

(* ------------------------------------------------------------------ *)
(* The platform callback                                                *)
(* ------------------------------------------------------------------ *)

(* The handler is handed a resolver rather than a message, and the request is
   not answered until the handler calls it. So the dispatch list is read twice:
   once before resolving, where only the sibling's message may appear, and once
   after, where exactly one outcome message follows it. *)
let test_interpret_routes_write_to_handler_and_outcome_to_dispatch () =
  let texts = ref [] in
  let resolvers = ref [] in
  let dispatched = ref [] in
  let focused = ref [] in
  let scrolled = ref [] in
  let cmd =
    Cmd.batch
      [
        copy "key" fake_key;
        Cmd.perform (fun dispatch -> dispatch (Other "sibling"));
      ]
  in
  Cmd.interpret
    ~focus:(fun id -> focused := id :: !focused)
    ~scroll_by:(fun id _delta -> scrolled := id :: !scrolled)
    ~write_clipboard:(fun text resolve ->
      texts := !texts @ [ text ];
      resolvers := !resolvers @ [ resolve ])
    ~dispatch:(fun m -> dispatched := !dispatched @ [ m ])
    ~schedule_after:(fun _ms _msg -> ())
    cmd;
  Alcotest.(check (list string))
    "the handler received the text exactly once" [ fake_key ] !texts;
  Alcotest.(check (list msg))
    "nothing is dispatched for the write until the handler resolves"
    [ Other "sibling" ] !dispatched;
  (match !resolvers with
  | [ resolve ] -> resolve (Error Not_permitted)
  | rs -> Alcotest.failf "expected one resolver, got %d" (List.length rs));
  Alcotest.(check (list msg))
    "resolving dispatches exactly one outcome message, after the sibling"
    [ Other "sibling"; Copied ("key", Error Not_permitted) ]
    !dispatched;
  Alcotest.(check (list string)) "focus saw nothing" [] !focused;
  Alcotest.(check (list string)) "scroll_by saw nothing" [] !scrolled

(* ------------------------------------------------------------------ *)
(* The scheduling-free interpreter                                      *)
(* ------------------------------------------------------------------ *)

(* Absence arm: [execute] drops the write and keeps traversing. Affirmative arm
   on the same fixture: the write it dropped is really there to be read. *)
let test_execute_drops_write_clipboard () =
  let dispatched = ref [] in
  let cmd =
    Cmd.batch
      [
        copy "key" fake_key;
        Cmd.perform (fun dispatch -> dispatch (Other "sibling ran"));
      ]
  in
  Cmd.execute (fun m -> dispatched := !dispatched @ [ m ]) cmd;
  Alcotest.(check (list msg))
    "execute drops the write and keeps traversing" [ Other "sibling ran" ]
    !dispatched;
  Alcotest.(check (list string))
    "the same fixture does carry a write" [ fake_key ]
    (List.map fst (Cmd.extract_clipboard_writes cmd))

let () =
  Alcotest.run "cmd_clipboard"
    [
      ( "Cmd.write_clipboard",
        [
          Alcotest.test_case "extract in batch order" `Quick
            test_extract_clipboard_writes_in_batch_order;
          Alcotest.test_case "describe is label never text" `Quick
            test_describe_is_label_never_text;
          Alcotest.test_case "map applies to outcome message" `Quick
            test_map_applies_to_outcome_message;
          Alcotest.test_case "interpret routes write and outcome" `Quick
            test_interpret_routes_write_to_handler_and_outcome_to_dispatch;
          Alcotest.test_case "execute drops write_clipboard" `Quick
            test_execute_drops_write_clipboard;
        ] );
    ]

open Nopal_image.Preview

(* One detail string is fed to every constructor, so a passing run proves the
   constructor itself discriminates the message rather than the payload leaking
   through an identity [message]. *)
let detail = "the store holds no entry under that handle"

(* Adding a fourth constructor makes this match non-exhaustive, and warning 8 is
   fatal here, so the build fails until [all] below is extended too. Without
   this, a new arm would ship with [message] covered by the library's own
   exhaustive [function] but covered by no test. *)
let _every_constructor_is_listed_below : error -> unit = function
  | Blob_not_found _
  | Url_unavailable _
  | Backend_unregistered _ ->
      ()

let all =
  [
    ( "blob not found",
      Blob_not_found detail,
      "Preview blob not found: " ^ detail );
    ( "url unavailable",
      Url_unavailable detail,
      "Preview URL unavailable: " ^ detail );
    ( "backend unregistered",
      Backend_unregistered detail,
      "Preview backend unregistered: " ^ detail );
  ]

let test_error_messages_distinct () =
  List.iter
    (fun (name, error, expected) ->
      Alcotest.(check string)
        (name ^ " names its stage and carries the detail verbatim")
        expected (message error))
    all;
  List.iter
    (fun (name, error, _) ->
      Alcotest.(check bool)
        (name ^ " renders something displayable")
        true
        (String.length (message error) > 0))
    all;
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

(* Names the constructor without its detail, so a case can pin which arm a
   failure was attributed to without also pinning the sentence. Bare [function]
   so a fourth constructor is a compile error here too. *)
let arm_of_error = function
  | Blob_not_found _ -> "Blob_not_found"
  | Url_unavailable _ -> "Url_unavailable"
  | Backend_unregistered _ -> "Backend_unregistered"

let detail_of_error = function
  | Blob_not_found detail
  | Url_unavailable detail
  | Backend_unregistered detail ->
      detail

(* [record] observes what the seam handed the backend, [answer] is what the
   backend replies with, [released] collects what [revoke] was asked to release.
   All three are required rather than defaulted so no case inherits an unstated
   value. *)
let recording_backend ~record ~answer ~released =
  {
    url =
      (fun ~blob_id ->
        record blob_id;
        Nopal_mvu.Task.return answer);
    revoke = (fun ~url -> released url);
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
let outcomes_of ~blob_id =
  let collected = ref [] in
  Nopal_mvu.Cmd.execute
    (fun outcome -> collected := outcome :: !collected)
    (preview_url ~blob_id Fun.id);
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
let test_unregistered_backend_resolves_error () =
  let outcome =
    single_outcome ~context:"no backend registered"
      (outcomes_of ~blob_id:"any-handle")
  in
  match outcome with
  | Ok url ->
      Alcotest.failf
        "expected an Error with no backend registered, got the URL %s" url
  | Error error ->
      Alcotest.(check string)
        "an absent backend is attributed to its own arm" "Backend_unregistered"
        (arm_of_error error);
      let detail = detail_of_error error in
      Alcotest.(check bool)
        "the absent backend explains itself in a sentence, not a token" true
        (String.length detail > 0 && String.contains detail ' ')

let test_registered_backend_invoked () =
  let requested = ref [] in
  let minted = "blob:https://example.test/8a1f-4c2e" in
  let outcome =
    with_backend
      (recording_backend
         ~record:(fun blob_id -> requested := blob_id :: !requested)
         ~answer:(Ok minted)
         ~released:(fun _url -> ()))
      (fun () ->
        single_outcome ~context:"registered backend"
          (outcomes_of ~blob_id:"selected-7c"))
  in
  (match outcome with
  | Ok url ->
      Alcotest.(check string)
        "the registered backend's URL reaches the caller unchanged" minted url
  | Error error ->
      Alcotest.failf "expected a URL from the registered backend, got %s"
        (message error));
  (match List.rev !requested with
  | [] -> Alcotest.fail "the registered backend was never asked for a URL"
  | _ :: _ :: _ ->
      Alcotest.failf "the registered backend was called %d times, expected once"
        (List.length !requested)
  | [ seen ] ->
      Alcotest.(check string)
        "the caller's handle reaches the backend unmodified" "selected-7c" seen);
  (* The stub must not outlive its scope, or every later case in this file is
     asserting against it rather than against the default. *)
  let restored =
    single_outcome ~context:"restored default"
      (outcomes_of ~blob_id:"selected-7c")
  in
  match restored with
  | Ok url -> Alcotest.failf "the stub outlived its scope: got the URL %s" url
  | Error error ->
      Alcotest.(check string)
        "restoring the default un-swaps the stub" "Backend_unregistered"
        (arm_of_error error)

(* A backend that records everything it was asked to release. *)
let releasing_into ledger =
  recording_backend
    ~record:(fun _blob_id -> ())
    ~answer:(Error (Blob_not_found "unused by this case"))
    ~released:(fun url -> ledger := url :: !ledger)

let check_released ~context ~expected ledger =
  match List.rev !ledger with
  | [] ->
      Alcotest.failf "%s: the backend was never asked to release a URL" context
  | _ :: _ :: _ ->
      Alcotest.failf
        "%s: the backend was asked to release %d URLs, expected one" context
        (List.length !ledger)
  | [ seen ] ->
      Alcotest.(check string)
        (context ^ ": the caller's URL reaches the backend unmodified")
        expected seen

(* [revoke] is the seam's only zero-dispatch command, so "dispatched nothing" is
   an absence claim: on its own it passes against a [revoke] that does nothing at
   all. The ledger assertions on the same fixture are the affirmative arm that
   makes the absence mean something.

   The registration is swapped between building the command and executing it,
   because which of the two moments the backend is read at is a property of this
   seam and not an accident: both of its builders capture the registration
   eagerly, so a command carries the backend it was built against and a
   re-registration part way through a turn cannot redirect work already
   described. Reading the backend inside the thunk instead would pass every
   other case in this file. The second backend releases the command that was
   built against it, which is what keeps "the swapped-in backend was not
   reached" from being a claim about a stub that releases nothing at all. *)
let test_revoke_reaches_backend_without_dispatching () =
  let at_build = ref [] in
  let after_swap = ref [] in
  let dispatched = ref 0 in
  let url = "blob:https://example.test/3d90-11bb" in
  let swapped_url = "blob:https://example.test/6b12-90fa" in
  let command =
    with_backend (releasing_into at_build) (fun () -> revoke ~url)
  in
  with_backend (releasing_into after_swap) (fun () ->
      Nopal_mvu.Cmd.execute (fun (_ : unit) -> incr dispatched) command;
      Nopal_mvu.Cmd.execute
        (fun (_ : unit) -> incr dispatched)
        (revoke ~url:swapped_url));
  check_released ~context:"the backend registered when the command was built"
    ~expected:url at_build;
  check_released ~context:"the backend registered when the command ran"
    ~expected:swapped_url after_swap;
  Alcotest.(check int)
    "releasing a URL dispatches no message into the application" 0 !dispatched

let tests =
  [
    Alcotest.test_case "error messages are distinct" `Quick
      test_error_messages_distinct;
    Alcotest.test_case "unregistered backend resolves an error" `Quick
      test_unregistered_backend_resolves_error;
    Alcotest.test_case "registered backend is invoked" `Quick
      test_registered_backend_invoked;
    Alcotest.test_case "revoke reaches the backend without dispatching" `Quick
      test_revoke_reaches_backend_without_dispatching;
  ]

let () = Alcotest.run "Nopal_image" [ ("Preview", tests) ]

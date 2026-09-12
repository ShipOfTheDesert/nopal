open Nopal_image.Retention

(* The single field is named explicitly rather than overridden onto
   [default_backend], so no case inherits a value it did not state. *)
let releasing_into ledger =
  { release = (fun ~blob_id -> ledger := blob_id :: !ledger) }

(* Installs [backend] for the duration of [f] and restores the default
   afterwards, so a failing assertion cannot leak a stub into the next case. *)
let with_backend backend f =
  Fun.protect
    ~finally:(fun () -> register_backend default_backend)
    (fun () ->
      register_backend backend;
      f ())

(* Runs [command] and counts what it dispatched. A count rather than a discarded
   callback, because a dispatch nobody counted is a dispatch nobody would
   notice. *)
let dispatch_count command =
  let dispatched = ref 0 in
  Nopal_mvu.Cmd.execute (fun (_ : unit) -> incr dispatched) command;
  !dispatched

let check_released ~context ~expected ledger =
  match List.rev !ledger with
  | [] ->
      Alcotest.failf "%s: the backend was never asked to release a handle"
        context
  | _ :: _ :: _ ->
      Alcotest.failf
        "%s: the backend was asked to release %s, expected one handle" context
        (String.concat ", " (List.rev !ledger))
  | [ seen ] ->
      Alcotest.(check string)
        (context ^ ": the caller's handle reaches the backend unmodified")
        expected seen

(* Runs against whatever the module initialised itself to, which is what "no
   backend registered" means at startup. Every other case restores
   [default_backend] under [Fun.protect], so ordering cannot make this one pass
   spuriously. A default that raised, or that left the caller something to
   handle, would fail here rather than reaching the assertion.

   "Dispatched nothing" is a claim of absence, and on its own it also holds
   against a command whose body never ran. The two arms below it are the
   affirmative half: the first swaps in a ledger backend and drives the same
   builder through the same collector, showing the path this case walked is live;
   the second drives a hand-built dispatching command through that same
   collector, showing the counter can leave zero. Both are anchored to fixtures
   this case makes and unmakes itself. *)
let test_default_backend_release_is_inert () =
  Alcotest.(check int)
    "releasing with no backend registered dispatches no message" 0
    (dispatch_count (release ~blob_id:"never-issued-2b7c"));
  let live = ref [] in
  let live_dispatches =
    with_backend (releasing_into live) (fun () ->
        dispatch_count (release ~blob_id:"never-issued-2b7c"))
  in
  check_released ~context:"the same builder under a registered backend"
    ~expected:"never-issued-2b7c" live;
  Alcotest.(check int)
    "releasing through a registered backend dispatches no message either" 0
    live_dispatches;
  Alcotest.(check int)
    "the collector counts a dispatch when a command makes one" 1
    (dispatch_count (Nopal_mvu.Cmd.perform (fun dispatch -> dispatch ())))

let test_release_reaches_registered_backend () =
  let ledger = ref [] in
  let dispatches =
    with_backend (releasing_into ledger) (fun () ->
        dispatch_count (release ~blob_id:"receipt-4f2a"))
  in
  check_released ~context:"the registered backend" ~expected:"receipt-4f2a"
    ledger;
  Alcotest.(check int)
    "releasing a stored image dispatches no message" 0 dispatches;
  (* The stub must not outlive its scope, or every later case in this file is
     asserting against it rather than against the default. A second release once
     the default is restored would put a second entry in the ledger if it did. *)
  let restored = dispatch_count (release ~blob_id:"receipt-4f2a") in
  Alcotest.(check int) "the restored default dispatches nothing" 0 restored;
  check_released ~context:"restoring the default un-swaps the stub"
    ~expected:"receipt-4f2a" ledger

(* Which moment the backend is read at is a property of this seam and not an
   accident: the builder captures the registration eagerly, so a command carries
   the backend it was built against and a re-registration part way through a turn
   cannot redirect work already described. A [release] that read the registration
   inside its thunk would pass both cases above and fail only here.

   The second backend releases a command built against it, which is what keeps
   "the swapped-in backend was not reached" from being a claim about a stub that
   releases nothing at all. *)
let test_release_reads_backend_at_build_time () =
  let at_build = ref [] in
  let after_swap = ref [] in
  let built_under_first = "built-under-first-9d31" in
  let built_under_second = "built-under-second-01ae" in
  let command =
    with_backend (releasing_into at_build) (fun () ->
        release ~blob_id:built_under_first)
  in
  let dispatches =
    with_backend (releasing_into after_swap) (fun () ->
        let carried = dispatch_count command in
        let fresh = dispatch_count (release ~blob_id:built_under_second) in
        carried + fresh)
  in
  check_released ~context:"the backend registered when the command was built"
    ~expected:built_under_first at_build;
  check_released ~context:"the backend registered when the command ran"
    ~expected:built_under_second after_swap;
  Alcotest.(check int) "neither release dispatched a message" 0 dispatches

(* Deferral is the reason this seam returns a command instead of doing the work:
   [update] describes an effect and the interpreter performs it, so nothing is
   released until the command is executed (CONTRIBUTING.md section V). Every
   other case here reaches the backend through [dispatch_count], which executes,
   so all three are equally satisfied by a [release] that released eagerly and
   returned [Cmd.none] - a side effect performed inside [update], which is the
   thing the seam exists to avoid. Building and executing are separated here,
   against one ledger, so the eager form fails the first assertion.

   That first assertion is a claim of absence, and the two below it are its
   affirmative half on the same ledger: the ledger was empty because the effect
   had not been asked for yet, not because this backend records nothing. *)
let test_release_defers_its_effect_to_interpretation () =
  let ledger = ref [] in
  let command =
    with_backend (releasing_into ledger) (fun () ->
        release ~blob_id:"deferred-1a4c")
  in
  Alcotest.(check (list string))
    "building the command releases nothing" [] !ledger;
  Alcotest.(check int)
    "executing the command dispatches no message" 0 (dispatch_count command);
  check_released ~context:"executing the command is what releases"
    ~expected:"deferred-1a4c" ledger

let tests =
  [
    Alcotest.test_case
      "the default backend releases nothing and reports nothing" `Quick
      test_default_backend_release_is_inert;
    Alcotest.test_case "release reaches the registered backend" `Quick
      test_release_reaches_registered_backend;
    Alcotest.test_case "release reads the backend when the command is built"
      `Quick test_release_reads_backend_at_build_time;
    Alcotest.test_case "release defers its effect to interpretation" `Quick
      test_release_defers_its_effect_to_interpretation;
  ]

let () = Alcotest.run "Nopal_image" [ ("Retention", tests) ]

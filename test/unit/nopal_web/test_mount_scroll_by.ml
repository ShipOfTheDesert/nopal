(* Where the relative-scroll drain runs inside a frame.

   The cases in [test_nopal_web.ml] drive [Nopal_web.drain_scroll_by] by hand,
   so they pin what the drain computes but not when the mount runs it. That
   ordering is a property of [drive]'s rAF body, and only a test that goes
   through [mount] can see it.

   The first case pins the drain against the DOM patch. Its update shrinks the
   pane's content and asks for a movement of one and three quarter viewports in
   the same breath. Against a 100-tall viewport that is 175. Before the patch
   the content is 300 tall, so the reachable range ends at 200 and 175 is
   reachable; after it the content is 250, the range ends at 150, and the same
   request clamps there instead. A drain moved above the patch therefore leaves
   the container at 175 rather than 150.

   The second case pins the drain against the focus flush that follows it. A
   batch of a relative scroll and a focus, drained the other way round, leaves
   the container somewhere else — so "relative scroll second, focus last" is a
   property of the frame here, not of the order a test happens to call two
   drains in.

   The third case pins the frame loop against a drain that throws. The
   container it names refuses to report its own scroll offset, so the drain
   raises where it measures; the loop must already have asked for the next
   frame by then, or one bad measurement freezes the application for good with
   nothing left to restart it.

   The fourth and fifth pin what the frame does with that failure rather than
   what it survives: it is reported to the mount's own fault sink instead of
   escaping as an uncaught browser error, the requests behind the failing one
   are still applied in the frame that measured them, and the focus stage that
   follows still runs.

   The sixth pins two mounts in one document against each other. The queues are
   mount-local, so a frame drains its own mount's requests and no other's, and
   a request the last dispatch before a teardown enqueued goes with the mount.
   Note what is NOT mount-local: the container ids resolve through the document,
   so two mounts sharing an id would reach one element.

   The seventh pins a request that arrives between two frames rather than during
   a dispatch — the shape a settled timer or task has. The queue carries it the
   same way, and the next frame applies it.

   The eighth pins the third guard, the one over the render pass itself. Its
   pane loses a row on each press and the node the patch must remove it from
   refuses, so the DOM patch throws where the drains cannot: the failure is
   reported naming its own stage, the loop is already re-armed, and the row the
   patch could not remove is still in the live tree the frames after reconcile
   against — which is the cost of reporting rather than propagating, and is what
   [drive]'s rAF comment names.

   The ninth pins the mount that was given no [~on_error] at all. It cannot
   assert on the backend's stderr default from inside this harness; it asserts
   the half that is observable, which is that a fault reported through that
   default is still survived — see the case's own comment for what it leaves
   unpinned.

   Each case mounts an app with an id namespace of its own, because the shim's
   element registry is never pruned: a container an earlier case left behind
   would answer to a shared id and a later one would measure a node nothing
   is driving. That is what the functor below is for.

   Runs under dom_shim + mount_shim: the mount shim captures the rAF callback
   instead of firing it, so a frame is run explicitly and the loop does not
   reschedule itself forever under Node. *)

let visible_height = 100.
let row_height = 50.
let initial_rows = 6
let shrunk_rows = 5

module type IDS = sig
  val prefix : string
end

(* One pane, one button per behaviour under test. [Shrink_and_scroll] is the
   pair that makes a pre-patch and a post-patch measurement disagree;
   [Scroll_and_focus] is the batch that makes the two drains disagree. *)
module Make_pane (I : IDS) = struct
  let container_id = I.prefix ^ "-pane"
  let shrink_trigger_id = I.prefix ^ "-shrink"
  let batch_trigger_id = I.prefix ^ "-batch"
  let scroll_trigger_id = I.prefix ^ "-scroll"
  let twice_trigger_id = I.prefix ^ "-twice"
  let deferred_trigger_id = I.prefix ^ "-deferred"
  let row_id i = I.prefix ^ "-row-" ^ string_of_int i

  type model = { rows : int }

  type msg =
    | Shrink_and_scroll
    | Scroll_and_focus
    | Scroll_only
    | Scroll_twice
    | Deferred_scroll

  let init () = ({ rows = initial_rows }, Nopal_mvu.Cmd.none)

  let update model msg =
    match msg with
    | Shrink_and_scroll ->
        ( { rows = shrunk_rows },
          Nopal_mvu.Cmd.scroll_by container_id
            (Nopal_element.Scroll_delta.viewports 1.75) )
    | Scroll_and_focus ->
        ( model,
          Nopal_mvu.Cmd.batch
            [
              Nopal_mvu.Cmd.scroll_by container_id
                (Nopal_element.Scroll_delta.viewports (-0.5));
              Nopal_mvu.Cmd.focus (row_id (initial_rows - 1));
            ] )
    | Scroll_only ->
        ( model,
          Nopal_mvu.Cmd.scroll_by container_id
            (Nopal_element.Scroll_delta.viewports 1.0) )
    | Scroll_twice ->
        ( model,
          Nopal_mvu.Cmd.batch
            [
              Nopal_mvu.Cmd.scroll_by container_id
                (Nopal_element.Scroll_delta.viewports 1.0);
              Nopal_mvu.Cmd.scroll_by container_id
                (Nopal_element.Scroll_delta.viewports 0.25);
            ] )
    (* Not a dispatch: the runtime hands this to the platform scheduler, whose
       callback dispatches [Scroll_only] whenever the timer settles — which is
       between two frames, not inside one. *)
    | Deferred_scroll -> (model, Nopal_mvu.Cmd.after 0 Scroll_only)

  let row i =
    Nopal_element.Element.Box
      {
        style = Nopal_style.Style.default;
        interaction = Nopal_style.Interaction.default;
        attrs = [ ("id", row_id i) ];
        children = [];
        focusable = false;
        on_focus = None;
        on_blur = None;
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }

  let trigger id msg label =
    Nopal_element.Element.Button
      {
        style = Nopal_style.Style.default;
        interaction = Nopal_style.Interaction.default;
        attrs = [ ("id", id) ];
        on_click = Some msg;
        on_dblclick = None;
        child =
          Nopal_element.Element.Text { content = label; text_style = None };
      }

  let view _vp model =
    Nopal_element.Element.Column
      {
        style = Nopal_style.Style.default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children =
          [
            trigger shrink_trigger_id Shrink_and_scroll "shrink";
            trigger batch_trigger_id Scroll_and_focus "batch";
            trigger scroll_trigger_id Scroll_only "scroll";
            trigger twice_trigger_id Scroll_twice "twice";
            trigger deferred_trigger_id Deferred_scroll "deferred";
            Nopal_element.Element.Scroll
              {
                style = Nopal_style.Style.default;
                attrs = [ ("id", container_id) ];
                reveal = None;
                child =
                  Nopal_element.Element.Column
                    {
                      style = Nopal_style.Style.default;
                      interaction = Nopal_style.Interaction.default;
                      attrs = [];
                      children = List.init model.rows row;
                    };
              };
          ];
      }

  let subscriptions _model = Nopal_mvu.Sub.none

  let as_module :
      (module Nopal_mvu.App.S with type model = model and type msg = msg) =
    (module struct
      type nonrec model = model
      type nonrec msg = msg

      let init = init
      let update = update
      let view = view
      let subscriptions = subscriptions
    end)
end

module Patch_pane = Make_pane (struct
  let prefix = "mount-patch"
end)

module Order_pane = Make_pane (struct
  let prefix = "mount-order"
end)

module Throwing_pane = Make_pane (struct
  let prefix = "mount-throwing"
end)

module Reporting_pane = Make_pane (struct
  let prefix = "mount-reporting"
end)

module After_throw_pane = Make_pane (struct
  let prefix = "mount-after-throw"
end)

module Deferred_pane = Make_pane (struct
  let prefix = "mount-deferred"
end)

module Default_sink_pane = Make_pane (struct
  let prefix = "mount-default-sink"
end)

(* A pane whose only behaviour is losing a row, so one frame's DOM patch is a
   single [removeChild] on a node a test can substitute for. It is written out
   rather than taken from [Make_pane] because the stage under test is the render
   pass, which runs before either drain and is guarded on its own: the pane needs
   no scroll container, and it needs a trigger that can be pressed twice to two
   different row counts, which [Shrink_and_scroll]'s fixed count cannot do. *)
module Reconcile_pane = struct
  let prefix = "mount-reconcile"
  let rows_id = prefix ^ "-rows"
  let drop_trigger_id = prefix ^ "-drop"
  let row_id i = prefix ^ "-row-" ^ string_of_int i

  type model = { rows : int }
  type msg = Drop_a_row

  let init () = ({ rows = initial_rows }, Nopal_mvu.Cmd.none)

  let update model msg =
    match msg with
    | Drop_a_row -> ({ rows = model.rows - 1 }, Nopal_mvu.Cmd.none)

  let row i =
    Nopal_element.Element.Box
      {
        style = Nopal_style.Style.default;
        interaction = Nopal_style.Interaction.default;
        attrs = [ ("id", row_id i) ];
        children = [];
        focusable = false;
        on_focus = None;
        on_blur = None;
        on_pointer_move = None;
        on_pointer_leave = None;
        on_pointer_down = None;
        on_pointer_up = None;
        on_wheel = None;
      }

  let view _vp model =
    Nopal_element.Element.Column
      {
        style = Nopal_style.Style.default;
        interaction = Nopal_style.Interaction.default;
        attrs = [];
        children =
          [
            Nopal_element.Element.Button
              {
                style = Nopal_style.Style.default;
                interaction = Nopal_style.Interaction.default;
                attrs = [ ("id", drop_trigger_id) ];
                on_click = Some Drop_a_row;
                on_dblclick = None;
                child =
                  Nopal_element.Element.Text
                    { content = "drop"; text_style = None };
              };
            Nopal_element.Element.Column
              {
                style = Nopal_style.Style.default;
                interaction = Nopal_style.Interaction.default;
                attrs = [ ("id", rows_id) ];
                children = List.init model.rows row;
              };
          ];
      }

  let subscriptions _model = Nopal_mvu.Sub.none

  let as_module :
      (module Nopal_mvu.App.S with type model = model and type msg = msg) =
    (module struct
      type nonrec model = model
      type nonrec msg = msg

      let init = init
      let update = update
      let view = view
      let subscriptions = subscriptions
    end)
end

(* Two panes that exist at the same time, in two mounts, in one document. *)
module Sibling_a = Make_pane (struct
  let prefix = "mount-sibling-a"
end)

module Sibling_b = Make_pane (struct
  let prefix = "mount-sibling-b"
end)

let fresh_parent () = Brr.El.v (Jstr.v "div") []
let document () = Jv.get Jv.global "document"
let by_id id = Jv.call (document ()) "getElementById" [| Jv.of_string id |]

let child_nodes jv =
  let nodes = Jv.get jv "childNodes" in
  let count = Jv.Int.get nodes "length" in
  List.init count (fun i -> Jv.get nodes (string_of_int i))

let scroll_top jv = Jv.Float.get jv "scrollTop"
let set_scroll_top jv v = Jv.Float.set jv "scrollTop" v
let scroll_writes jv = Jv.Int.get jv "_scrollWrites"
let scroll_height jv = Jv.Float.get jv "scrollHeight"
let reset_scroll_writes jv = Jv.Int.set jv "_scrollWrites" 0

(* Run exactly one rAF frame: the mount shim stored the callback rather than
   firing it. *)
let run_frame () =
  let cb = Jv.get Jv.global "__nopal_raf_cb" in
  if not (Jv.is_undefined cb) then ignore (Jv.apply cb [| Jv.of_float 0. |])

let click id =
  let ev = Jv.new' (Jv.get Jv.global "Event") [| Jv.of_string "click" |] in
  ignore (Jv.call (by_id id) "dispatchEvent" [| ev |])

(* A container that refuses to report where it sits, which is where the
   relative-scroll drain reads first. The shim declares [scrollTop] configurable
   precisely so a test can substitute for it; the returned function puts the
   original accessor back, so the container is measurable again on the frame
   after. *)
exception Measurement_refused

let object_ () = Jv.get Jv.global "Object"

let define_scroll_top el descriptor =
  ignore
    (Jv.call (object_ ()) "defineProperty"
       [| el; Jv.of_string "scrollTop"; descriptor |])

let refuse_measurement el =
  let original =
    Jv.call (object_ ()) "getOwnPropertyDescriptor"
      [| el; Jv.of_string "scrollTop" |]
  in
  define_scroll_top el
    (Jv.obj
       [|
         ("get", Jv.callback ~arity:1 (fun _ -> raise Measurement_refused));
         ("configurable", Jv.true');
       |]);
  fun () -> define_scroll_top el original

(* The same refusal, but spent on the first read only: the substitute accessor
   puts the original back before it raises, so the request that follows the
   failing one measures a container that answers again. One container can then
   stand for both "the request that threw" and "the request behind it", which
   is what makes the queue's behaviour after a throw observable at all. *)
let refuse_first_measurement el =
  let original =
    Jv.call (object_ ()) "getOwnPropertyDescriptor"
      [| el; Jv.of_string "scrollTop" |]
  in
  define_scroll_top el
    (Jv.obj
       [|
         ( "get",
           Jv.callback ~arity:1 (fun _ ->
               define_scroll_top el original;
               raise Measurement_refused) );
         ("configurable", Jv.true');
       |])

(* A node that refuses to give up a child, which is what a DOM patch does to
   shrink a list. Unlike the refusals above this substitutes a plain method
   rather than an accessor — the shim gives every node its own [removeChild] —
   and the returned function puts the original back, so the frame after can
   patch. *)
exception Patch_refused

let refuse_child_removal node =
  let original = Jv.get node "removeChild" in
  Jv.set node "removeChild"
    (Jv.callback ~arity:1 (fun _ -> raise Patch_refused));
  fun () -> Jv.set node "removeChild" original

(* The id of whatever the document currently considers focused, or [""] when
   nothing is. The focus drain's own effect, read without going through a scroll
   offset another stage also writes. *)
let active_element_id () =
  let active = Jv.get (document ()) "activeElement" in
  if Jv.is_none active then ""
  else Jv.to_string (Jv.call active "getAttribute" [| Jv.of_string "id" |])

let contains haystack needle =
  let n = String.length needle and h = String.length haystack in
  let rec at i =
    i + n <= h && (String.sub haystack i n = needle || at (i + 1))
  in
  n = 0 || at 0

(* Every frame callback the loop asks for, rather than only the last one. The
   shim keeps a single [__nopal_raf_cb], so with two mounts live the second one
   registered would be the only one a frame ever ran and the first mount's queue
   would look drained by nobody. This collector keeps them all; [run_pending]
   snapshots the collection before running it, so the callbacks re-arming
   themselves cannot loop forever. *)
let collect_raf () =
  let original = Jv.get Jv.global "requestAnimationFrame" in
  (* mutable: the frames asked for since the last [run_pending], newest first *)
  let asked = ref [] in
  Jv.set Jv.global "requestAnimationFrame"
    (Jv.callback ~arity:1 (fun cb ->
         asked := cb :: !asked;
         Jv.of_int 0));
  let run_pending () =
    let due = List.rev !asked in
    asked := [];
    List.iter (fun cb -> ignore (Jv.apply cb [| Jv.of_float 0. |])) due
  in
  (run_pending, fun () -> Jv.set Jv.global "requestAnimationFrame" original)

(* [Cmd.after] reaches the platform through [window.setTimeout]. Capturing it
   lets a test settle the timer itself, at a moment of its choosing between two
   frames, instead of handing the callback to Node's event loop where a
   synchronous test can never see it run. *)
let capture_timeouts () =
  let original = Jv.get Jv.global "setTimeout" in
  (* mutable: the timer callbacks scheduled but not yet settled, newest first *)
  let scheduled = ref [] in
  Jv.set Jv.global "setTimeout"
    (Jv.callback ~arity:2 (fun cb _ms ->
         scheduled := cb :: !scheduled;
         Jv.of_int 0));
  let settle () =
    let due = List.rev !scheduled in
    scheduled := [];
    List.iter (fun cb -> ignore (Jv.apply cb [||])) due
  in
  (settle, fun () -> Jv.set Jv.global "setTimeout" original)

(* How many frames the loop has asked for. The shim keeps one captured callback
   and hands back the same one whatever happens, so a test cannot tell an armed
   loop from a dead one by looking at it; counting the requests can. The wrapper
   delegates to the shim, so capture behaves exactly as the other cases expect,
   and the returned function uninstalls it. *)
let raf_arms () = Jv.Int.get Jv.global "__nopal_raf_arms"

let count_raf_arms () =
  let shim_raf = Jv.get Jv.global "requestAnimationFrame" in
  Jv.Int.set Jv.global "__nopal_raf_arms" 0;
  Jv.set Jv.global "requestAnimationFrame"
    (Jv.callback ~arity:1 (fun cb ->
         Jv.Int.set Jv.global "__nopal_raf_arms" (raf_arms () + 1);
         Jv.apply shim_raf [| cb |]));
  fun () -> Jv.set Jv.global "requestAnimationFrame" shim_raf

(* Give the container a viewport and stack its rows inside it, after the mount's
   initial render and before anything asks for a movement — the order a page
   produces. *)
let lay_out container =
  Jv.Float.set container "_clientHeight" visible_height;
  match child_nodes container with
  | [] -> Alcotest.fail "the mounted pane rendered no column to lay out"
  | column :: _ ->
      List.iteri
        (fun i row ->
          Jv.Float.set row "_layoutTop" (float_of_int i *. row_height);
          Jv.Float.set row "_layoutHeight" row_height)
        (child_nodes column)

let rows_in container =
  match child_nodes container with
  | [] -> 0
  | column :: _ -> List.length (child_nodes column)

let test_drain_measures_the_patched_container () =
  let target = fresh_parent () in
  let mounted : Nopal_web.mounted =
    Nopal_web.mount Patch_pane.as_module target
  in
  let container = by_id Patch_pane.container_id in
  Alcotest.(check bool)
    "the mount rendered a container the request can name" true
    (not (Jv.is_none container));
  lay_out container;
  Alcotest.(check int)
    "the pane starts at its full row count" initial_rows (rows_in container);
  Alcotest.(check (float 0.001))
    "whose content is taller than the viewport" 300. (scroll_height container);
  reset_scroll_writes container;
  click Patch_pane.shrink_trigger_id;
  (* The runtime interprets the command during dispatch. Nothing may have moved
     yet: the queue is what carries the request across to the frame. *)
  Alcotest.(check int)
    "dispatch alone writes nothing" 0 (scroll_writes container);
  run_frame ();
  Alcotest.(check int)
    "the frame patched the pane down to its shrunk row count" shrunk_rows
    (rows_in container);
  Alcotest.(check (float 0.001))
    "so the content the drain measures is the shorter one" 250.
    (scroll_height container);
  Alcotest.(check int) "and the drain wrote once" 1 (scroll_writes container);
  (* 1.75 viewports is 175, past the 150 the patched content leaves reachable.
     Measured against the taller content the previous frame held it would have
     been reachable, and the container would sit at 175 instead. *)
  Alcotest.(check (float 0.001))
    "landing at the end of the range the patched content leaves" 150.
    (scroll_top container);
  mounted.unmount ()

let test_focus_drains_after_the_relative_scroll () =
  let target = fresh_parent () in
  let mounted : Nopal_web.mounted =
    Nopal_web.mount Order_pane.as_module target
  in
  let container = by_id Order_pane.container_id in
  lay_out container;
  (* Start part-way down, the way a reader who scrolled would leave it, so both
     stages have somewhere to move from and each writes whichever order they
     run in. *)
  set_scroll_top container 100.;
  reset_scroll_writes container;
  click Order_pane.batch_trigger_id;
  run_frame ();
  Alcotest.(check int) "both stages wrote" 2 (scroll_writes container);
  (* Half a viewport back from 100 is 50; focusing the last row then brings it
     into view, which ends at 200. Drained the other way round the focus would
     land first and the relative scroll would take it back to 150, so the number
     below is the order and not the arithmetic. *)
  Alcotest.(check (float 0.001))
    "the focus lands after the relative scroll, not before it" 200.
    (scroll_top container);
  mounted.unmount ()

let test_a_throwing_drain_leaves_the_loop_running () =
  let restore_raf = count_raf_arms () in
  let target = fresh_parent () in
  let mounted : Nopal_web.mounted =
    Nopal_web.mount Throwing_pane.as_module target
  in
  let container = by_id Throwing_pane.container_id in
  lay_out container;
  click Throwing_pane.shrink_trigger_id;
  let armed_before = raf_arms () in
  let measurable_again = refuse_measurement container in
  run_frame ();
  measurable_again ();
  Alcotest.(check int)
    "the frame whose drain threw still asked for its successor"
    (armed_before + 1) (raf_arms ());
  (* And that successor does the work the frame that threw could not. *)
  reset_scroll_writes container;
  click Throwing_pane.shrink_trigger_id;
  run_frame ();
  Alcotest.(check int)
    "the frame after the one that threw applied its request" 1
    (scroll_writes container);
  Alcotest.(check (float 0.001))
    "landing at the end of the range the patched content leaves" 150.
    (scroll_top container);
  mounted.unmount ();
  restore_raf ()

(* A request that throws is reported, and the queue behind it still drains.
   Both halves are the same frame: the first of two requests refuses to be
   measured, and the second — which the failing one would otherwise carry into
   the next frame, to be sized against a layout one patch newer — is applied
   here, where it belongs. *)
let test_a_throwing_request_is_reported_and_the_rest_drain () =
  (* mutable: every description this mount reported, newest first *)
  let reported = ref [] in
  let target = fresh_parent () in
  let mounted : Nopal_web.mounted =
    Nopal_web.mount
      ~on_error:(fun description -> reported := description :: !reported)
      Reporting_pane.as_module target
  in
  let container = by_id Reporting_pane.container_id in
  lay_out container;
  reset_scroll_writes container;
  click Reporting_pane.twice_trigger_id;
  refuse_first_measurement container;
  run_frame ();
  Alcotest.(check int)
    "the request that could not be measured was reported" 1
    (List.length !reported);
  Alcotest.(check bool)
    "and the report names what went wrong" true
    (List.exists (fun d -> contains d "Measurement_refused") !reported);
  (* The stage and the container, not just the exception: with several requests
     queued in one frame, a description that named neither would leave a
     consumer unable to tell which container's measurement failed. *)
  Alcotest.(check bool)
    "naming the stage that failed" true
    (List.exists (fun d -> contains d "scroll drain") !reported);
  Alcotest.(check bool)
    "and the container the failing request named" true
    (List.exists (fun d -> contains d Reporting_pane.container_id) !reported);
  Alcotest.(check int)
    "the request behind it still wrote, and the failing one never did" 1
    (scroll_writes container);
  Alcotest.(check (float 0.001))
    "landing a quarter of a viewport on from where it started" 25.
    (scroll_top container);
  (* Nothing was carried over: a stranded request would size itself against
     this frame's layout and move the container again. *)
  run_frame ();
  Alcotest.(check int)
    "the frame after applies nothing further" 1 (scroll_writes container);
  Alcotest.(check (float 0.001))
    "so the container stays where the drain left it" 25. (scroll_top container);
  (* Affirmative arm: the same pane, measurable again, still moves — so the
     two assertions above are the queue being empty, not the pane being inert. *)
  click Reporting_pane.twice_trigger_id;
  run_frame ();
  Alcotest.(check int)
    "both requests of a measurable frame wrote" 3 (scroll_writes container);
  Alcotest.(check (float 0.001))
    "a whole viewport and a quarter further on" 150. (scroll_top container);
  mounted.unmount ()

(* The two drains are independent. A batch of a relative scroll and a focus,
   whose scroll stage throws, still focuses — the frame reports the failure and
   carries on rather than dropping the rest of its work. *)
let test_the_focus_drain_survives_a_throwing_scroll_drain () =
  (* mutable: every description this mount reported, newest first *)
  let reported = ref [] in
  let target = fresh_parent () in
  let mounted : Nopal_web.mounted =
    Nopal_web.mount
      ~on_error:(fun description -> reported := description :: !reported)
      After_throw_pane.as_module target
  in
  let container = by_id After_throw_pane.container_id in
  lay_out container;
  set_scroll_top container 100.;
  reset_scroll_writes container;
  click After_throw_pane.batch_trigger_id;
  refuse_first_measurement container;
  run_frame ();
  Alcotest.(check int)
    "the scroll stage's failure was reported" 1 (List.length !reported);
  Alcotest.(check bool)
    "naming the stage and the container that failed" true
    (List.exists
       (fun d ->
         contains d "scroll drain" && contains d After_throw_pane.container_id)
       !reported);
  Alcotest.(check string)
    "and the focus stage, which runs after it, still ran"
    (After_throw_pane.row_id (initial_rows - 1))
    (active_element_id ());
  Alcotest.(check int)
    "only the focus wrote — the stage that threw never reached its write" 1
    (scroll_writes container);
  Alcotest.(check (float 0.001))
    "leaving the container where bringing the last row into view puts it" 200.
    (scroll_top container);
  (* Affirmative arm: the same batch, measurable, writes twice — so the single
     write above is the scroll stage having thrown, not the batch having been
     dropped before either stage. *)
  click After_throw_pane.batch_trigger_id;
  run_frame ();
  Alcotest.(check int)
    "a measurable frame runs both stages" 3 (scroll_writes container);
  mounted.unmount ()

(* Two mounts, one document. Each frame drains its own mount's requests and no
   other's, and a request the last dispatch before a teardown enqueued goes
   with the mount rather than being applied by the surviving sibling's frame. *)
let test_two_mounts_keep_their_own_requests () =
  let run_pending, restore_raf = collect_raf () in
  Fun.protect ~finally:restore_raf (fun () ->
      let mounted_a : Nopal_web.mounted =
        Nopal_web.mount Sibling_a.as_module (fresh_parent ())
      in
      let mounted_b : Nopal_web.mounted =
        Nopal_web.mount Sibling_b.as_module (fresh_parent ())
      in
      let pane_a = by_id Sibling_a.container_id in
      let pane_b = by_id Sibling_b.container_id in
      lay_out pane_a;
      lay_out pane_b;
      reset_scroll_writes pane_a;
      reset_scroll_writes pane_b;
      click Sibling_a.scroll_trigger_id;
      run_pending ();
      Alcotest.(check (float 0.001))
        "the mount whose app asked for it moved a whole viewport" 100.
        (scroll_top pane_a);
      Alcotest.(check int) "writing once" 1 (scroll_writes pane_a);
      Alcotest.(check int)
        "and the sibling mount, whose frame ran in the same batch, wrote \
         nothing"
        0 (scroll_writes pane_b);
      (* Affirmative arm: the sibling is drivable on the very same fixture, so
         the zero above is the queue being mount-local rather than the sibling
         being inert or unreachable. *)
      click Sibling_b.scroll_trigger_id;
      run_pending ();
      Alcotest.(check (float 0.001))
        "the sibling moves when its own app asks" 100. (scroll_top pane_b);
      Alcotest.(check int) "writing once" 1 (scroll_writes pane_b);
      Alcotest.(check int)
        "and the first mount was not moved by the sibling's frame" 1
        (scroll_writes pane_a);
      (* A request enqueued by the last dispatch before teardown. *)
      click Sibling_b.scroll_trigger_id;
      mounted_b.unmount ();
      run_pending ();
      Alcotest.(check int)
        "the torn-down mount's last request went with the mount" 1
        (scroll_writes pane_b);
      Alcotest.(check int)
        "and the surviving mount did not inherit it" 1 (scroll_writes pane_a);
      mounted_a.unmount ())

(* A request that arrives between two frames rather than during a dispatch —
   here from a [Cmd.after] timer, which is also the shape a settled task has.
   The queue is what carries it, so the frame that follows applies it exactly
   as it applies one issued inside a dispatch. *)
let test_a_request_arriving_between_frames_lands_on_the_next_one () =
  let settle_timers, restore_timers = capture_timeouts () in
  Fun.protect ~finally:restore_timers (fun () ->
      let target = fresh_parent () in
      let mounted : Nopal_web.mounted =
        Nopal_web.mount Deferred_pane.as_module target
      in
      let container = by_id Deferred_pane.container_id in
      lay_out container;
      reset_scroll_writes container;
      click Deferred_pane.deferred_trigger_id;
      run_frame ();
      Alcotest.(check int)
        "the dispatch scheduled a timer and asked for no movement" 0
        (scroll_writes container);
      settle_timers ();
      Alcotest.(check int)
        "and the timer's dispatch enqueues rather than writing, the way a \
         dispatch inside a frame does"
        0 (scroll_writes container);
      run_frame ();
      Alcotest.(check int)
        "the next frame applies it" 1 (scroll_writes container);
      Alcotest.(check (float 0.001))
        "moving the container a whole viewport on" 100. (scroll_top container);
      mounted.unmount ())

(* The render pass is guarded like the two drains, and the guard is what makes
   the relocated re-arm worth having: without it an exception in the DOM patch
   escaped the rAF callback and the loop was never re-armed at all. What the
   guard costs is stated in [drive]'s own comment and asserted here — the frame
   that threw leaves the live tree patched only as far as it got, and every
   frame after reconciles against that tree rather than against the model. *)
let test_a_throwing_render_pass_is_reported_and_the_loop_continues () =
  let restore_raf = count_raf_arms () in
  (* mutable: every description this mount reported, newest first *)
  let reported = ref [] in
  let target = fresh_parent () in
  let mounted : Nopal_web.mounted =
    Nopal_web.mount
      ~on_error:(fun description -> reported := description :: !reported)
      Reconcile_pane.as_module target
  in
  let rows = by_id Reconcile_pane.rows_id in
  Alcotest.(check bool)
    "the mount rendered a row container the patch can be refused on" true
    (not (Jv.is_none rows));
  Alcotest.(check int)
    "holding every row the model asked for" initial_rows
    (List.length (child_nodes rows));
  click Reconcile_pane.drop_trigger_id;
  let armed_before = raf_arms () in
  let patchable_again = refuse_child_removal rows in
  run_frame ();
  patchable_again ();
  Alcotest.(check int) "the failed patch was reported" 1 (List.length !reported);
  Alcotest.(check bool)
    "naming the stage that failed" true
    (List.exists (fun d -> contains d "render pass") !reported);
  Alcotest.(check bool)
    "and what went wrong" true
    (List.exists (fun d -> contains d "Patch_refused") !reported);
  Alcotest.(check int)
    "the frame whose render pass threw still asked for its successor"
    (armed_before + 1) (raf_arms ());
  (* The consequence the guard buys and the rAF comment names: the model dropped
     a row, the patch could not, and the tree the next frame reconciles against
     still holds it. *)
  Alcotest.(check int)
    "the row the patch could not remove is still in the live tree" initial_rows
    (List.length (child_nodes rows));
  (* Affirmative arm on the same fixture: a later frame still patches, so the
     count above is the one patch having failed rather than the pane having
     stopped rendering or the trigger having stopped dispatching. *)
  click Reconcile_pane.drop_trigger_id;
  run_frame ();
  Alcotest.(check int)
    "a frame after the one that threw patches to the model's row count"
    (initial_rows - 2)
    (List.length (child_nodes rows));
  mounted.unmount ();
  restore_raf ()

(* A mount given no [~on_error] still has somewhere to send a fault: this
   backend's own default, which the module installs so that an exception in a
   drain cannot reach the browser as an uncaught error instead.

   What this case pins is the survivable half — the frame does not propagate,
   the request behind the failing one is still applied in it, and the loop keeps
   running. What it does NOT pin is the text the default writes, or that it
   writes at all: the default goes to stderr, which is not observable from
   inside this jsoo Alcotest harness, so the ["[nopal_web] "] prefix is asserted
   nowhere in the suite. *)
let test_a_mount_without_a_fault_sink_still_drains () =
  let restore_raf = count_raf_arms () in
  let target = fresh_parent () in
  let mounted : Nopal_web.mounted =
    Nopal_web.mount Default_sink_pane.as_module target
  in
  let container = by_id Default_sink_pane.container_id in
  lay_out container;
  reset_scroll_writes container;
  click Default_sink_pane.twice_trigger_id;
  let armed_before = raf_arms () in
  refuse_first_measurement container;
  (* No handler here on purpose: a frame that let the fault out of the default
     sink would fail this case by propagating out of [run_frame]. *)
  run_frame ();
  Alcotest.(check int)
    "the frame that reported through the default sink still asked for its \
     successor"
    (armed_before + 1) (raf_arms ());
  Alcotest.(check int)
    "the request behind the failing one still wrote, and the failing one never \
     did"
    1 (scroll_writes container);
  Alcotest.(check (float 0.001))
    "landing a quarter of a viewport on from where it started" 25.
    (scroll_top container);
  (* Affirmative arm on the same fixture: measurable, the same batch writes
     both of its requests. *)
  click Default_sink_pane.twice_trigger_id;
  run_frame ();
  Alcotest.(check int)
    "both requests of a measurable frame wrote" 3 (scroll_writes container);
  Alcotest.(check (float 0.001))
    "a whole viewport and a quarter further on" 150. (scroll_top container);
  mounted.unmount ();
  restore_raf ()

let () =
  Alcotest.run "nopal_web mount scroll_by"
    [
      ( "drain placement",
        [
          Alcotest.test_case "measures the container the frame patched" `Quick
            test_drain_measures_the_patched_container;
          Alcotest.test_case "focus drains after the relative scroll" `Quick
            test_focus_drains_after_the_relative_scroll;
          Alcotest.test_case "a throwing drain leaves the loop running" `Quick
            test_a_throwing_drain_leaves_the_loop_running;
          Alcotest.test_case
            "a throwing request is reported and the rest still drain" `Quick
            test_a_throwing_request_is_reported_and_the_rest_drain;
          Alcotest.test_case "the focus drain survives a throwing scroll drain"
            `Quick test_the_focus_drain_survives_a_throwing_scroll_drain;
          Alcotest.test_case "two mounts keep their own requests" `Quick
            test_two_mounts_keep_their_own_requests;
          Alcotest.test_case
            "a request arriving between frames lands on the next one" `Quick
            test_a_request_arriving_between_frames_lands_on_the_next_one;
          Alcotest.test_case
            "a throwing render pass is reported and the loop continues" `Quick
            test_a_throwing_render_pass_is_reported_and_the_loop_continues;
          Alcotest.test_case "a mount without a fault sink still drains" `Quick
            test_a_mount_without_a_fault_sink_still_drains;
        ] );
    ]

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

   Each case mounts an app with an id namespace of its own, because the shim's
   element registry is never pruned: a container the first case left behind
   would answer to a shared id and the second case would measure a node nothing
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
  let row_id i = I.prefix ^ "-row-" ^ string_of_int i

  type model = { rows : int }
  type msg = Shrink_and_scroll | Scroll_and_focus

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

  let row i =
    Nopal_element.Element.Box
      {
        style = Nopal_style.Style.default;
        interaction = Nopal_style.Interaction.default;
        attrs = [ ("id", row_id i) ];
        children = [];
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

let () =
  Alcotest.run "nopal_web mount scroll_by"
    [
      ( "drain placement",
        [
          Alcotest.test_case "measures the container the frame patched" `Quick
            test_drain_measures_the_patched_container;
          Alcotest.test_case "focus drains after the relative scroll" `Quick
            test_focus_drains_after_the_relative_scroll;
        ] );
    ]

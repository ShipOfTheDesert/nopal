open Nopal_test.Test_renderer
module Text = Nopal_style.Text

(* Native structural coverage for one group of the kitchen-sink typography
   section (feature 0130): the container that declares [Preserve] for its own
   subtree, and the four rows inside it. Scoped deliberately to that group —
   the rest of [view_typography] (heading scale, alignment, weights, colours,
   the section-level whitespace rows) has never had a structural suite, and
   absorbing it here would go past what this feature created.

   The group is the part worth pinning without a browser: three of its four rows
   author a value whose whole point is what it does *against an inherited*
   [Preserve], so the row and the container are one claim, not two. Everything
   below reads the resolved [Text.t] the section actually built, so a row wired
   to the wrong axis fails here rather than in Chromium. Navigation is stubbed
   and storage in-memory, mirroring {!Test_style_removal_section}. *)
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

let pp_whitespace ppf (ws : Text.whitespace) =
  Format.pp_print_string ppf
    (match ws with
    | Collapse -> "Collapse"
    | Preserve -> "Preserve")

let pp_text_overflow ppf (ov : Text.text_overflow) =
  Format.pp_print_string ppf
    (match ov with
    | Clip -> "Clip"
    | Ellipsis -> "Ellipsis"
    | Wrap -> "Wrap"
    | No_wrap -> "No_wrap")

let whitespace =
  Alcotest.(option (testable pp_whitespace Text.equal_whitespace))

let text_overflow =
  Alcotest.(option (testable pp_text_overflow Text.equal_text_overflow))

(* The container node itself, found from the rendered section rather than
   constructed, so a group that stopped being rendered fails loudly instead of
   leaving every row assertion vacuously unreachable. *)
let container () =
  let section = tree (render (K.view_typography (fst (K.init ())))) in
  match
    find (By_attr ("data-testid", "whitespace-preserving-container")) section
  with
  | Some node -> node
  | None -> Alcotest.fail "the typography section rendered no preserving group"

(* The text style a row resolved to. Reached through the row's own anchor and
   then its first child — the anchor carries the sample alone — so this does not
   restate the sample literal the section defines. *)
let row_text_style group testid =
  let anchor =
    match find (By_attr ("data-testid", testid)) group with
    | Some node -> node
    | None -> Alcotest.fail (testid ^ ": the group renders no such row")
  in
  let sample =
    match find First_child anchor with
    | Some node -> node
    | None -> Alcotest.fail (testid ^ ": the row anchor carries no text")
  in
  match text_style sample with
  | Some style -> style
  | None -> Alcotest.fail (testid ^ ": the row's text carries no text style")

(* Without this the three rows below assert against nothing: an explicit
   [Collapse] and an unset whitespace resolve identically unless an ancestor
   preserves. *)
let test_container_preserves () =
  let style =
    match style (container ()) with
    | Some style -> style
    | None -> Alcotest.fail "the preserving group is not an element"
  in
  Alcotest.check whitespace "the group declares preservation for its subtree"
    (Some Text.Preserve) style.Nopal_style.Style.text.whitespace

(* Both axes of all four rows in one table, so the two rows that leave an axis
   unset are read beside the two that set it: an [None] expectation that a
   broken helper could satisfy by never reaching the text-style path at all is
   witnessed here by sibling rows on the same helper producing [Some]. The last
   row is the trap — it authors only the wrapping axis and therefore loses the
   container's preservation at the platform, which is exactly why its authored
   whitespace must stay unset. *)
let test_rows_author_their_axes () =
  let group = container () in
  let axes testid =
    let style = row_text_style group testid in
    (style.Text.whitespace, style.Text.text_overflow)
  in
  let expected =
    [
      ("whitespace-inherited", (None, None));
      ("whitespace-collapse", (Some Text.Collapse, None));
      ("whitespace-collapse-nowrap", (Some Text.Collapse, Some Text.No_wrap));
      ("whitespace-inherited-nowrap", (None, Some Text.No_wrap));
    ]
  in
  List.iter
    (fun (testid, (expected_whitespace, expected_overflow)) ->
      let actual_whitespace, actual_overflow = axes testid in
      Alcotest.check whitespace
        (testid ^ ": collapsing axis")
        expected_whitespace actual_whitespace;
      Alcotest.check text_overflow
        (testid ^ ": wrapping axis")
        expected_overflow actual_overflow)
    expected

let () =
  Alcotest.run "kitchen_sink_typography_section"
    [
      ( "inherited whitespace",
        [
          Alcotest.test_case "the container preserves for its subtree" `Quick
            test_container_preserves;
          Alcotest.test_case "each row authors its own axes" `Quick
            test_rows_author_their_axes;
        ] );
    ]

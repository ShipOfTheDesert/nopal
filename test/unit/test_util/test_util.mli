(** Shared test utilities for Nopal unit tests. *)

val string_contains : string -> sub:string -> bool
(** [string_contains s ~sub] returns [true] if [sub] appears anywhere in [s]. *)

val contains_fragment : string -> fragment:string -> bool
(** [contains_fragment record ~fragment] is [string_contains] with the left-hand
    side anchored: [fragment] has to begin [record] or follow the space that
    separates it from the fragment before it.

    A serialized model record joins [field=value;] fragments with a space, so
    every fragment is bounded on the right by its own ';' and on the left by
    nothing at all. That is enough until one field name ends in another —
    [original_byte_size=] ends in [byte_size=] — at which point an unanchored
    search for the shorter field is satisfied by the longer field's fragment
    whenever the two values coincide. Use this wherever a field name is a suffix
    of another field name in the same record; [string_contains] stays correct
    for everything else. *)

val pp_selector : Format.formatter -> Nopal_test.Test_renderer.selector -> unit
val error_testable : Nopal_test.Test_renderer.error Alcotest.testable
val node_pp : Format.formatter -> Nopal_test.Test_renderer.node -> unit

val node_equal :
  Nopal_test.Test_renderer.node -> Nopal_test.Test_renderer.node -> bool

val node_testable : Nopal_test.Test_renderer.node Alcotest.testable

val check_node :
  string ->
  Nopal_test.Test_renderer.node ->
  Nopal_test.Test_renderer.node ->
  unit

val count_unique : ('a -> 'a -> bool) -> 'a list -> int
(** [count_unique eq lst] returns the number of distinct elements in [lst] using
    [eq] for equality comparison. *)

val find_or_fail :
  string ->
  Nopal_test.Test_renderer.selector ->
  Nopal_test.Test_renderer.node ->
  Nopal_test.Test_renderer.node
(** [find_or_fail message selector node] is the first descendant of [node]
    matching [selector], or an Alcotest failure carrying [message]. Use it
    wherever the absence of the node is itself a test failure rather than a
    value the test goes on to inspect. *)

val style_testable : Nopal_style.Style.t Alcotest.testable
(** Compares whole styles with {!Nopal_style.Style.equal}; prints an opaque
    placeholder, so a failure names the assertion rather than the record. *)

val text_style_testable : Nopal_style.Text.t Alcotest.testable
(** Compares text styles with {!Nopal_style.Text.equal}. *)

val bold_label_style : Nopal_style.Style.t
(** A style whose only departure from {!Nopal_style.Style.default} is a bold
    font weight on its text component — the standard fixture for asserting that
    a label style override reaches both the label box and the text node inside
    it. *)

val table_keys_under : heading:string -> string -> string list option
(** [table_keys_under ~heading text] is the key column of every row of the first
    Markdown table after the line of [text] that equals [heading], in table
    order. The key column is the second one, the first being a row number;
    backticks are stripped from it, and the header row (key [Key]) and the
    separator row are dropped. Prose between the heading and the table is
    skipped, and the table ends at the first line that does not start with
    ["|"].

    [None] when no line equals [heading], so a renamed heading fails as that
    rather than as an empty list. *)

val does_not_compile : string
(** The before-column literal for a change-list candidate whose change is
    compile-visible: no reading can equal it, so such a candidate lands in the
    moved partition by construction. *)

val simulated :
  show_msg:('msg -> string) ->
  ('msg Nopal_test.Test_renderer.rendered ->
  (unit, Nopal_test.Test_renderer.error) result) ->
  'msg Nopal_element.Element.t ->
  string
(** [simulated ~show_msg sim element] renders [element], runs [sim] on the
    render, and reports what a simulator answers on it: [Ok] with every
    dispatched message rendered through [show_msg], or which error arm [sim]
    returned. Use [~show_msg:Fun.id] where the message type is already [string].
*)

val check_change_list :
  candidates:(string * string * (unit -> string)) list ->
  published:string list ->
  unchanged:string list ->
  unit
(** [check_change_list ~candidates ~published ~unchanged] partitions
    [candidates] — each a key, its before-column answer, and a thunk reading its
    answer as the tree stands — into the keys whose answer moved and the keys
    whose answer did not, and checks that partition against [published] and
    [unchanged] in every direction: a published key whose answer did not move, a
    moved key that is not published, the published list out of order with the
    moved keys, and an unchanged key that in fact moved all fail. *)

val llms_txt : unit -> string
(** [llms_txt ()] is the repository's [llms.txt], read from the root of the
    build tree, or an Alcotest failure when it cannot be read. The path is taken
    from the running executable rather than the working directory, so it holds
    under [dune exec] as well, once [dune build] has copied the file; it holds
    only for a test executable in a directory directly under [test/unit/], and
    that test's stanza must declare [(deps %{project_root}/llms.txt)] for dune
    to copy the file there. *)

(* The expected strings below are whole key strings, never substrings: "d" is a
   substring of "Ctrl+d" and "Shift+Tab" of "Ctrl+Shift+Tab", so a containment
   assertion would pass on the wrong string. *)

let check_chord label expected ~key ~ctrl ~shift =
  Alcotest.(check string)
    label expected
    (Nopal_mvu.Key_chord.of_event ~key ~ctrl ~shift)

let test_ctrl_prefixes_the_key () =
  check_chord "letter under Ctrl" "Ctrl+d" ~key:"d" ~ctrl:true ~shift:false;
  check_chord "named key under Ctrl" "Ctrl+ArrowDown" ~key:"ArrowDown"
    ~ctrl:true ~shift:false

let test_shift_prefix_unchanged () =
  check_chord "named key under Shift" "Shift+Tab" ~key:"Tab" ~ctrl:false
    ~shift:true;
  check_chord "letter under Shift is uppercase" "Shift+D" ~key:"D" ~ctrl:false
    ~shift:true;
  check_chord "punctuation reached through Shift" "Shift+?" ~key:"?" ~ctrl:false
    ~shift:true

let test_no_modifier_is_the_bare_key () =
  check_chord "bare letter" "d" ~key:"d" ~ctrl:false ~shift:false;
  check_chord "bare named key" "ArrowDown" ~key:"ArrowDown" ~ctrl:false
    ~shift:false;
  check_chord "bare punctuation" "/" ~key:"/" ~ctrl:false ~shift:false

(* One fixture holding both flags at once. Ctrl-only and Shift-only cases cannot
   pin the order; if this case is deleted the order is unpinned. *)
let test_both_modifiers_use_canonical_order () =
  check_chord "letter under Ctrl and Shift" "Ctrl+Shift+D" ~key:"D" ~ctrl:true
    ~shift:true;
  check_chord "punctuation under Ctrl and Shift" "Ctrl+Shift+?" ~key:"?"
    ~ctrl:true ~shift:true

(* Each modifier alone, and each pressed while the other is held. The
   cross-modifier pairs are the ones a rule that only suppressed the pressed
   modifier's own prefix would get wrong. The last row is a keyup: releasing
   Shift while Ctrl is still held reports "Shift" with the Ctrl flag set. *)
let test_modifier_keypress_carries_no_prefix () =
  check_chord "Ctrl pressed alone" "Control" ~key:"Control" ~ctrl:true
    ~shift:false;
  check_chord "Shift pressed alone" "Shift" ~key:"Shift" ~ctrl:false ~shift:true;
  check_chord "Shift pressed while Ctrl held" "Shift" ~key:"Shift" ~ctrl:true
    ~shift:true;
  check_chord "Ctrl pressed while Shift held" "Control" ~key:"Control"
    ~ctrl:true ~shift:true;
  check_chord "Shift released while Ctrl held" "Shift" ~key:"Shift" ~ctrl:true
    ~shift:false

(* Only the two folded modifier names are exempt from prefixing. Alt and Meta
   are not folded — their flags are never read — so their own key names take the
   prefixes of whatever folded modifier is held, exactly like any other key.
   Widening the exemption to every modifier name is the same change as adding an
   "Alt+" prefix, and this case is what makes that coupling visible. *)
let test_unfolded_modifier_keypress_is_prefixed () =
  check_chord "Alt pressed while Ctrl held" "Ctrl+Alt" ~key:"Alt" ~ctrl:true
    ~shift:false;
  check_chord "Meta pressed while Ctrl held" "Ctrl+Meta" ~key:"Meta" ~ctrl:true
    ~shift:false;
  check_chord "Alt pressed alone" "Alt" ~key:"Alt" ~ctrl:false ~shift:false

let () =
  Alcotest.run "nopal_mvu_key_chord"
    [
      ( "Key_chord.of_event",
        [
          Alcotest.test_case "ctrl_prefixes_the_key" `Quick
            test_ctrl_prefixes_the_key;
          Alcotest.test_case "shift_prefix_unchanged" `Quick
            test_shift_prefix_unchanged;
          Alcotest.test_case "no_modifier_is_the_bare_key" `Quick
            test_no_modifier_is_the_bare_key;
          Alcotest.test_case "both_modifiers_use_canonical_order" `Quick
            test_both_modifiers_use_canonical_order;
          Alcotest.test_case "modifier_keypress_carries_no_prefix" `Quick
            test_modifier_keypress_carries_no_prefix;
          Alcotest.test_case "unfolded_modifier_keypress_is_prefixed" `Quick
            test_unfolded_modifier_keypress_is_prefixed;
        ] );
    ]

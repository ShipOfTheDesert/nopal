(** Tests for [Nopal_scene.Graphic_name] — the decision every graphic carries: a
    checked name, or decorative.

    A refusal is asserted with the exact input it carries, and an acceptance
    with the exact string the [Named] case holds. *)

open Nopal_scene

let pp_name ppf (name : Graphic_name.t) =
  match name with
  | Graphic_name.Named label -> Format.fprintf ppf "Named %S" label
  | Graphic_name.Decorative -> Format.fprintf ppf "Decorative"

let pp_error ppf (error : Graphic_name.error) =
  match error with
  | Graphic_name.Blank { input } ->
      Format.fprintf ppf "Blank { input = %S }" input

let equal_error (a : Graphic_name.error) (b : Graphic_name.error) =
  match (a, b) with
  | Graphic_name.Blank { input = i1 }, Graphic_name.Blank { input = i2 } ->
      String.equal i1 i2

let outcome =
  Alcotest.result
    (Alcotest.testable pp_name Graphic_name.equal)
    (Alcotest.testable pp_error equal_error)

let label_of input =
  match Graphic_name.named input with
  | Ok (Graphic_name.Named label) -> Some label
  | Ok Graphic_name.Decorative
  | Error (Graphic_name.Blank _) ->
      None

let test_named_refuses_blank () =
  List.iter
    (fun input ->
      Alcotest.check outcome
        (Printf.sprintf "%S is blank" input)
        (Error (Graphic_name.Blank { input }))
        (Graphic_name.named input))
    [ ""; " "; "\t\n\r\x0c "; "\x01"; "\x0b"; " \x01 "; "\x7f"; "\x00" ]

let test_named_keeps_input_unchanged () =
  List.iter
    (fun input ->
      Alcotest.(check (option string))
        (Printf.sprintf "%S is named unchanged" input)
        (Some input) (label_of input))
    [ " Equity "; "\xc2\xa0"; "A\x01" ]

let test_equal_distinguishes_cases_and_names () =
  let named input =
    match Graphic_name.named input with
    | Ok name -> name
    | Error (Graphic_name.Blank _) -> Alcotest.failf "%S was refused" input
  in
  let equity = named "Equity" in
  Alcotest.(check bool)
    "decorative is not a name" false
    (Graphic_name.equal Graphic_name.decorative equity);
  Alcotest.(check bool)
    "a name is not decorative" false
    (Graphic_name.equal equity Graphic_name.decorative);
  Alcotest.(check bool)
    "decorative equals decorative" true
    (Graphic_name.equal Graphic_name.decorative Graphic_name.decorative);
  Alcotest.(check bool)
    "the same string is equal" true
    (Graphic_name.equal equity (named "Equity"));
  Alcotest.(check bool)
    "a different string is not equal" false
    (Graphic_name.equal equity (named "equity"))

let named_exn label =
  match Graphic_name.named label with
  | Ok n -> n
  | Error (Graphic_name.Blank _) -> Alcotest.failf "%S was refused" label

let test_aria_attrs_named () =
  Alcotest.(check (list (pair string (option string))))
    "named sets role and label and removes aria-hidden"
    [
      ("role", Some "img"); ("aria-label", Some "Equity"); ("aria-hidden", None);
    ]
    (Graphic_name.aria_attrs (named_exn "Equity"))

let test_aria_attrs_decorative () =
  Alcotest.(check (list (pair string (option string))))
    "decorative sets aria-hidden and removes role and label"
    [ ("role", None); ("aria-label", None); ("aria-hidden", Some "true") ]
    (Graphic_name.aria_attrs Graphic_name.decorative)

let test_image_alt () =
  Alcotest.(check string)
    "named is the label" "Equity"
    (Graphic_name.image_alt (named_exn "Equity"));
  Alcotest.(check string)
    "decorative is empty" ""
    (Graphic_name.image_alt Graphic_name.decorative)

let blank_gen =
  QCheck.Gen.(
    string_size
      ~gen:(map Char.chr (oneof [ int_range 0 0x20; return 0x7f ]))
      (int_range 0 8))

let property_blank_refused =
  QCheck.Test.make ~count:500 ~name:"property_blank_refused"
    (QCheck.make ~print:(Printf.sprintf "%S") blank_gen)
    (fun input ->
      match Graphic_name.named input with
      | Error (Graphic_name.Blank { input = got }) -> String.equal got input
      | Ok _ -> false)

let property_other_accepted_unchanged =
  QCheck.Test.make ~count:500 ~name:"property_other_accepted_unchanged"
    (QCheck.make ~print:(Printf.sprintf "%S")
       QCheck.Gen.(string_size ~gen:char (int_range 0 12)))
    (fun input ->
      let blank =
        String.for_all
          (fun c -> Char.code c <= 0x20 || Char.code c = 0x7f)
          input
      in
      match (blank, Graphic_name.named input) with
      | true, Error (Graphic_name.Blank { input = got }) ->
          String.equal got input
      | false, Ok (Graphic_name.Named label) -> String.equal label input
      | true, Ok _
      | false, Error (Graphic_name.Blank _)
      | _, Ok Graphic_name.Decorative ->
          false)

let () =
  Alcotest.run "Nopal_scene.Graphic_name"
    [
      ( "graphic_name",
        [
          Alcotest.test_case "named_refuses_blank" `Quick
            test_named_refuses_blank;
          Alcotest.test_case "named_keeps_input_unchanged" `Quick
            test_named_keeps_input_unchanged;
          Alcotest.test_case "equal_distinguishes_cases_and_names" `Quick
            test_equal_distinguishes_cases_and_names;
          Alcotest.test_case "aria_attrs_named" `Quick test_aria_attrs_named;
          Alcotest.test_case "aria_attrs_decorative" `Quick
            test_aria_attrs_decorative;
          Alcotest.test_case "image_alt" `Quick test_image_alt;
        ]
        @ List.map
            (QCheck_alcotest.to_alcotest ~speed_level:`Quick)
            [ property_blank_refused; property_other_accepted_unchanged ] );
    ]

let detail = "width must be positive, got 0"

let test_message_invalid_dimensions () =
  Alcotest.(check string)
    "prefixes the dimension failure and carries the detail verbatim"
    "Invalid image dimensions: width must be positive, got 0"
    (Nopal_image.message (Nopal_image.Invalid_dimensions detail))

let test_message_invalid_config () =
  Alcotest.(check string)
    "prefixes the config failure and carries the detail verbatim"
    "Invalid image config: quality must be between 0 and 1, got 1.5"
    (Nopal_image.message
       (Nopal_image.Invalid_config "quality must be between 0 and 1, got 1.5"))

(* Both constructors are fed the SAME detail, so a passing run proves the
   constructor itself discriminates the message rather than the payload leaking
   through an identity [message]. *)
let test_messages_are_distinct () =
  let dimensions =
    Nopal_image.message (Nopal_image.Invalid_dimensions detail)
  in
  let config = Nopal_image.message (Nopal_image.Invalid_config detail) in
  Alcotest.(check bool)
    "the two constructors describe themselves differently" false
    (String.equal dimensions config)

(* What the type equation buys. Constructing the error directly would compile
   even if the entry module declared its own unrelated variant, so the arm that
   actually pins the equation is the second one: a rejection produced inside the
   library, by a submodule whose signature names the internal error type, is
   handed to the entry module's [message] with no conversion. Drop the equation
   and this file stops compiling. *)
let test_reexported_error_equates () =
  Alcotest.(check string)
    "the entry module accepts a directly constructed error"
    "Invalid image dimensions: width must be positive, got 0"
    (Nopal_image.message (Nopal_image.Invalid_dimensions detail));
  match Nopal_image.Buffer.create ~width:0 ~height:2 ~rgba:Bytes.empty with
  | Ok _ -> Alcotest.fail "a zero width was expected to be rejected"
  | Error error ->
      Alcotest.(check string)
        "the entry module displays an error raised by a submodule"
        "Invalid image dimensions: width must be positive, got 0"
        (Nopal_image.message error)

(* The submodule signatures name [Image_error.t], so without the alias in the
   entry module the only way to write that type is through the mangled internal
   compilation-unit path, which is what odoc then prints for [Buffer.create] and
   [Config.make]. Naming the re-exported module here keeps the alias in use, and
   the annotations pin it as the same type as the entry module's [error]. *)
let test_error_module_is_reexported () =
  let direct : Nopal_image.Image_error.t =
    Nopal_image.Invalid_config "quality must be a number, got nan"
  in
  let through_entry : Nopal_image.error = direct in
  Alcotest.(check string)
    "the re-exported module names the same type as the entry module's error"
    (Nopal_image.Image_error.message direct)
    (Nopal_image.message through_entry)

let tests =
  [
    Alcotest.test_case "invalid dimensions message" `Quick
      test_message_invalid_dimensions;
    Alcotest.test_case "invalid config message" `Quick
      test_message_invalid_config;
    Alcotest.test_case "messages are distinct" `Quick test_messages_are_distinct;
    Alcotest.test_case "re-exported error equates" `Quick
      test_reexported_error_equates;
    Alcotest.test_case "the error module is re-exported" `Quick
      test_error_module_is_reexported;
  ]

let () = Alcotest.run "Nopal_image" [ ("Image_error", tests) ]

type t = Named of string | Decorative
type error = Blank of { input : string }

(* Whitespace, every C0 control and DEL: the bytes an accessible name cannot
   show, and that [Svg_fmt.xml_escape] drops from an attribute. *)
let is_blank_char c =
  match c with
  | '\x00' .. '\x20'
  | '\x7f' ->
      true
  | _ -> false

let named input =
  match String.for_all is_blank_char input with
  | true -> Error (Blank { input })
  | false -> Ok (Named input)

let decorative = Decorative

let equal a b =
  match (a, b) with
  | Named x, Named y -> String.equal x y
  | Decorative, Decorative -> true
  | Named _, Decorative
  | Decorative, Named _ ->
      false

let aria_attrs = function
  | Named label ->
      [
        ("role", Some "img"); ("aria-label", Some label); ("aria-hidden", None);
      ]
  | Decorative ->
      [ ("role", None); ("aria-label", None); ("aria-hidden", Some "true") ]

let image_alt = function
  | Named label -> label
  | Decorative -> ""

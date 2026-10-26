type family =
  | System_ui
  | Sans_serif
  | Serif
  | Monospace
  | Ui_sans_serif
  | Ui_serif
  | Ui_monospace
  | Ui_rounded
  | Custom of string

module Generic = struct
  type t = System_ui | Sans_serif | Serif | Monospace

  let to_family : t -> family = function
    | System_ui -> System_ui
    | Sans_serif -> Sans_serif
    | Serif -> Serif
    | Monospace -> Monospace
end

type weight =
  | Thin
  | Extra_light
  | Light
  | Normal
  | Medium
  | Semi_bold
  | Bold
  | Extra_bold
  | Black

let equal_family a b =
  match (a, b) with
  | System_ui, System_ui -> true
  | Sans_serif, Sans_serif -> true
  | Serif, Serif -> true
  | Monospace, Monospace -> true
  | Ui_sans_serif, Ui_sans_serif -> true
  | Ui_serif, Ui_serif -> true
  | Ui_monospace, Ui_monospace -> true
  | Ui_rounded, Ui_rounded -> true
  | Custom s1, Custom s2 -> String.equal s1 s2
  | ( ( System_ui | Sans_serif | Serif | Monospace | Ui_sans_serif | Ui_serif
      | Ui_monospace | Ui_rounded | Custom _ ),
      _ ) ->
      false

type stack = { entries : family list; last_resort : Generic.t }

let stack entries ~last_resort = { entries; last_resort }

let families { entries; last_resort } =
  entries @ [ Generic.to_family last_resort ]

let equal_stack a b = List.equal equal_family (families a) (families b)

let equal_weight a b =
  match (a, b) with
  | Thin, Thin -> true
  | Extra_light, Extra_light -> true
  | Light, Light -> true
  | Normal, Normal -> true
  | Medium, Medium -> true
  | Semi_bold, Semi_bold -> true
  | Bold, Bold -> true
  | Extra_bold, Extra_bold -> true
  | Black, Black -> true
  | ( ( Thin | Extra_light | Light | Normal | Medium | Semi_bold | Bold
      | Extra_bold | Black ),
      _ ) ->
      false

let add_escaped_name_char buf c =
  match c with
  | '"'
  | '\\' ->
      Buffer.add_char buf '\\';
      Buffer.add_char buf c
  | '{'
  | '}'
  | ';'
  | '\000' .. '\031'
  | '\127' ->
      Buffer.add_string buf (Printf.sprintf "\\%x " (Char.code c))
  | c -> Buffer.add_char buf c

let quoted_name name =
  let buf = Buffer.create (String.length name + 2) in
  Buffer.add_char buf '"';
  String.iter (add_escaped_name_char buf) name;
  Buffer.add_char buf '"';
  Buffer.contents buf

let family_to_css_string = function
  | System_ui -> "system-ui"
  | Sans_serif -> "sans-serif"
  | Serif -> "serif"
  | Monospace -> "monospace"
  | Ui_sans_serif -> "ui-sans-serif"
  | Ui_serif -> "ui-serif"
  | Ui_monospace -> "ui-monospace"
  | Ui_rounded -> "ui-rounded"
  | Custom name -> quoted_name name

let stack_to_css_string s =
  String.concat ", " (List.map family_to_css_string (families s))

let weight_to_int = function
  | Thin -> 100
  | Extra_light -> 200
  | Light -> 300
  | Normal -> 400
  | Medium -> 500
  | Semi_bold -> 600
  | Bold -> 700
  | Extra_bold -> 800
  | Black -> 900

let weight_to_css_string w = string_of_int (weight_to_int w)

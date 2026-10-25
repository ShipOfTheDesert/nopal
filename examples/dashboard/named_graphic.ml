module Element = Nopal_element.Element
module Graphic_name = Nopal_element.Graphic_name

let refusal_message input =
  Printf.sprintf "Refused a blank graphic name: %S" input

let named_graphic label graphic =
  match Graphic_name.named label with
  | Ok name -> graphic name
  | Error (Graphic_name.Blank { input }) -> Element.text (refusal_message input)

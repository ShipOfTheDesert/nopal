type t = Invalid_dimensions of string | Invalid_config of string

let message = function
  | Invalid_dimensions detail ->
      Printf.sprintf "Invalid image dimensions: %s" detail
  | Invalid_config detail -> Printf.sprintf "Invalid image config: %s" detail

type error = Image_error.t =
  | Invalid_dimensions of string
  | Invalid_config of string

let message = Image_error.message

module Image_error = Image_error
module Buffer = Buffer
module Luma = Luma
module Sharpness = Sharpness
module Config = Config

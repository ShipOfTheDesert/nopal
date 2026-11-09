type writing_mode =
  | Horizontal_tb
  | Vertical_rl
  | Vertical_lr
  | Sideways_rl
  | Sideways_lr
  | Other_writing_mode

type direction = Ltr | Rtl | Other_direction
type orientation = Forward | Reversed
type axes = { x : orientation; y : orientation }

let writing_mode_of_string = function
  | "horizontal-tb" -> Horizontal_tb
  | "vertical-rl" -> Vertical_rl
  | "vertical-lr" -> Vertical_lr
  | "sideways-rl" -> Sideways_rl
  | "sideways-lr" -> Sideways_lr
  | _ -> Other_writing_mode

let direction_of_string = function
  | "ltr" -> Ltr
  | "rtl" -> Rtl
  | _ -> Other_direction

let neither = { x = Forward; y = Forward }
let x_only = { x = Reversed; y = Forward }
let y_only = { x = Forward; y = Reversed }
let both = { x = Reversed; y = Reversed }

(* Every pair is spelled out: a new writing mode or direction is a compile
   error here rather than a silent default. *)
let reversed_axes writing_mode direction =
  match (writing_mode, direction) with
  | Horizontal_tb, Ltr -> neither
  | Horizontal_tb, Rtl -> x_only
  | Vertical_rl, Ltr -> x_only
  | Vertical_rl, Rtl -> both
  | Vertical_lr, Ltr -> neither
  | Vertical_lr, Rtl -> y_only
  | Sideways_rl, Ltr -> x_only
  | Sideways_rl, Rtl -> both
  | Sideways_lr, Ltr -> y_only
  | Sideways_lr, Rtl -> neither
  | Other_writing_mode, (Ltr | Rtl | Other_direction)
  | ( (Horizontal_tb | Vertical_rl | Vertical_lr | Sideways_rl | Sideways_lr),
      Other_direction ) ->
      both

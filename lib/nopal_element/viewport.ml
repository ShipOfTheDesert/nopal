type orientation = Portrait | Landscape
type safe_area = { top : int; right : int; bottom : int; left : int }

let zero_insets = { top = 0; right = 0; bottom = 0; left = 0 }
let make_safe_area ~top ~right ~bottom ~left () = { top; right; bottom; left }
let safe_area_top sa = sa.top
let safe_area_right sa = sa.right
let safe_area_bottom sa = sa.bottom
let safe_area_left sa = sa.left

type t = {
  width : int;
  height : int;
  size_class : Size_class.t;
  orientation : orientation;
  safe_area : safe_area;
}

let make ~width ~height ?(safe_area = zero_insets) () =
  let size_class = Size_class.of_width width in
  let orientation = if height >= width then Portrait else Landscape in
  { width; height; size_class; orientation; safe_area }

let width vp = vp.width
let height vp = vp.height
let size_class vp = vp.size_class
let orientation vp = vp.orientation
let safe_area vp = vp.safe_area
let is_compact vp = Size_class.equal vp.size_class Size_class.Compact
let is_medium vp = Size_class.equal vp.size_class Size_class.Medium
let is_expanded vp = Size_class.equal vp.size_class Size_class.Expanded

let equal_orientation a b =
  match (a, b) with
  | Portrait, Portrait -> true
  | Landscape, Landscape -> true
  | Portrait, Landscape -> false
  | Landscape, Portrait -> false

let equal_safe_area a b =
  a.top = b.top && a.right = b.right && a.bottom = b.bottom && a.left = b.left

let equal a b =
  a.width = b.width
  && a.height = b.height
  && Size_class.equal a.size_class b.size_class
  && equal_orientation a.orientation b.orientation
  && equal_safe_area a.safe_area b.safe_area

let phone = make ~width:375 ~height:812 ()
let phone_landscape = make ~width:812 ~height:375 ()
let tablet = make ~width:768 ~height:1024 ()
let desktop = make ~width:1440 ~height:900 ()

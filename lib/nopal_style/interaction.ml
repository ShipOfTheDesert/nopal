type t = {
  hover : Style.t option;
  pressed : Style.t option;
  focused : Style.t option;
  focused_within : Style.t option;
}

let default =
  { hover = None; pressed = None; focused = None; focused_within = None }

let equal a b =
  Option.equal Style.equal a.hover b.hover
  && Option.equal Style.equal a.pressed b.pressed
  && Option.equal Style.equal a.focused b.focused
  && Option.equal Style.equal a.focused_within b.focused_within

let has_any t =
  Option.is_some t.hover
  || Option.is_some t.pressed
  || Option.is_some t.focused
  || Option.is_some t.focused_within

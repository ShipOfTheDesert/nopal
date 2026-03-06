type 'msg t =
  | Empty
  | Text of string
  | Box of { style : Nopal_style.Style.t; children : 'msg t list }
  | Row of { style : Nopal_style.Style.t; children : 'msg t list }
  | Column of { style : Nopal_style.Style.t; children : 'msg t list }
  | Button of {
      style : Nopal_style.Style.t;
      on_click : 'msg option;
      child : 'msg t;
    }
  | Input of {
      style : Nopal_style.Style.t;
      value : string;
      placeholder : string;
      on_change : (string -> 'msg) option;
      on_submit : 'msg option;
    }
  | Image of { style : Nopal_style.Style.t; src : string; alt : string }
  | Scroll of { style : Nopal_style.Style.t; child : 'msg t }
  | Keyed of { key : string; child : 'msg t }

let empty = Empty
let text s = Text s
let box ?(style = Nopal_style.Style.empty) children = Box { style; children }
let row ?(style = Nopal_style.Style.empty) children = Row { style; children }

let column ?(style = Nopal_style.Style.empty) children =
  Column { style; children }

let button ?(style = Nopal_style.Style.empty) ?on_click child =
  Button { style; on_click; child }

let input ?(style = Nopal_style.Style.empty) ?(placeholder = "") ?on_change
    ?on_submit value =
  Input { style; value; placeholder; on_change; on_submit }

let image ?(style = Nopal_style.Style.empty) ~src ~alt () =
  Image { style; src; alt }

let scroll ?(style = Nopal_style.Style.empty) child = Scroll { style; child }
let keyed key child = Keyed { key; child }

let rec map f = function
  | Empty -> Empty
  | Text s -> Text s
  | Box { style; children } ->
      Box { style; children = List.map (map f) children }
  | Row { style; children } ->
      Row { style; children = List.map (map f) children }
  | Column { style; children } ->
      Column { style; children = List.map (map f) children }
  | Button { style; on_click; child } ->
      Button { style; on_click = Option.map f on_click; child = map f child }
  | Input { style; value; placeholder; on_change; on_submit } ->
      Input
        {
          style;
          value;
          placeholder;
          on_change = Option.map (fun g s -> f (g s)) on_change;
          on_submit = Option.map f on_submit;
        }
  | Image { style; src; alt } -> Image { style; src; alt }
  | Scroll { style; child } -> Scroll { style; child = map f child }
  | Keyed { key; child } -> Keyed { key; child = map f child }

let rec equal a b =
  match (a, b) with
  | Empty, Empty -> true
  | Text s1, Text s2 -> String.equal s1 s2
  | Box { style = s1; children = c1 }, Box { style = s2; children = c2 }
  | Row { style = s1; children = c1 }, Row { style = s2; children = c2 }
  | Column { style = s1; children = c1 }, Column { style = s2; children = c2 }
    ->
      Nopal_style.Style.equal s1 s2 && equal_children c1 c2
  | ( Button { style = s1; on_click = oc1; child = ch1 },
      Button { style = s2; on_click = oc2; child = ch2 } ) ->
      Nopal_style.Style.equal s1 s2
      && Option.equal ( = ) oc1 oc2
      && equal ch1 ch2
  | ( Input
        {
          style = s1;
          value = v1;
          placeholder = p1;
          on_change = oc1;
          on_submit = os1;
        },
      Input
        {
          style = s2;
          value = v2;
          placeholder = p2;
          on_change = oc2;
          on_submit = os2;
        } ) ->
      Nopal_style.Style.equal s1 s2
      && String.equal v1 v2
      && String.equal p1 p2
      && Option.equal ( == ) oc1 oc2
      && Option.equal ( = ) os1 os2
  | ( Image { style = s1; src = src1; alt = alt1 },
      Image { style = s2; src = src2; alt = alt2 } ) ->
      Nopal_style.Style.equal s1 s2
      && String.equal src1 src2
      && String.equal alt1 alt2
  | Scroll { style = s1; child = ch1 }, Scroll { style = s2; child = ch2 } ->
      Nopal_style.Style.equal s1 s2 && equal ch1 ch2
  | Keyed { key = k1; child = ch1 }, Keyed { key = k2; child = ch2 } ->
      String.equal k1 k2 && equal ch1 ch2
  | ( ( Empty | Text _ | Box _ | Row _ | Column _ | Button _ | Input _ | Image _
      | Scroll _ | Keyed _ ),
      _ ) ->
      false

and equal_children c1 c2 = List.equal equal c1 c2

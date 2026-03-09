type pointer_event = { x : float; y : float }

type 'msg t =
  | Empty
  | Text of string
  | Box of {
      style : Nopal_style.Style.t;
      attrs : (string * string) list;
      children : 'msg t list;
    }
  | Row of {
      style : Nopal_style.Style.t;
      attrs : (string * string) list;
      children : 'msg t list;
    }
  | Column of {
      style : Nopal_style.Style.t;
      attrs : (string * string) list;
      children : 'msg t list;
    }
  | Button of {
      style : Nopal_style.Style.t;
      attrs : (string * string) list;
      on_click : 'msg option;
      on_dblclick : 'msg option;
      child : 'msg t;
    }
  | Input of {
      style : Nopal_style.Style.t;
      attrs : (string * string) list;
      value : string;
      placeholder : string;
      on_change : (string -> 'msg) option;
      on_submit : 'msg option;
      on_blur : 'msg option;
      on_keydown : (string -> 'msg option) option;
    }
  | Image of { style : Nopal_style.Style.t; src : string; alt : string }
  | Scroll of { style : Nopal_style.Style.t; child : 'msg t }
  | Keyed of { key : string; child : 'msg t }
  | Draw of {
      width : float;
      height : float;
      scene : Nopal_draw.Scene.t list;
      on_pointer_move : (pointer_event -> 'msg) option;
      on_click : (pointer_event -> 'msg) option;
      on_pointer_leave : 'msg option;
      cursor : Nopal_style.Cursor.t option;
      aria_label : string option;
    }

let empty = Empty
let text s = Text s

let box ?(style = Nopal_style.Style.empty) ?(attrs = []) children =
  Box { style; attrs; children }

let row ?(style = Nopal_style.Style.empty) ?(attrs = []) children =
  Row { style; attrs; children }

let column ?(style = Nopal_style.Style.empty) ?(attrs = []) children =
  Column { style; attrs; children }

let button ?(style = Nopal_style.Style.empty) ?(attrs = []) ?on_click
    ?on_dblclick child =
  Button { style; attrs; on_click; on_dblclick; child }

let input ?(style = Nopal_style.Style.empty) ?(attrs = []) ?(placeholder = "")
    ?on_change ?on_submit ?on_blur ?on_keydown value =
  Input
    {
      style;
      attrs;
      value;
      placeholder;
      on_change;
      on_submit;
      on_blur;
      on_keydown;
    }

let image ?(style = Nopal_style.Style.empty) ~src ~alt () =
  Image { style; src; alt }

let scroll ?(style = Nopal_style.Style.empty) child = Scroll { style; child }
let keyed key child = Keyed { key; child }

let draw ?on_pointer_move ?on_click ?on_pointer_leave ?cursor ?aria_label ~width
    ~height scene =
  Draw
    {
      width;
      height;
      scene;
      on_pointer_move;
      on_click;
      on_pointer_leave;
      cursor;
      aria_label;
    }

let rec map f = function
  | Empty -> Empty
  | Text s -> Text s
  | Box { style; attrs; children } ->
      Box { style; attrs; children = List.map (map f) children }
  | Row { style; attrs; children } ->
      Row { style; attrs; children = List.map (map f) children }
  | Column { style; attrs; children } ->
      Column { style; attrs; children = List.map (map f) children }
  | Button { style; attrs; on_click; on_dblclick; child } ->
      Button
        {
          style;
          attrs;
          on_click = Option.map f on_click;
          on_dblclick = Option.map f on_dblclick;
          child = map f child;
        }
  | Input
      {
        style;
        attrs;
        value;
        placeholder;
        on_change;
        on_submit;
        on_blur;
        on_keydown;
      } ->
      Input
        {
          style;
          attrs;
          value;
          placeholder;
          on_change = Option.map (fun g s -> f (g s)) on_change;
          on_submit = Option.map f on_submit;
          on_blur = Option.map f on_blur;
          on_keydown = Option.map (fun g s -> Option.map f (g s)) on_keydown;
        }
  | Image { style; src; alt } -> Image { style; src; alt }
  | Scroll { style; child } -> Scroll { style; child = map f child }
  | Keyed { key; child } -> Keyed { key; child = map f child }
  | Draw
      {
        width;
        height;
        scene;
        on_pointer_move;
        on_click;
        on_pointer_leave;
        cursor;
        aria_label;
      } ->
      Draw
        {
          width;
          height;
          scene;
          on_pointer_move = Option.map (fun g pe -> f (g pe)) on_pointer_move;
          on_click = Option.map (fun g pe -> f (g pe)) on_click;
          on_pointer_leave = Option.map f on_pointer_leave;
          cursor;
          aria_label;
        }

let equal_attrs a1 a2 =
  List.equal
    (fun (k1, v1) (k2, v2) -> String.equal k1 k2 && String.equal v1 v2)
    a1 a2

let rec equal a b =
  match (a, b) with
  | Empty, Empty -> true
  | Text s1, Text s2 -> String.equal s1 s2
  | ( Box { style = s1; attrs = a1; children = c1 },
      Box { style = s2; attrs = a2; children = c2 } )
  | ( Row { style = s1; attrs = a1; children = c1 },
      Row { style = s2; attrs = a2; children = c2 } )
  | ( Column { style = s1; attrs = a1; children = c1 },
      Column { style = s2; attrs = a2; children = c2 } ) ->
      Nopal_style.Style.equal s1 s2 && equal_attrs a1 a2 && equal_children c1 c2
  | ( Button
        {
          style = s1;
          attrs = a1;
          on_click = oc1;
          on_dblclick = od1;
          child = ch1;
        },
      Button
        {
          style = s2;
          attrs = a2;
          on_click = oc2;
          on_dblclick = od2;
          child = ch2;
        } ) ->
      Nopal_style.Style.equal s1 s2
      && equal_attrs a1 a2
      && Option.equal ( = ) oc1 oc2
      && Option.equal ( = ) od1 od2
      && equal ch1 ch2
  | ( Input
        {
          style = s1;
          attrs = a1;
          value = v1;
          placeholder = p1;
          on_change = oc1;
          on_submit = os1;
          on_blur = ob1;
          on_keydown = ok1;
        },
      Input
        {
          style = s2;
          attrs = a2;
          value = v2;
          placeholder = p2;
          on_change = oc2;
          on_submit = os2;
          on_blur = ob2;
          on_keydown = ok2;
        } ) ->
      Nopal_style.Style.equal s1 s2
      && equal_attrs a1 a2
      && String.equal v1 v2
      && String.equal p1 p2
      && Option.equal ( == ) oc1 oc2
      && Option.equal ( = ) os1 os2
      && Option.equal ( = ) ob1 ob2
      && Option.equal ( == ) ok1 ok2
  | ( Image { style = s1; src = src1; alt = alt1 },
      Image { style = s2; src = src2; alt = alt2 } ) ->
      Nopal_style.Style.equal s1 s2
      && String.equal src1 src2
      && String.equal alt1 alt2
  | Scroll { style = s1; child = ch1 }, Scroll { style = s2; child = ch2 } ->
      Nopal_style.Style.equal s1 s2 && equal ch1 ch2
  | Keyed { key = k1; child = ch1 }, Keyed { key = k2; child = ch2 } ->
      String.equal k1 k2 && equal ch1 ch2
  | ( Draw
        {
          width = w1;
          height = h1;
          scene = s1;
          cursor = c1;
          aria_label = al1;
          on_pointer_move = _;
          on_click = _;
          on_pointer_leave = _;
        },
      Draw
        {
          width = w2;
          height = h2;
          scene = s2;
          cursor = c2;
          aria_label = al2;
          on_pointer_move = _;
          on_click = _;
          on_pointer_leave = _;
        } ) ->
      Float.equal w1 w2
      && Float.equal h1 h2
      && List.equal Nopal_draw.Scene.equal s1 s2
      && Option.equal Nopal_style.Cursor.equal c1 c2
      && Option.equal String.equal al1 al2
  | ( ( Empty | Text _ | Box _ | Row _ | Column _ | Button _ | Input _ | Image _
      | Scroll _ | Keyed _ | Draw _ ),
      _ ) ->
      false

and equal_children c1 c2 = List.equal equal c1 c2

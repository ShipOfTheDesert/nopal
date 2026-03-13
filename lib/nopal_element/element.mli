(** Pure UI description type.

    [Element.t] is the value that view functions return. It describes what
    should appear on screen without coupling to any rendering backend. The type
    is exposed (not abstract) so that renderers can exhaustively pattern-match
    on all constructors. *)

type pointer_event = {
  x : float;
  y : float;
  client_x : float;
  client_y : float;
}
(** Pointer coordinates. [x]/[y] are element-local (for hit testing and zoom
    center). [client_x]/[client_y] are viewport-relative (stable across
    re-renders — use these for drag delta computation). *)

type wheel_event = { delta_y : float; x : float; y : float }
(** Wheel event with scroll delta and element-local coordinates. *)

type 'msg t =
  | Empty
  | Text of { content : string; text_style : Nopal_style.Text.t option }
  | Box of {
      style : Nopal_style.Style.t;
      interaction : Nopal_style.Interaction.t;
      attrs : (string * string) list;
      children : 'msg t list;
      on_pointer_move : (pointer_event -> 'msg) option;
      on_pointer_leave : 'msg option;
      on_pointer_down : (pointer_event -> 'msg) option;
      on_pointer_up : (pointer_event -> 'msg) option;
      on_wheel : (wheel_event -> 'msg) option;
    }
  | Row of {
      style : Nopal_style.Style.t;
      interaction : Nopal_style.Interaction.t;
      attrs : (string * string) list;
      children : 'msg t list;
    }
  | Column of {
      style : Nopal_style.Style.t;
      interaction : Nopal_style.Interaction.t;
      attrs : (string * string) list;
      children : 'msg t list;
    }
  | Button of {
      style : Nopal_style.Style.t;
      interaction : Nopal_style.Interaction.t;
      attrs : (string * string) list;
      on_click : 'msg option;
      on_dblclick : 'msg option;
      child : 'msg t;
    }
  | Input of {
      style : Nopal_style.Style.t;
      interaction : Nopal_style.Interaction.t;
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
      scene : Nopal_scene.Scene.t list;
      on_pointer_move : (pointer_event -> 'msg) option;
      on_click : (pointer_event -> 'msg) option;
      on_pointer_leave : 'msg option;
      on_pointer_down : (pointer_event -> 'msg) option;
      on_pointer_up : (pointer_event -> 'msg) option;
      on_wheel : (wheel_event -> 'msg) option;
      cursor : Nopal_style.Cursor.t option;
      aria_label : string option;
    }

(** {1 Builders}

    Ergonomic constructors with labelled optional arguments. Application code
    should use these instead of raw variant constructors. *)

val empty : 'msg t
(** An element that renders nothing. *)

val text : string -> 'msg t
(** A text node with no text style. *)

val styled_text : text_style:Nopal_style.Text.t -> string -> 'msg t
(** A text node with an explicit text style. *)

val box :
  ?style:Nopal_style.Style.t ->
  ?interaction:Nopal_style.Interaction.t ->
  ?attrs:(string * string) list ->
  ?on_pointer_move:(pointer_event -> 'msg) ->
  ?on_pointer_leave:'msg ->
  ?on_pointer_down:(pointer_event -> 'msg) ->
  ?on_pointer_up:(pointer_event -> 'msg) ->
  ?on_wheel:(wheel_event -> 'msg) ->
  'msg t list ->
  'msg t
(** A generic container. Children are laid out according to backend defaults.

    [attrs] carries key-value metadata (e.g. [data-*] attributes, ARIA labels)
    that web backends render as HTML attributes. Non-web backends may ignore
    attributes that have no native equivalent. Prefer [attrs] for test selectors
    and accessibility hints, not for styling or behavior. *)

val row :
  ?style:Nopal_style.Style.t ->
  ?interaction:Nopal_style.Interaction.t ->
  ?attrs:(string * string) list ->
  'msg t list ->
  'msg t
(** A horizontal layout container. *)

val column :
  ?style:Nopal_style.Style.t ->
  ?interaction:Nopal_style.Interaction.t ->
  ?attrs:(string * string) list ->
  'msg t list ->
  'msg t
(** A vertical layout container. *)

val button :
  ?style:Nopal_style.Style.t ->
  ?interaction:Nopal_style.Interaction.t ->
  ?attrs:(string * string) list ->
  ?on_click:'msg ->
  ?on_dblclick:'msg ->
  'msg t ->
  'msg t
(** A clickable button. The child element serves as the button label. *)

val input :
  ?style:Nopal_style.Style.t ->
  ?interaction:Nopal_style.Interaction.t ->
  ?attrs:(string * string) list ->
  ?placeholder:string ->
  ?on_change:(string -> 'msg) ->
  ?on_submit:'msg ->
  ?on_blur:'msg ->
  ?on_keydown:(string -> 'msg option) ->
  string ->
  'msg t
(** A text input. The positional argument is the current value. *)

val image :
  ?style:Nopal_style.Style.t -> src:string -> alt:string -> unit -> 'msg t
(** An image element. [src] and [alt] are required. *)

val scroll : ?style:Nopal_style.Style.t -> 'msg t -> 'msg t
(** A scrollable container wrapping a single child. *)

val keyed : string -> 'msg t -> 'msg t
(** [keyed key child] wraps [child] with a stable identity key for list
    reconciliation. *)

val draw :
  ?on_pointer_move:(pointer_event -> 'msg) ->
  ?on_click:(pointer_event -> 'msg) ->
  ?on_pointer_leave:'msg ->
  ?on_pointer_down:(pointer_event -> 'msg) ->
  ?on_pointer_up:(pointer_event -> 'msg) ->
  ?on_wheel:(wheel_event -> 'msg) ->
  ?cursor:Nopal_style.Cursor.t ->
  ?aria_label:string ->
  width:float ->
  height:float ->
  Nopal_scene.Scene.t list ->
  'msg t
(** [draw ~width ~height scene] creates a 2D drawing canvas element. The scene
    list describes shapes rendered onto the canvas. Optional pointer callbacks
    receive canvas-local coordinates. *)

(** {1 Transforms} *)

val map : ('a -> 'b) -> 'a t -> 'b t
(** [map f element] transforms all messages in [element] from type ['a] to type
    ['b]. Used for embedding child components with different message types. *)

(** {1 Responsive combinators} *)

val responsive :
  Viewport.t ->
  compact:'msg t ->
  ?medium:'msg t ->
  expanded:'msg t ->
  unit ->
  'msg t
(** [responsive vp ~compact ?medium ~expanded ()] selects a subtree based on
    [vp]'s size class. When [~medium] is omitted, Compact and Medium both use
    the [~compact] branch. *)

val responsive_style :
  Viewport.t ->
  compact:Nopal_style.Style.t ->
  ?medium:Nopal_style.Style.t ->
  expanded:Nopal_style.Style.t ->
  unit ->
  Nopal_style.Style.t
(** [responsive_style vp ~compact ?medium ~expanded ()] selects a style based on
    [vp]'s size class. Same fallback semantics as [responsive]. *)

(** {1 Comparison} *)

val equal : 'msg t -> 'msg t -> bool
(** [equal a b] tests structural equality of two element trees. Data fields
    (strings, styles, messages) are compared by structural equality. Function
    fields (event handlers like [on_change]) are compared by physical equality.
*)

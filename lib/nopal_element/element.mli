(** Pure UI description type.

    [Element.t] is the value that view functions return. It describes what
    should appear on screen without coupling to any rendering backend. The type
    is exposed (not abstract) so that renderers can exhaustively pattern-match
    on all constructors. *)

type 'msg t =
  | Empty
  | Text of string
  | Box of {
      style : Nopal_style.Style.t;
      interaction : Nopal_style.Interaction.t;
      attrs : (string * string) list;
      children : 'msg t list;
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

(** {1 Builders}

    Ergonomic constructors with labelled optional arguments. Application code
    should use these instead of raw variant constructors. *)

val empty : 'msg t
(** An element that renders nothing. *)

val text : string -> 'msg t
(** A text node. *)

val box :
  ?style:Nopal_style.Style.t ->
  ?interaction:Nopal_style.Interaction.t ->
  ?attrs:(string * string) list ->
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

(** {1 Transforms} *)

val map : ('a -> 'b) -> 'a t -> 'b t
(** [map f element] transforms all messages in [element] from type ['a] to type
    ['b]. Used for embedding child components with different message types. *)

(** {1 Comparison} *)

val equal : 'msg t -> 'msg t -> bool
(** [equal a b] tests structural equality of two element trees. Data fields
    (strings, styles, messages) are compared by structural equality. Function
    fields (event handlers like [on_change]) are compared by physical equality.
*)

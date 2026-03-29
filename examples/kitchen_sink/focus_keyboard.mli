(** Focus & Keyboard kitchen sink subapp.

    Demonstrates [Cmd.focus] for programmatic focus and [Sub.on_keydown_prevent]
    for selective preventDefault on keydown events. *)

type model = { last_key : string; trap_keys : bool }
(** The subapp model. [last_key] is the most recently trapped key string.
    [trap_keys] controls whether the keydown-prevent subscription is active. *)

type msg =
  | Focus_input
  | Toggle_trap of bool
  | Key_trapped of string  (** Messages for the focus & keyboard demo. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** Initial model and command. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** Update function. [Focus_input] produces [Cmd.focus "demo-input"].
    [Toggle_trap] toggles the keydown-prevent subscription. [Key_trapped]
    records the trapped key in the model. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** View function. Renders a column with a focus button, input, trap toggle
    checkbox, and a text display showing the last trapped key. *)

val subscriptions : model -> msg Nopal_mvu.Sub.t
(** Subscriptions. When [trap_keys] is true, subscribes to keydown with
    preventDefault for the Tab key. *)

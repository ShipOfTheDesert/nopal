(** Navigation bar kitchen sink subapp.

    Demonstrates [Navigation_bar] with three tabs (Home, Settings, About) and
    content switching on tab selection. *)

type tab = Home | Settings | About  (** The three demo tabs. *)

type model = { active_tab : tab }
(** The subapp model. [active_tab] tracks which tab is currently selected. *)

type msg =
  | SelectTab of string
      (** Messages for the navigation bar demo. [SelectTab id] switches the
          active tab. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** Initial model and command. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** Update function. [SelectTab id] sets the matching tab as active. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** View function. Renders a navigation bar with three tabs and a content area
    that changes based on the active tab. *)

val subscriptions : model -> msg Nopal_mvu.Sub.t
(** Subscriptions. Currently none. *)

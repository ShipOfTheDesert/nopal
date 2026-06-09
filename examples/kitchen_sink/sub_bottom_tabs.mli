(** Bottom-tabs kitchen sink subapp.

    Demonstrates {!Nopal_ui.Bottom_tabs} with two tabs ("home", "profile"), each
    owning an independent {!Nopal_navigation.Nav_stack.t} navigable two screens
    deep. Switching tabs preserves each tab's stack depth (REQ-F3): the per-tab
    stacks live side by side in the model and are never reset on selection. *)

type tab = Home | Profile  (** The two demo tabs. *)

type screen =
  | Home_root
  | Home_detail
  | Profile_root
  | Profile_detail
      (** Screens reachable in the demo. Each tab roots at its [_root] screen
          and can push to its [_detail] screen — two deep. *)

type model = {
  active : tab;  (** Currently selected tab. *)
  home : screen Nopal_navigation.Nav_stack.t;
      (** Home tab's navigation stack. *)
  profile : screen Nopal_navigation.Nav_stack.t;
      (** Profile tab's navigation stack. *)
}
(** The subapp model. Each tab's stack is held independently so a tab switch
    preserves the other tab's depth. *)

type msg =
  | Select of string  (** Select a tab by id (echoed from the tab bar). *)
  | Push of screen  (** Push a screen onto the active tab's stack. *)
  | Back  (** Pop the active tab's stack (no-op at its root). *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** Initial model: both tabs at their root, [Home] active. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** [Select id] switches the active tab; [Push]/[Back] mutate only the active
    tab's stack, leaving the other tab's stack untouched. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** Renders the bottom-tabs component for the active tab's current screen. *)

val subscriptions : model -> msg Nopal_mvu.Sub.t
(** Subscriptions. Currently none. *)

val serialize_model : model -> string
(** Telemetry serializer (ADR 0108). Emits each tab's stack depth terminated
    with a trailing [;] so substring assertions ([profile_depth=2;]) cannot
    prefix-alias a larger depth. *)

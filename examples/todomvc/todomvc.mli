(** TodoMVC example — full MVU application demonstrating list rendering, keyed
    updates, input handling, editing, filtering, routing, and persistence. *)

type todo = { id : int; title : string; completed : bool }
(** A single todo item. *)

(** Which subset of todos to display. *)
type filter = All | Active | Completed

type editing = { id : int; text : string; original : string; cancelled : bool }
(** Transient state while a todo title is being edited. [original] holds the
    pre-edit title so that [Cancel_edit] can restore it. [cancelled] prevents a
    subsequent [Submit_edit] from blur from saving the changed text. *)

(** Route values corresponding to URL hash fragments. *)
type route = All_route | Active_route | Completed_route

type model = {
  todos : todo list;
  filter : filter;
  input : string;
  editing : editing option;
  next_id : int;
  router : route Nopal_router.Router.t;
}
(** The full application model. *)

(** Messages that drive the MVU update loop. *)
type msg =
  | Input_changed of string
  | Add_todo
  | Toggle of int
  | Toggle_all
  | Delete of int
  | Start_editing of int
  | Edit_changed of string
  | Submit_edit
  | Cancel_edit
  | Clear_completed
  | Navigate_to of route
  | Route_changed of route

(** Platform storage abstraction — implemented in [main.ml]. *)
module type Storage = sig
  val load : unit -> todo list
  val save : todo list -> unit
end

val parse : string -> route option
(** [parse path] converts a URL path to a route, returning [None] for
    unrecognized paths. *)

val to_path : route -> string
(** [to_path route] converts a route to its URL path string. *)

val filter_of_route : route -> filter
(** [filter_of_route route] returns the display filter for a route. *)

val init :
  (module Storage) ->
  route Nopal_router.Router.t ->
  unit ->
  model * msg Nopal_mvu.Cmd.t
(** [init storage router ()] loads todos from storage, reads the current route,
    and returns the initial model. *)

val update : (module Storage) -> model -> msg -> model * msg Nopal_mvu.Cmd.t
(** [update storage model msg] applies a message to the model, persisting
    changes to storage when todos are mutated. *)

val view : model -> msg Nopal_element.Element.t
(** [view model] returns the element tree for the current model state. *)

val subscriptions : model -> msg Nopal_mvu.Sub.t
(** [subscriptions model] returns the active subscriptions (router navigation).
*)

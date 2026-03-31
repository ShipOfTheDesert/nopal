(** Data table kitchen sink subapp.

    Demonstrates [Data_table] with sortable and non-sortable columns, sort
    toggle behaviour, and keyed row rendering. *)

type person = { name : string; age : int; city : string }
(** Sample row type used by the demo. *)

type model = { data : person list; sort : Nopal_ui.Data_table.sort option }
(** The subapp model. [data] holds the current (possibly sorted) row list.
    [sort] tracks the active sort column and direction. *)

type msg =
  | Sort of string
      (** Messages for the data table demo. [Sort key] toggles sort on the given
          column key. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** Initial model and command. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** Update function. [Sort key] toggles ascending/descending on the same column,
    or resets to ascending on a new column. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** View function. Renders a three-column data table (Name, Age, City) with Name
    and Age sortable. *)

val subscriptions : model -> msg Nopal_mvu.Sub.t
(** Subscriptions. Currently none. *)

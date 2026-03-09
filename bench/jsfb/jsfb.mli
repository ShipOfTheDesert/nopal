(** js-framework-benchmark Nopal application.

    Implements the standard jsfb table with all 9 operations for benchmarking
    the Nopal MVU loop and rendering pipeline. *)

type row = { id : int; label : string }
(** A single table row with a unique ID and a randomly generated label. *)

type model = {
  rows : row list;
  selected : int option;  (** Currently selected row ID, if any. *)
  next_id : int;
}
(** The benchmark application state. *)

type msg =
  | Create_1000
  | Replace_1000
  | Append_1000
  | Update_every_10th
  | Select of int
  | Remove of int
  | Swap_rows
  | Clear
  | Create_10000  (** The 9 jsfb benchmark operations. *)

include Nopal_mvu.App.S with type model := model and type msg := msg

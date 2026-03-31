open Nopal_element
open Nopal_style

let total_items = 10_000

let row_height =
  (* These literals are compile-time constants known to be valid;
     Option.get is safe here. *)
  Option.get (Virtual_list.Positive_float.of_float 40.0)

let container_height = Option.get (Virtual_list.Positive_float.of_float 600.0)
let nat_item_count = Option.get (Virtual_list.Natural.of_int total_items)
let overscan = Option.get (Virtual_list.Natural.of_int 5)

type model = { scroll_offset : float }
type msg = Scrolled of float

let init () = ({ scroll_offset = 0.0 }, Nopal_mvu.Cmd.none)

let update _model msg =
  match msg with
  | Scrolled offset -> ({ scroll_offset = offset }, Nopal_mvu.Cmd.none)

let subscriptions _model = Nopal_mvu.Sub.none

let row_style =
  Style.default
  |> Style.with_layout (fun l -> l |> Style.padding 8.0 12.0 8.0 12.0)

let view _vp model =
  let scroll_state = Virtual_list.scroll_state ~offset:model.scroll_offset in
  Element.virtual_list
    ~on_scroll:(fun offset -> Scrolled offset)
    ~item_count:nat_item_count ~row_height ~container_height ~scroll_state
    ~overscan
    (fun i ->
      Element.box ~style:row_style
        ~attrs:[ ("data-bench-row", string_of_int i) ]
        [ Element.text (Printf.sprintf "Row %d — benchmark content" i) ])

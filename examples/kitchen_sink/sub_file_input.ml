open Nopal_element

type model = { selection : Element.file_info list }
type msg = Selected of Element.file_info list

let init () = ({ selection = [] }, Nopal_mvu.Cmd.none)
let update _model (Selected selection) = ({ selection }, Nopal_mvu.Cmd.none)
let subscriptions _model = Nopal_mvu.Sub.none

(* The picker has no label of its own to slugify, so the accessible name and the
   test anchor are both supplied here at the call site. *)
let picker_label = "Receipt image"
let picker_field = "receipt-image"

let describe (f : Element.file_info) =
  Printf.sprintf "%s | %s | %d bytes" f.name f.mime f.size

let view _vp model =
  let readout =
    match model.selection with
    | [] -> [ Element.text "No file selected" ]
    | files -> List.map (fun f -> Element.text (describe f)) files
  in
  Element.column
    [
      Element.text picker_label;
      Element.file_input
        ~attrs:[ ("data-field", picker_field); ("aria-label", picker_label) ]
        ~accept:[ "image/*" ] ~capture:Element.Environment ~multiple:false
        ~on_change:(fun files -> Selected files)
        ();
      Element.column ~attrs:[ ("data-testid", "file-input-selection") ] readout;
    ]

(* The blob handle is deliberately absent: it is issued fresh on every selection
   and means nothing outside the page session, so asserting on it would pin a
   value no test can predict. Every field is terminated with ';' so a substring
   assertion is bounded on both sides. *)
let serialize_file (f : Element.file_info) =
  Printf.sprintf "file_name=%S; file_mime=%S; file_size=%d;" f.name f.mime
    f.size

let serialize_model model =
  String.concat " "
    (Printf.sprintf "file_count=%d;" (List.length model.selection)
    :: List.map serialize_file model.selection)

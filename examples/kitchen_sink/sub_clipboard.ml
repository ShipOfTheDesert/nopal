open Nopal_element
open Nopal_style

type status = Idle | Copied | Copy_failed of Nopal_mvu.Clipboard.error
type model = { key : string; status : status }

type msg =
  | Copy_clicked
  | Copy_result of (unit, Nopal_mvu.Clipboard.error) result

let init () = ({ key = "nopal-test-key-7Q2"; status = Idle }, Nopal_mvu.Cmd.none)

let update model msg =
  match msg with
  | Copy_clicked ->
      ( model,
        Nopal_mvu.Cmd.write_clipboard model.key ~on_result:(fun result ->
            Copy_result result) )
  | Copy_result (Ok ()) -> ({ model with status = Copied }, Nopal_mvu.Cmd.none)
  | Copy_result (Error error) ->
      ({ model with status = Copy_failed error }, Nopal_mvu.Cmd.none)

let status_token status =
  match status with
  | Idle -> "idle"
  | Copied -> "copied"
  | Copy_failed Nopal_mvu.Clipboard.Not_permitted -> "not-permitted"
  | Copy_failed Nopal_mvu.Clipboard.Unavailable -> "unavailable"
  | Copy_failed (Nopal_mvu.Clipboard.Failed _) -> "failed"

let status_text status =
  match status with
  | Idle -> "Not copied yet"
  | Copied -> "Copied to the clipboard"
  | Copy_failed Nopal_mvu.Clipboard.Not_permitted ->
      "Not copied: the platform refused the write"
  | Copy_failed Nopal_mvu.Clipboard.Unavailable ->
      "Not copied: no clipboard is available here"
  | Copy_failed (Nopal_mvu.Clipboard.Failed reason) -> "Not copied: " ^ reason

(* Layout fields are all options, so starting from the default layout inherits
   no opinion about anything but the fields named here. *)
let column_style =
  Style.default |> Style.with_layout (fun l -> { l with gap = Some 8.0 })

let row_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = Some 8.0; cross_align = Some Center })

let view _vp model =
  Element.column ~style:column_style
    [
      Element.text
        "A fake API key, shown once. Copy places it on the system clipboard; \
         the status below reports whether that worked.";
      Element.row ~style:row_style
        [
          Element.box
            ~attrs:[ ("data-testid", "clipboard-key") ]
            [ Element.text model.key ];
          Element.button
            ~attrs:[ ("data-testid", "clipboard-copy") ]
            ~on_click:Copy_clicked (Element.text "Copy");
        ];
      Element.box
        ~attrs:
          [
            ("data-testid", "clipboard-status");
            ("data-status", status_token model.status);
            ("role", "status");
          ]
        [ Element.text (status_text model.status) ];
    ]

let serialize_msg msg =
  match msg with
  | Copy_clicked -> "Clipboard:Copy_clicked;"
  | Copy_result (Ok ()) -> "Clipboard:Copy_result:Ok;"
  | Copy_result (Error Nopal_mvu.Clipboard.Not_permitted) ->
      "Clipboard:Copy_result:Error Not_permitted;"
  | Copy_result (Error Nopal_mvu.Clipboard.Unavailable) ->
      "Clipboard:Copy_result:Error Unavailable;"
  | Copy_result (Error (Nopal_mvu.Clipboard.Failed reason)) ->
      Printf.sprintf "Clipboard:Copy_result:Error Failed %S;" reason

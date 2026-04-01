module E = Nopal_element.Element
module Sub = Nopal_mvu.Sub

type 'msg config = {
  open_ : bool;
  title_id : string;
  on_close : 'msg;
  body : 'msg E.t;
  on_backdrop_click : 'msg option;
  style : Nopal_style.Style.t option;
  backdrop_style : Nopal_style.Style.t option;
  interaction : Nopal_style.Interaction.t option;
  attrs : (string * string) list;
}

let make ~open_ ~title_id ~on_close ~body =
  {
    open_;
    title_id;
    on_close;
    body;
    on_backdrop_click = None;
    style = None;
    backdrop_style = None;
    interaction = None;
    attrs = [];
  }

let with_on_backdrop_click msg config =
  { config with on_backdrop_click = Some msg }

let with_style style config = { config with style = Some style }

let with_backdrop_style style config =
  { config with backdrop_style = Some style }

let with_interaction interaction config =
  { config with interaction = Some interaction }

let with_attrs attrs config = { config with attrs }

let view config =
  if not config.open_ then E.empty
  else
    let aria_attrs =
      [
        ("role", "dialog");
        ("aria-modal", "true");
        ("aria-labelledby", config.title_id);
        ("data-testid", "modal-dialog");
      ]
    in
    let dialog_attrs = aria_attrs @ config.attrs in
    let dialog =
      match (config.style, config.interaction) with
      | Some s, Some i ->
          E.column ~style:s ~interaction:i ~attrs:dialog_attrs [ config.body ]
      | Some s, None -> E.column ~style:s ~attrs:dialog_attrs [ config.body ]
      | None, Some i ->
          E.column ~interaction:i ~attrs:dialog_attrs [ config.body ]
      | None, None -> E.column ~attrs:dialog_attrs [ config.body ]
    in
    let children =
      match config.on_backdrop_click with
      | Some msg ->
          let backdrop_attrs = [ ("data-testid", "modal-backdrop") ] in
          let backdrop =
            match config.backdrop_style with
            | Some s ->
                E.box ~style:s ~attrs:backdrop_attrs
                  ~on_pointer_down:(fun _pe -> msg)
                  []
            | None ->
                E.box ~attrs:backdrop_attrs ~on_pointer_down:(fun _pe -> msg) []
          in
          [ backdrop; dialog ]
      | None -> [ dialog ]
    in
    E.box ~attrs:[ ("data-testid", "modal-root") ] children

let subscriptions config =
  if not config.open_ then Sub.none
  else
    Sub.on_keydown_prevent "modal-escape" (fun key ->
        match key with
        | "Escape" -> Some (config.on_close, true)
        | _ -> None)

let rec safe_nth n = function
  | [] -> None
  | x :: rest -> if n = 0 then Some x else safe_nth (n - 1) rest

let next_focus ~focusable_ids ~current ~key =
  let rec find_index i = function
    | [] -> None
    | x :: rest ->
        if String.equal x current then Some i else find_index (i + 1) rest
  in
  match (focusable_ids, key) with
  | [], _ -> None
  | _, "Tab" -> (
      match find_index 0 focusable_ids with
      | None -> None
      | Some idx ->
          let len = List.length focusable_ids in
          let next_idx = (idx + 1) mod len in
          safe_nth next_idx focusable_ids)
  | _, "Shift+Tab" -> (
      match find_index 0 focusable_ids with
      | None -> None
      | Some idx ->
          let len = List.length focusable_ids in
          let prev_idx = (idx - 1 + len) mod len in
          safe_nth prev_idx focusable_ids)
  | _, _ -> None

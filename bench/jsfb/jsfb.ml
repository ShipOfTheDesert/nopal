module E = Nopal_element.Element

type row = { id : int; label : string }
type model = { rows : row list; selected : int option; next_id : int }

type msg =
  | Create_1000
  | Replace_1000
  | Append_1000
  | Update_every_10th
  | Select of int
  | Remove of int
  | Swap_rows
  | Clear
  | Create_10000

let adjectives =
  [|
    "pretty";
    "large";
    "big";
    "small";
    "tall";
    "short";
    "long";
    "handsome";
    "plain";
    "quaint";
    "clean";
    "elegant";
    "easy";
    "angry";
    "crazy";
    "helpful";
    "mushy";
    "odd";
    "unsightly";
    "adorable";
    "important";
    "inexpensive";
    "cheap";
    "expensive";
    "fancy";
  |]

let colors =
  [|
    "red";
    "yellow";
    "blue";
    "green";
    "pink";
    "brown";
    "purple";
    "brown";
    "white";
    "black";
    "orange";
  |]

let nouns =
  [|
    "table";
    "chair";
    "house";
    "bbq";
    "desk";
    "car";
    "pony";
    "cookie";
    "sandwich";
    "burger";
    "pizza";
    "mouse";
    "keyboard";
  |]

let random_label () =
  let adj = adjectives.(Random.int (Array.length adjectives)) in
  let col = colors.(Random.int (Array.length colors)) in
  let noun = nouns.(Random.int (Array.length nouns)) in
  adj ^ " " ^ col ^ " " ^ noun

let create_rows n next_id =
  let rec go acc i remaining =
    match remaining with
    | 0 -> (List.rev acc, i)
    | n ->
        let r = { id = i; label = random_label () } in
        go (r :: acc) (i + 1) (n - 1)
  in
  go [] next_id n

let init () = ({ rows = []; selected = None; next_id = 1 }, Nopal_mvu.Cmd.none)

let update model msg =
  match msg with
  | Create_1000 ->
      let rows, next_id = create_rows 1000 model.next_id in
      ({ rows; selected = model.selected; next_id }, Nopal_mvu.Cmd.none)
  | Create_10000 ->
      let rows, next_id = create_rows 10000 model.next_id in
      ({ rows; selected = model.selected; next_id }, Nopal_mvu.Cmd.none)
  | Replace_1000 ->
      let rows, next_id = create_rows 1000 model.next_id in
      ({ rows; selected = model.selected; next_id }, Nopal_mvu.Cmd.none)
  | Append_1000 ->
      let new_rows, next_id = create_rows 1000 model.next_id in
      (* @ is O(n) in left-list length — acceptable here since append is a
         single benchmarked operation, not inside a fold accumulator *)
      let rows = model.rows @ new_rows in
      ({ rows; selected = model.selected; next_id }, Nopal_mvu.Cmd.none)
  | Update_every_10th ->
      let rows =
        List.mapi
          (fun i (r : row) ->
            if i mod 10 = 0 then { r with label = r.label ^ " !!!" } else r)
          model.rows
      in
      ({ model with rows }, Nopal_mvu.Cmd.none)
  | Select id -> ({ model with selected = Some id }, Nopal_mvu.Cmd.none)
  | Remove id ->
      let rows = List.filter (fun (r : row) -> r.id <> id) model.rows in
      ({ model with rows }, Nopal_mvu.Cmd.none)
  | Swap_rows ->
      (* Array swap: O(1) indexed mutation on ephemeral local copy;
         pure list equivalent would require O(n) indexed access *)
      let arr = Array.of_list model.rows in
      if Array.length arr > 998 then begin
        let tmp = arr.(1) in
        arr.(1) <- arr.(998);
        arr.(998) <- tmp;
        ({ model with rows = Array.to_list arr }, Nopal_mvu.Cmd.none)
      end
      else (model, Nopal_mvu.Cmd.none)
  | Clear -> ({ model with rows = [] }, Nopal_mvu.Cmd.none)

let view_row selected (r : row) =
  let is_selected =
    match selected with
    | Some id -> id = r.id
    | None -> false
  in
  E.keyed (string_of_int r.id)
    (E.row
       ~attrs:(if is_selected then [ ("data-selected", "true") ] else [])
       [
         E.text (string_of_int r.id);
         E.button ~on_click:(Select r.id) (E.text r.label);
         E.button ~on_click:(Remove r.id) (E.text "x");
       ])

let view _vp model =
  E.column
    [
      E.box
        ~attrs:[ ("data-section", "toolbar") ]
        [
          E.button
            ~attrs:[ ("id", "run") ]
            ~on_click:Create_1000
            (E.text "Create 1,000 rows");
          E.button
            ~attrs:[ ("id", "runlots") ]
            ~on_click:Create_10000
            (E.text "Create 10,000 rows");
          E.button
            ~attrs:[ ("id", "add") ]
            ~on_click:Append_1000
            (E.text "Append 1,000 rows");
          E.button
            ~attrs:[ ("id", "update") ]
            ~on_click:Update_every_10th
            (E.text "Update every 10th row");
          E.button ~attrs:[ ("id", "clear") ] ~on_click:Clear (E.text "Clear");
          E.button
            ~attrs:[ ("id", "swaprows") ]
            ~on_click:Swap_rows (E.text "Swap Rows");
        ];
      E.column
        ~attrs:[ ("id", "tbody") ]
        (List.map (view_row model.selected) model.rows);
    ]

let subscriptions _model = Nopal_mvu.Sub.none

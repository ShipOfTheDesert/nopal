module E = Nopal_element.Element

type route = Home | About | Item of int | NotFound

let parse = function
  | "/" -> Some Home
  | "/about" -> Some About
  | path -> (
      match String.split_on_char '/' path with
      | [ ""; "items"; id ] -> (
          match int_of_string_opt id with
          | Some n -> Some (Item n)
          | None -> None)
      | _ -> None)

let to_path = function
  | Home -> "/"
  | About -> "/about"
  | Item id -> "/items/" ^ string_of_int id
  | NotFound -> "/not-found"

type model = { current_route : route; router : route Nopal_router.Router.t }
type msg = Navigate_to of route | Route_changed of route

let init router () =
  ( { current_route = Nopal_router.Router.current router; router },
    Nopal_mvu.Cmd.none )

let update model = function
  | Navigate_to route ->
      ( { model with current_route = route },
        Nopal_router.Router.push model.router route )
  | Route_changed route ->
      ({ model with current_route = route }, Nopal_mvu.Cmd.none)

let view_for_route = function
  | Home ->
      E.column
        [
          E.text "Home Page";
          E.button ~on_click:(Navigate_to About) (E.text "Go to About");
          E.button ~on_click:(Navigate_to (Item 1)) (E.text "Go to Item 1");
        ]
  | About ->
      E.column
        [
          E.text "About Page";
          E.button ~on_click:(Navigate_to Home) (E.text "Go Home");
        ]
  | Item id ->
      E.column
        [
          E.text ("Item " ^ string_of_int id);
          E.button ~on_click:(Navigate_to Home) (E.text "Go Home");
        ]
  | NotFound ->
      E.column
        [
          E.text "Page Not Found";
          E.button ~on_click:(Navigate_to Home) (E.text "Go Home");
        ]

let view model =
  E.column
    [
      E.text "Routing Demo";
      E.row
        [
          E.button ~on_click:(Navigate_to Home) (E.text "Home");
          E.button ~on_click:(Navigate_to About) (E.text "About");
          E.button ~on_click:(Navigate_to (Item 42)) (E.text "Item 42");
        ];
      view_for_route model.current_route;
    ]

let subscriptions model =
  Nopal_router.Router.on_navigate model.router (fun route ->
      Route_changed route)

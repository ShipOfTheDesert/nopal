open Nopal_element
open Nopal_style

type route = Start | Target

let route_to_path route =
  match route with
  | Start -> "/kitchen_sink/"
  | Target -> "/kitchen_sink/?links=target"

let route_of_path path =
  match path with
  | "/kitchen_sink/" -> Some Start
  | _ -> None

let router platform =
  Nopal_platform.Router.create ~platform ~parse:route_of_path
    ~to_path:route_to_path ~not_found:Start

type model = { route : route; open_failure : Link.open_error option }
type msg = Followed of route | Open_failed of Link.open_error

let external_url = "https://ocaml.org/"

(* The kitchen sink's own page again, so the tab the link opens loads; the
   query only tells the two addresses apart. *)
let new_tab_path = "/kitchen_sink/?links=new-tab"
let init () = ({ route = Start; open_failure = None }, Nopal_mvu.Cmd.none)

let update router model msg =
  match msg with
  | Followed route ->
      ({ model with route }, Nopal_platform.Router.push router route)
  | Open_failed error ->
      ({ model with open_failure = Some error }, Nopal_mvu.Cmd.none)

let route_token route =
  match route with
  | Start -> "start"
  | Target -> "target"

let route_text route =
  match route with
  | Start -> "Route: the start route"
  | Target -> "Route: the target route, followed in-app"

let status_token open_failure =
  match open_failure with
  | None -> "idle"
  | Some Link.Not_permitted -> "not-permitted"
  | Some (Link.Failed _) -> "failed"

let status_text open_failure =
  match open_failure with
  | None -> "No external link has failed to open"
  | Some Link.Not_permitted ->
      "Not opened: the platform refused to open the link"
  | Some (Link.Failed reason) -> "Not opened: " ^ reason

(* [link] names the link that is missing, as in "route link". *)
let path_error_text ~link error =
  match error with
  | Route_path.Not_absolute _ -> "No " ^ link ^ ": its path is not rooted"
  | Route_path.Protocol_relative _ ->
      "No " ^ link ^ ": its path would leave for another host"
  | Route_path.Control_character _ ->
      "No " ^ link ^ ": its path has a control character or surrounding space"

let url_error_text error =
  match error with
  | Url.Missing_scheme _ -> "No external link: its URL has no scheme"
  | Url.Unsupported_scheme _ ->
      "No external link: its URL's scheme is not allowed"
  | Url.Control_character _ ->
      "No external link: its URL has a control character or surrounding space"

(* Layout fields are all options, so starting from the default layout inherits
   no opinion about anything but the fields named here. *)
let column_style =
  Style.default |> Style.with_layout (fun l -> { l with gap = Some 8.0 })

let link_interaction =
  {
    Interaction.hover =
      Some
        (Style.default
        |> Style.with_text (fun t -> t |> Text.text_decoration Text.Underline));
    pressed = None;
    focused = None;
  }

let offset_link_interaction =
  {
    Interaction.hover =
      Some
        (Style.default
        |> Style.with_text (fun t ->
            t
            |> Text.text_decoration Text.Underline
            |> Text.underline_offset 3.0));
    pressed = None;
    focused = None;
  }

let error_line testid text =
  Element.box
    ~attrs:[ ("data-testid", testid); ("role", "alert") ]
    [ Element.text text ]

let route_link router =
  match
    Nopal_platform.Router.destination router Target ~on_follow:(fun route ->
        Followed route)
  with
  | Ok destination ->
      Element.link ~interaction:offset_link_interaction
        ~attrs:[ ("data-testid", "links-route-link") ]
        destination
        (Element.text "Follow an in-app link")
  | Error error ->
      error_line "links-route-error" (path_error_text ~link:"route link" error)

let external_link () =
  match Url.of_string external_url with
  | Ok url ->
      Element.link ~interaction:link_interaction
        ~attrs:[ ("data-testid", "links-external-link") ]
        (Link.External
           { url; on_open_failed = (fun error -> Open_failed error) })
        (Element.text "OCaml's website")
  | Error error -> error_line "links-external-error" (url_error_text error)

let new_tab_link () =
  match Route_path.of_string new_tab_path with
  | Ok path ->
      Element.link ~interaction:link_interaction
        ~attrs:[ ("data-testid", "links-new-tab-link") ]
        (Link.New_tab { path })
        (Element.text "Open this page in a new tab")
  | Error error ->
      error_line "links-new-tab-error"
        (path_error_text ~link:"new-tab link" error)

let view router _vp model =
  Element.column ~style:column_style
    [
      Element.text
        "A link to a route of this page, followed without loading it, a link \
         to another site, and a link that opens this page in a new tab. Hover \
         one to underline it: the in-app link's underline sits 3px below the \
         text, the others' where the browser puts it.";
      route_link router;
      external_link ();
      new_tab_link ();
      Element.box
        ~attrs:
          [
            ("data-testid", "links-current-route");
            ("data-route", route_token model.route);
            ("role", "status");
          ]
        [ Element.text (route_text model.route) ];
      Element.box
        ~attrs:
          [
            ("data-testid", "links-open-status");
            ("data-status", status_token model.open_failure);
            ("role", "status");
          ]
        [ Element.text (status_text model.open_failure) ];
    ]

let serialize_msg msg =
  match msg with
  | Followed Start -> "Links:Followed:Start;"
  | Followed Target -> "Links:Followed:Target;"
  | Open_failed Link.Not_permitted -> "Links:Open_failed:Not_permitted;"
  | Open_failed (Link.Failed reason) ->
      Printf.sprintf "Links:Open_failed:Failed %S;" reason

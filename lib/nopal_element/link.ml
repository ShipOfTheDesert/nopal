type open_error = Not_permitted | Failed of string

type 'msg destination =
  | Route of { path : Route_path.t; on_follow : 'msg }
  | External of { url : Url.t; on_open_failed : open_error -> 'msg }
  | New_tab of { path : Route_path.t }

type button = Primary | Middle | Other

type click = {
  button : button;
  ctrl : bool;
  meta : bool;
  shift : bool;
  alt : bool;
}

type host = Browser | Webview

type 'msg action =
  | Navigate of 'msg
  | Leave_to_platform
  | Open_externally of { url : Url.t; on_open_failed : open_error -> 'msg }

let button_of_index = function
  | 0 -> Primary
  | 1 -> Middle
  | _ -> Other

let is_modified { button = _; ctrl; meta; shift; alt } =
  ctrl || meta || shift || alt

let in_browser click destination =
  match (destination, click.button) with
  | Route { path = _; on_follow }, Primary -> (
      match is_modified click with
      | false -> Navigate on_follow
      | true -> Leave_to_platform)
  | Route _, (Middle | Other)
  | External _, (Primary | Middle | Other)
  | New_tab _, (Primary | Middle | Other) ->
      Leave_to_platform

let in_webview click destination =
  match (click.button, destination) with
  | (Primary | Middle), Route { path = _; on_follow } -> Navigate on_follow
  | (Primary | Middle), External { url; on_open_failed } ->
      Open_externally { url; on_open_failed }
  | (Primary | Middle | Other), New_tab _
  | Other, (Route _ | External _) ->
      Leave_to_platform

let decide ~host click destination =
  match host with
  | Browser -> in_browser click destination
  | Webview -> in_webview click destination

let map_destination f = function
  | Route { path; on_follow } -> Route { path; on_follow = f on_follow }
  | External { url; on_open_failed } ->
      External { url; on_open_failed = (fun error -> f (on_open_failed error)) }
  | New_tab { path } -> New_tab { path }

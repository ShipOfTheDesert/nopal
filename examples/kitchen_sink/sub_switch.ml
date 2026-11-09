open Nopal_element
open Nopal_style
open Nopal_ui

type route = Start | Dropped_alerts

let route_to_path route =
  match route with
  | Start -> "/kitchen_sink/"
  | Dropped_alerts -> "/kitchen_sink/?switch=dropped-alerts"

let route_of_path path =
  match path with
  | "/kitchen_sink/" -> Some Start
  | _ -> None

let router platform =
  Nopal_platform.Router.create ~platform ~parse:route_of_path
    ~to_path:route_to_path ~not_found:Start

type model = { starts_on : bool; starts_off : bool; disabled : bool }

type msg =
  | Starts_on_toggled of bool
  | Starts_off_toggled of bool
  | Disabled_toggled of bool
  | Dropped_alerts_followed

let init () =
  ( { starts_on = true; starts_off = false; disabled = false },
    Nopal_mvu.Cmd.none )

let update router model msg =
  match msg with
  | Starts_on_toggled on -> ({ model with starts_on = on }, Nopal_mvu.Cmd.none)
  | Starts_off_toggled on -> ({ model with starts_off = on }, Nopal_mvu.Cmd.none)
  | Disabled_toggled on -> ({ model with disabled = on }, Nopal_mvu.Cmd.none)
  | Dropped_alerts_followed ->
      (model, Nopal_platform.Router.push router Dropped_alerts)

let label = "Send an alert when it goes silent"
let note_color = Style.hex "#5C5346"
let ring_color = Style.rgba 11 97 88 0.5

(* Every paint field is written out, so no style inherits a look it did not ask
   for. *)
let paint ?border ?shadow () =
  { Style.background = None; border; opacity = 1.0; shadow; overflow = Visible }

let note_style =
  {
    Style.layout = Style.default_layout;
    paint = paint ();
    text = Text.default |> Text.color note_color |> Text.font_size 14.0;
  }

(* Zero offset and zero blur make the shadow read as a ring; the spread alone
   gives it its width. The button has no corners of its own, so the ring carries
   the track's radius. *)
let focus_ring =
  {
    Interaction.hover = None;
    pressed = None;
    focused =
      Some
        {
          Style.layout = Style.default_layout;
          paint =
            paint
              ~border:
                {
                  Style.width = 0.0;
                  style = No_border;
                  color = Style.transparent;
                  radius = 12.0;
                  corners = None;
                }
              ~shadow:
                {
                  x = 0.0;
                  y = 0.0;
                  blur = 0.0;
                  spread = 3.0;
                  color = ring_color;
                }
              ();
          text = Style.default_text;
        };
    focused_within = None;
  }

let row_style =
  {
    Style.layout =
      {
        Style.default_layout with
        direction = Some Row_dir;
        cross_align = Some Center;
        gap = Some 4.0;
      };
    paint = paint ();
    text = Style.default_text;
  }

let dropped_alerts_link router =
  match
    Nopal_platform.Router.destination router Dropped_alerts
      ~on_follow:(fun (_ : route) -> Dropped_alerts_followed)
  with
  | Ok destination ->
      Element.link
        ~attrs:[ ("data-testid", "switch-dropped-alerts-link") ]
        destination
        (Element.text "See the dropped alerts")
  | Error (_ : Route_path.error) ->
      Element.box
        ~attrs:
          [ ("data-testid", "switch-dropped-alerts-error"); ("role", "alert") ]
        [ Element.text "No dropped-alerts link: its address was refused" ]

let dropped_alerts_hint router =
  Element.row ~style:row_style
    [
      Element.text "Off, so alerts are being dropped.";
      dropped_alerts_link router;
    ]

let switch ~id ~on ~on_toggle =
  Switch.make ~label ~on ~on_toggle
  |> Switch.with_id id
  |> Switch.with_focus_ring focus_ring
  |> Switch.with_hint_style note_style
  |> Switch.with_reason_style note_style
  |> Switch.with_attrs [ ("data-testid", id ^ "-row") ]

let do_nothing_button ~testid text =
  Element.button ~attrs:[ ("data-testid", testid) ] (Element.text text)

let view router model =
  Element.column
    ~style:
      {
        Style.layout =
          {
            Style.default_layout with
            cross_align = Some Start;
            gap = Some 16.0;
          };
        paint = paint ();
        text = Style.default_text;
      }
    [
      do_nothing_button ~testid:"switch-before" "Before the switches";
      switch ~id:"switch-starts-on" ~on:model.starts_on ~on_toggle:(fun on ->
          Starts_on_toggled on)
      |> Switch.with_hint (Element.text "Delivering to alerts.example.com")
      |> Switch.view;
      switch ~id:"switch-starts-off" ~on:model.starts_off ~on_toggle:(fun on ->
          Starts_off_toggled on)
      |> Switch.view;
      switch ~id:"switch-disabled" ~on:model.disabled ~on_toggle:(fun on ->
          Disabled_toggled on)
      |> Switch.with_availability
           (Switch.Disabled { reason = "Needs a silence threshold." })
      |> Switch.with_hint (dropped_alerts_hint router)
      |> Switch.view;
      do_nothing_button ~testid:"switch-after" "After the switches";
    ]

let serialize_msg msg =
  match msg with
  | Starts_on_toggled on -> Printf.sprintf "Switch:Starts_on_toggled:%b;" on
  | Starts_off_toggled on -> Printf.sprintf "Switch:Starts_off_toggled:%b;" on
  | Disabled_toggled on -> Printf.sprintf "Switch:Disabled_toggled:%b;" on
  | Dropped_alerts_followed -> "Switch:Dropped_alerts_followed;"

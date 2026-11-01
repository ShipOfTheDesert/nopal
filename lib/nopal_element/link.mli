(** Where a link goes, and what a click on it does — the link contract, written
    once.

    Everything here is pure and compiles on native OCaml. Every renderer answers
    a click on a link by calling {!decide} and carrying out the action it
    returns, so which clicks are intercepted, dispatched or opened is decided
    here and nowhere else: a renderer that resolved it independently could drift
    from the other renderers and from this definition.

    The rule depends on the host the link is rendered in.

    {b In a browser}, only an unmodified primary click on a {!Route} link is
    taken over: the default is prevented and the link's [on_follow] message is
    dispatched, so in-app navigation runs through the application's [update].
    Every other click is left to the browser and dispatches nothing — a modified
    (Ctrl, Meta, Shift or Alt) click, a middle click, a click with any other
    button, and every click on an {!External} or a {!New_tab} link — so the user
    gets a new tab, window or page as the browser decides.

    {b In a webview}, a primary or middle click is always taken over, whatever
    modifiers are held: on a {!Route} link it dispatches [on_follow], and on an
    {!External} link it hands the URL to the host's opener, which shows it in
    the system browser while the webview stays where it is. A webview has no
    tabs, so a modified click on a {!Route} link is a plain click. A click with
    any other button is left to the platform, and so is every click on a
    {!New_tab} link: the link carries no message to dispatch and no URL an
    opener could show, so what the webview does with its [target="_blank"] is
    the platform's, and no test here holds it.

    Keyboard activation (Enter on a focused link) reaches {!decide} as an
    unmodified primary click. *)

(** Why the host's opener could not show an external URL. *)
type open_error =
  | Not_permitted
      (** The host refused to open the URL: it grants no permission to open one,
          or none for this URL. *)
  | Failed of string
      (** The opener was permitted and failed. The string is a human-readable
          reason. The URL as given is replaced in it; a normalised form a
          launcher echoes may remain. *)

(** Where a link goes. *)
type 'msg destination =
  | Route of { path : Route_path.t; on_follow : 'msg }
      (** An in-app destination. [path] is the link's address; [on_follow] is
          dispatched when the link is followed in-app, and the application's
          [update] answers it by navigating to [path]. *)
  | External of { url : Url.t; on_open_failed : open_error -> 'msg }
      (** A destination outside the app. [on_open_failed] is dispatched with the
          reason when a host's opener cannot show [url]. A browser follows an
          external link itself, so it never dispatches [on_open_failed]. *)
  | New_tab of { path : Route_path.t }
      (** A path on the page's own origin, opened in a new tab: a photo, a file
          or a page the server serves beside the app, which a [Route] link would
          take over and navigate to in place. Rendered with ["target"]
          ["_blank"] and ["rel"] ["noopener noreferrer"], and never taken over:
          {!decide} leaves every click on it to the platform, on either host.
          [path] is a {!Route_path.t}, so it starts with a single [/] and cannot
          name another host. *)

(** The mouse button a click was made with. *)
type button =
  | Primary  (** The main button, usually the left one. *)
  | Middle  (** The auxiliary button, usually the wheel. *)
  | Other  (** Any other button, such as back or forward. *)

type click = {
  button : button;  (** The button the click was made with. *)
  ctrl : bool;  (** Whether Ctrl was held. *)
  meta : bool;  (** Whether Meta (Command, Windows) was held. *)
  shift : bool;  (** Whether Shift was held. *)
  alt : bool;  (** Whether Alt (Option) was held. *)
}
(** A click on a link, as the platform reported it. *)

(** Where the link is rendered. *)
type host =
  | Browser  (** A web browser, which has tabs, windows and its own links. *)
  | Webview
      (** An application webview, which has no tabs; a click on an external link
          must not navigate it away from the app. *)

(** What the renderer does with a click. *)
type 'msg action =
  | Navigate of 'msg
      (** Prevent the platform default and dispatch the message, once. *)
  | Leave_to_platform
      (** Neither prevent the platform default nor dispatch anything. *)
  | Open_externally of { url : Url.t; on_open_failed : open_error -> 'msg }
      (** Prevent the platform default and hand [url] to the host's opener. When
          the opener fails, the renderer dispatches [on_open_failed] with the
          reason. *)

val button_of_index : int -> button
(** [button_of_index n] is the button a platform reports as button number [n]: 0
    is {!Primary}, 1 is {!Middle}, and every other number is {!Other}. Total. *)

val decide : host:host -> click -> 'msg destination -> 'msg action
(** [decide ~host click destination] is what the renderer does with [click] on a
    link to [destination] rendered in [host], by the rule in this module's
    header. Total: every combination answers an action and none raises. *)

val map_destination : ('a -> 'b) -> 'a destination -> 'b destination
(** [map_destination f destination] is [destination] with [f] applied to every
    message it can produce: [on_follow], and the result of [on_open_failed]. The
    path or URL is unchanged. *)

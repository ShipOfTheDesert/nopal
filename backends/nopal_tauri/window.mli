(** Typed OCaml bindings to the Tauri Window API.

    Provides window management functions via the Tauri JavaScript API. Each
    function returns a {!Nopal_mvu.Task.t} that resolves with [Ok _] when the
    Tauri promise completes, or [Error msg] if the IPC rejects (REQ-F5). A
    failed op resolves [Error] rather than hanging, so a [let*] chain over these
    ops never silently stalls. *)

type size = { width : int; height : int }
(** Logical pixel dimensions of a window. *)

val set_title : string -> (unit, string) result Nopal_mvu.Task.t
(** [set_title title] sets the window title bar text to [title]. *)

val set_fullscreen : bool -> (unit, string) result Nopal_mvu.Task.t
(** [set_fullscreen flag] enters fullscreen when [flag] is [true], exits when
    [false]. *)

val is_fullscreen : (bool, string) result Nopal_mvu.Task.t
(** [is_fullscreen] queries fullscreen state. *)

val minimize : (unit, string) result Nopal_mvu.Task.t
(** [minimize] minimizes the window. *)

val maximize : (unit, string) result Nopal_mvu.Task.t
(** [maximize] maximizes the window. *)

val unmaximize : (unit, string) result Nopal_mvu.Task.t
(** [unmaximize] restores the window from maximized state. *)

val is_maximized : (bool, string) result Nopal_mvu.Task.t
(** [is_maximized] queries maximized state. *)

val close : (unit, string) result Nopal_mvu.Task.t
(** [close] closes the window. *)

val set_size : size -> (unit, string) result Nopal_mvu.Task.t
(** [set_size size] sets the window's logical size to [size.width] x
    [size.height] pixels. *)

val inner_size : (size, string) result Nopal_mvu.Task.t
(** [inner_size] queries the window's inner dimensions in logical pixels. *)

val is_visible : (bool, string) result Nopal_mvu.Task.t
(** [is_visible] queries whether the window is currently visible. *)

val show : (unit, string) result Nopal_mvu.Task.t
(** [show] makes the window visible. *)

val hide : (unit, string) result Nopal_mvu.Task.t
(** [hide] hides the window. *)

val set_focus : (unit, string) result Nopal_mvu.Task.t
(** [set_focus] brings the window to the foreground and gives it input focus. *)

val center : (unit, string) result Nopal_mvu.Task.t
(** [center] centers the window on the screen. *)

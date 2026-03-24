(** Typed OCaml bindings to the Tauri Window API.

    Provides window management functions via the Tauri JavaScript API. Each
    function returns a {!Nopal_mvu.Task.t} that resolves when the Tauri promise
    completes. If the Tauri runtime is not available, the task never resolves.
*)

type size = { width : int; height : int }
(** Logical pixel dimensions of a window. *)

val set_title : string -> unit Nopal_mvu.Task.t
(** [set_title title] sets the window title bar text to [title]. Resolves with
    [()] when the operation completes. *)

val set_fullscreen : bool -> unit Nopal_mvu.Task.t
(** [set_fullscreen flag] enters fullscreen when [flag] is [true], exits when
    [false]. Resolves with [()] when the operation completes. *)

val is_fullscreen : bool Nopal_mvu.Task.t
(** [is_fullscreen] queries fullscreen state. Resolves with the current
    fullscreen status. *)

val minimize : unit Nopal_mvu.Task.t
(** [minimize] minimizes the window. Resolves with [()] when the operation
    completes. *)

val maximize : unit Nopal_mvu.Task.t
(** [maximize] maximizes the window. Resolves with [()] when the operation
    completes. *)

val unmaximize : unit Nopal_mvu.Task.t
(** [unmaximize] restores the window from maximized state. Resolves with [()]
    when the operation completes. *)

val is_maximized : bool Nopal_mvu.Task.t
(** [is_maximized] queries maximized state. Resolves with the current maximized
    status. *)

val close : unit Nopal_mvu.Task.t
(** [close] closes the window. Resolves with [()] when the operation completes.
*)

val set_size : size -> unit Nopal_mvu.Task.t
(** [set_size size] sets the window's logical size to [size.width] x
    [size.height] pixels. Resolves with [()] when the operation completes. *)

val inner_size : size Nopal_mvu.Task.t
(** [inner_size] queries the window's inner dimensions. Resolves with the
    logical pixel size. *)

val is_visible : bool Nopal_mvu.Task.t
(** [is_visible] queries whether the window is currently visible. Resolves with
    the current visibility status. *)

val show : unit Nopal_mvu.Task.t
(** [show] makes the window visible. Resolves with [()] when the operation
    completes. *)

val hide : unit Nopal_mvu.Task.t
(** [hide] hides the window. Resolves with [()] when the operation completes. *)

val set_focus : unit Nopal_mvu.Task.t
(** [set_focus] brings the window to the foreground and gives it input focus.
    Resolves with [()] when the operation completes. *)

val center : unit Nopal_mvu.Task.t
(** [center] centers the window on the screen. Resolves with [()] when the
    operation completes. *)

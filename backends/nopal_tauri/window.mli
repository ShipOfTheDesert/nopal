(** Typed OCaml bindings to the Tauri Window API.

    Provides window management functions via the Tauri JavaScript API. Each
    function uses the [Fut.await] callback pattern. If the Tauri runtime is not
    available, callbacks are simply never invoked. *)

type size = { width : int; height : int }
(** Logical pixel dimensions of a window. *)

val set_title : string -> (unit -> unit) -> unit
(** [set_title title f] sets the window title bar text to [title]. When the
    operation completes, [f ()] is called. *)

val set_fullscreen : bool -> (unit -> unit) -> unit
(** [set_fullscreen flag f] enters fullscreen when [flag] is [true], exits when
    [false]. When the operation completes, [f ()] is called. *)

val is_fullscreen : (bool -> unit) -> unit
(** [is_fullscreen f] queries fullscreen state. When the query completes,
    [f is_fs] is called with the current fullscreen status. *)

val minimize : (unit -> unit) -> unit
(** [minimize f] minimizes the window. When the operation completes, [f ()] is
    called. *)

val maximize : (unit -> unit) -> unit
(** [maximize f] maximizes the window. When the operation completes, [f ()] is
    called. *)

val unmaximize : (unit -> unit) -> unit
(** [unmaximize f] restores the window from maximized state. When the operation
    completes, [f ()] is called. *)

val is_maximized : (bool -> unit) -> unit
(** [is_maximized f] queries maximized state. When the query completes,
    [f is_max] is called with the current maximized status. *)

val close : (unit -> unit) -> unit
(** [close f] closes the window. When the operation completes, [f ()] is called.
*)

val set_size : size -> (unit -> unit) -> unit
(** [set_size size f] sets the window's logical size to [size.width] x
    [size.height] pixels. When the operation completes, [f ()] is called. *)

val inner_size : (size -> unit) -> unit
(** [inner_size f] queries the window's inner dimensions. When the query
    completes, [f size] is called with the logical pixel size. *)

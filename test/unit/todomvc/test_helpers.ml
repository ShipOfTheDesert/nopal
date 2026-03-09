open Todomvc

(** No-op storage that loads empty and discards saves. *)
let noop_storage : (module Storage) =
  (module struct
    let load () = []
    let save _ = ()
  end)

(** Storage pre-populated with the given todos. *)
let preloaded_storage (todos : todo list) : (module Storage) =
  (module struct
    let load () = todos
    let save _ = ()
  end)

(** Storage that records every save call in a ref. *)
let tracking_storage () =
  let saves : todo list list ref = ref [] in
  let storage : (module Storage) =
    (module struct
      let load () = []
      let save todos = saves := todos :: !saves
    end)
  in
  (storage, saves)

let make_mock_platform initial_path =
  let current = ref initial_path in
  let _popstate_listener : (string -> unit) option ref = ref None in
  let platform =
    (module struct
      let current_path () = !current
      let push_state path = current := path
      let replace_state path = current := path
      let back () = ()

      let on_popstate callback =
        _popstate_listener := Some callback;
        fun () -> _popstate_listener := None
    end : Nopal_router.Platform.S)
  in
  platform

let make_router ?(initial_path = "/") () =
  let platform = make_mock_platform initial_path in
  Nopal_router.Router.create ~platform ~parse ~to_path ~not_found:All_route

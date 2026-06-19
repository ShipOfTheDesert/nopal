type size = { width : int; height : int }

let window_args args = Array.append [| ("label", Jv.of_string "main") |] args

let window_unit cmd args =
  Nopal_mvu.Task.from_callback
    (Ipc.invoke_result
       ~ok:(fun _ -> ())
       ("plugin:window|" ^ cmd) (window_args args))

let window_bool cmd =
  Nopal_mvu.Task.from_callback
    (Ipc.invoke_result ~ok:Jv.to_bool ("plugin:window|" ^ cmd)
       (window_args [||]))

let set_title title =
  window_unit "set_title" [| ("value", Jv.of_string title) |]

let set_fullscreen flag =
  window_unit "set_fullscreen" [| ("value", Jv.of_bool flag) |]

let is_fullscreen = window_bool "is_fullscreen"
let minimize = window_unit "minimize" [||]
let maximize = window_unit "maximize" [||]
let unmaximize = window_unit "unmaximize" [||]
let is_maximized = window_bool "is_maximized"
let close = window_unit "close" [||]

let set_size size =
  let data =
    Jv.obj
      [| ("width", Jv.of_int size.width); ("height", Jv.of_int size.height) |]
  in
  let value = Jv.obj [| ("Logical", data) |] in
  window_unit "set_size" [| ("value", value) |]

let inner_size =
  Nopal_mvu.Task.from_callback
    (Ipc.invoke_result
       ~ok:(fun jv ->
         {
           width = Jv.to_int (Jv.get jv "width");
           height = Jv.to_int (Jv.get jv "height");
         })
       "plugin:window|inner_size" (window_args [||]))

let is_visible = window_bool "is_visible"
let show = window_unit "show" [||]
let hide = window_unit "hide" [||]
let set_focus = window_unit "set_focus" [||]
let center = window_unit "center" [||]

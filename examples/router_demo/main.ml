let () =
  let open Brr in
  let target =
    match Document.find_el_by_id G.document (Jstr.v "app") with
    | Some el -> el
    | None ->
        let body = Document.body G.document in
        let div = El.div [] in
        El.append_children body [ div ];
        div
  in
  let platform =
    (module Nopal_web.Platform_web : Nopal_platform.Platform.NAV)
  in
  let router =
    Nopal_platform.Router.create ~platform ~parse:Router_demo_app.parse
      ~to_path:Router_demo_app.to_path ~not_found:Router_demo_app.Step_one
  in
  let (_ : Nopal_runtime.Telemetry.handle) =
    Nopal_web.mount_with_telemetry
      (module struct
        type model = Router_demo_app.model
        type msg = Router_demo_app.msg

        let init = Router_demo_app.init router
        let update = Router_demo_app.update router
        let view = Router_demo_app.view
        let subscriptions = Router_demo_app.subscriptions router
      end)
      ~serialize_msg:Router_demo_app.serialize_msg
      ~serialize_model:Router_demo_app.serialize_model target
  in
  ()

let () =
  let platform = (module Nopal_web.Platform_web : Nopal_router.Platform.S) in
  let router =
    Nopal_router.Router.create ~platform ~parse:Kitchen_sink_app.parse
      ~to_path:Kitchen_sink_app.to_path ~not_found:Kitchen_sink_app.NotFound
  in
  let module App = struct
    type model = Kitchen_sink_app.model
    type msg = Kitchen_sink_app.msg

    let init = Kitchen_sink_app.init router
    let update = Kitchen_sink_app.update
    let view = Kitchen_sink_app.view
    let subscriptions = Kitchen_sink_app.subscriptions
  end in
  let module R = Nopal_runtime.Runtime.Make (App) in
  let runtime = R.create () in
  R.start runtime;
  ignore runtime

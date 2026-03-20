let has_tauri () =
  not (Jv.is_undefined (Jv.get Jv.global "__TAURI_INTERNALS__"))

let tauri_fetch_cmd =
  Nopal_mvu.Cmd.batch
    [
      Nopal_mvu.Cmd.task (fun dispatch ->
          Nopal_tauri.App.get_name (fun s ->
              dispatch (Kitchen_sink_app.GotAppName s)));
      Nopal_mvu.Cmd.task (fun dispatch ->
          Nopal_tauri.App.get_version (fun s ->
              dispatch (Kitchen_sink_app.GotAppVersion s)));
      Nopal_mvu.Cmd.task (fun dispatch ->
          Nopal_tauri.App.get_tauri_version (fun s ->
              dispatch (Kitchen_sink_app.GotTauriVersion s)));
    ]

let init () =
  let model, cmd = Kitchen_sink_app.init () in
  if has_tauri () then (model, Nopal_mvu.Cmd.batch [ cmd; tauri_fetch_cmd ])
  else (model, cmd)

let update model msg =
  let model', cmd = Kitchen_sink_app.update model msg in
  match msg with
  | Kitchen_sink_app.FetchTauriInfo when has_tauri () ->
      (model', Nopal_mvu.Cmd.batch [ cmd; tauri_fetch_cmd ])
  | _ -> (model', cmd)

let () =
  Nopal_http.register_backend { Nopal_http.send = Nopal_http_web.send };
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
  Nopal_web.mount
    (module struct
      type model = Kitchen_sink_app.model
      type msg = Kitchen_sink_app.msg

      let init = init
      let update = update
      let view = Kitchen_sink_app.view
      let subscriptions = Kitchen_sink_app.subscriptions
    end)
    target

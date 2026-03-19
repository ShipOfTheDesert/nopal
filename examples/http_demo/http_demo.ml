open Nopal_element

type request_state = Idle | Loading | Success of string | Errored of string

type todo = {
  user_id : int; [@key "userId"]
  id : int;
  title : string;
  completed : bool;
}
[@@deriving of_yojson]

type decode_state = DcIdle | DcLoading | Decoded of todo | DcErrored of string

type model = {
  get_state : request_state;
  post_state : request_state;
  put_state : request_state;
  delete_state : request_state;
  decode_state : decode_state;
  timeout_state : request_state;
}

type msg =
  | GetClicked
  | GetResult of Nopal_http.outcome
  | PostClicked
  | PostResult of Nopal_http.outcome
  | PutClicked
  | PutResult of Nopal_http.outcome
  | DeleteClicked
  | DeleteResult of Nopal_http.outcome
  | DecodeClicked
  | DecodeResult of Nopal_http.outcome
  | TimeoutClicked
  | TimeoutResult of Nopal_http.outcome

let btn_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (fun l ->
      l |> Nopal_style.Style.padding 6.0 16.0 6.0 16.0)

let page_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (fun l ->
      { l with gap = 20.0 } |> Nopal_style.Style.padding 32.0 32.0 32.0 32.0)

let section_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (fun l -> { l with gap = 8.0 })

let init () =
  ( {
      get_state = Idle;
      post_state = Idle;
      put_state = Idle;
      delete_state = Idle;
      decode_state = DcIdle;
      timeout_state = Idle;
    },
    Nopal_mvu.Cmd.none )

let update model msg =
  match msg with
  | GetClicked ->
      ( { model with get_state = Loading },
        Nopal_http.get "https://jsonplaceholder.typicode.com/todos/1" (fun o ->
            GetResult o) )
  | GetResult (Ok { body; _ }) ->
      ({ model with get_state = Success body }, Nopal_mvu.Cmd.none)
  | GetResult (Error (Network_error msg)) ->
      ({ model with get_state = Errored msg }, Nopal_mvu.Cmd.none)
  | GetResult (Error Timeout) ->
      ( { model with get_state = Errored "request timed out" },
        Nopal_mvu.Cmd.none )
  | PostClicked ->
      ( { model with post_state = Loading },
        Nopal_http.post
          ~body:(Nopal_http.Json {|{"title":"nopal","body":"test","userId":1}|})
          "https://jsonplaceholder.typicode.com/posts" (fun o -> PostResult o)
      )
  | PostResult (Ok { body; _ }) ->
      ({ model with post_state = Success body }, Nopal_mvu.Cmd.none)
  | PostResult (Error (Network_error msg)) ->
      ({ model with post_state = Errored msg }, Nopal_mvu.Cmd.none)
  | PostResult (Error Timeout) ->
      ( { model with post_state = Errored "request timed out" },
        Nopal_mvu.Cmd.none )
  | PutClicked ->
      ( { model with put_state = Loading },
        Nopal_http.put
          ~headers:[ ("X-Custom", "nopal") ]
          ~body:
            (Nopal_http.Form_encoded
               [ ("title", "updated"); ("body", "via nopal") ])
          "https://jsonplaceholder.typicode.com/posts/1"
          (fun o -> PutResult o) )
  | PutResult (Ok { body; _ }) ->
      ({ model with put_state = Success body }, Nopal_mvu.Cmd.none)
  | PutResult (Error (Network_error msg)) ->
      ({ model with put_state = Errored msg }, Nopal_mvu.Cmd.none)
  | PutResult (Error Timeout) ->
      ( { model with put_state = Errored "request timed out" },
        Nopal_mvu.Cmd.none )
  | DeleteClicked ->
      ( { model with delete_state = Loading },
        Nopal_http.delete_ "https://jsonplaceholder.typicode.com/posts/1"
          (fun o -> DeleteResult o) )
  | DeleteResult (Ok { body; _ }) ->
      ({ model with delete_state = Success body }, Nopal_mvu.Cmd.none)
  | DeleteResult (Error (Network_error msg)) ->
      ({ model with delete_state = Errored msg }, Nopal_mvu.Cmd.none)
  | DeleteResult (Error Timeout) ->
      ( { model with delete_state = Errored "request timed out" },
        Nopal_mvu.Cmd.none )
  | DecodeClicked ->
      ( { model with decode_state = DcLoading },
        Nopal_http.get "https://jsonplaceholder.typicode.com/todos/1" (fun o ->
            DecodeResult o) )
  | DecodeResult (Ok { body; _ }) ->
      let state =
        match Yojson.Safe.from_string body |> todo_of_yojson with
        | Ok todo -> Decoded todo
        | Error msg -> DcErrored msg
      in
      ({ model with decode_state = state }, Nopal_mvu.Cmd.none)
  | DecodeResult (Error (Network_error msg)) ->
      ({ model with decode_state = DcErrored msg }, Nopal_mvu.Cmd.none)
  | DecodeResult (Error Timeout) ->
      ( { model with decode_state = DcErrored "request timed out" },
        Nopal_mvu.Cmd.none )
  | TimeoutClicked ->
      ( { model with timeout_state = Loading },
        Nopal_http.get ~timeout:2.0 "https://httpbin.org/delay/10" (fun o ->
            TimeoutResult o) )
  | TimeoutResult (Ok { body; _ }) ->
      ({ model with timeout_state = Success body }, Nopal_mvu.Cmd.none)
  | TimeoutResult (Error (Network_error msg)) ->
      ({ model with timeout_state = Errored msg }, Nopal_mvu.Cmd.none)
  | TimeoutResult (Error Timeout) ->
      ( { model with timeout_state = Errored "request timed out" },
        Nopal_mvu.Cmd.none )

let view_get model =
  let status_display =
    match model.get_state with
    | Idle ->
        Element.box
          ~attrs:[ ("data-testid", "get-idle") ]
          [ Element.text "Click Fetch to load data" ]
    | Loading ->
        Element.box
          ~attrs:[ ("data-testid", "get-status") ]
          [ Element.text "Loading\u{2026}" ]
    | Success body ->
        Element.box
          ~attrs:[ ("data-testid", "get-result") ]
          [ Element.text body ]
    | Errored msg ->
        Element.box ~attrs:[ ("data-testid", "get-error") ] [ Element.text msg ]
  in
  Element.column ~style:section_style
    ~attrs:[ ("data-section", "get") ]
    [
      Element.text "GET";
      Element.button ~style:btn_style
        ~attrs:[ ("data-testid", "get-btn") ]
        ~on_click:GetClicked (Element.text "Fetch");
      status_display;
    ]

let view_post model =
  let status_display =
    match model.post_state with
    | Idle ->
        Element.box
          ~attrs:[ ("data-testid", "post-idle") ]
          [ Element.text "Click Send to POST data" ]
    | Loading ->
        Element.box
          ~attrs:[ ("data-testid", "post-status") ]
          [ Element.text "Loading\u{2026}" ]
    | Success body ->
        Element.box
          ~attrs:[ ("data-testid", "post-result") ]
          [ Element.text body ]
    | Errored msg ->
        Element.box
          ~attrs:[ ("data-testid", "post-error") ]
          [ Element.text msg ]
  in
  Element.column ~style:section_style
    ~attrs:[ ("data-section", "post") ]
    [
      Element.text "POST";
      Element.button ~style:btn_style
        ~attrs:[ ("data-testid", "post-btn") ]
        ~on_click:PostClicked (Element.text "Send");
      status_display;
    ]

let view_put model =
  let status_display =
    match model.put_state with
    | Idle ->
        Element.box
          ~attrs:[ ("data-testid", "put-idle") ]
          [ Element.text "Click Send to PUT data" ]
    | Loading ->
        Element.box
          ~attrs:[ ("data-testid", "put-status") ]
          [ Element.text "Loading\u{2026}" ]
    | Success body ->
        Element.box
          ~attrs:[ ("data-testid", "put-result") ]
          [ Element.text body ]
    | Errored msg ->
        Element.box ~attrs:[ ("data-testid", "put-error") ] [ Element.text msg ]
  in
  Element.column ~style:section_style
    ~attrs:[ ("data-section", "put") ]
    [
      Element.text "PUT";
      Element.button ~style:btn_style
        ~attrs:[ ("data-testid", "put-btn") ]
        ~on_click:PutClicked (Element.text "Send");
      status_display;
    ]

let view_delete model =
  let status_display =
    match model.delete_state with
    | Idle ->
        Element.box
          ~attrs:[ ("data-testid", "delete-idle") ]
          [ Element.text "Click Delete to remove a post" ]
    | Loading ->
        Element.box
          ~attrs:[ ("data-testid", "delete-status") ]
          [ Element.text "Loading\u{2026}" ]
    | Success body ->
        Element.box
          ~attrs:[ ("data-testid", "delete-result") ]
          [ Element.text body ]
    | Errored msg ->
        Element.box
          ~attrs:[ ("data-testid", "delete-error") ]
          [ Element.text msg ]
  in
  Element.column ~style:section_style
    ~attrs:[ ("data-section", "delete") ]
    [
      Element.text "DELETE";
      Element.button ~style:btn_style
        ~attrs:[ ("data-testid", "delete-btn") ]
        ~on_click:DeleteClicked (Element.text "Delete");
      status_display;
    ]

let view_decode model =
  let status_display =
    match model.decode_state with
    | DcIdle ->
        Element.box
          ~attrs:[ ("data-testid", "decode-idle") ]
          [ Element.text "Click Decode to fetch and parse a todo" ]
    | DcLoading ->
        Element.box
          ~attrs:[ ("data-testid", "decode-status") ]
          [ Element.text "Loading\u{2026}" ]
    | Decoded todo ->
        Element.box
          ~attrs:[ ("data-testid", "decode-result") ]
          [
            Element.column
              [
                Element.text ("userId: " ^ string_of_int todo.user_id);
                Element.text ("id: " ^ string_of_int todo.id);
                Element.text ("title: " ^ todo.title);
                Element.text ("completed: " ^ string_of_bool todo.completed);
              ];
          ]
    | DcErrored msg ->
        Element.box
          ~attrs:[ ("data-testid", "decode-error") ]
          [ Element.text msg ]
  in
  Element.column ~style:section_style
    ~attrs:[ ("data-section", "decode") ]
    [
      Element.text "Typed Decode";
      Element.button ~style:btn_style
        ~attrs:[ ("data-testid", "decode-btn") ]
        ~on_click:DecodeClicked (Element.text "Decode");
      status_display;
    ]

let view_timeout model =
  let status_display =
    match model.timeout_state with
    | Idle ->
        Element.box
          ~attrs:[ ("data-testid", "timeout-idle") ]
          [
            Element.text
              "Click Timeout to test a 2s timeout against a 10s delay";
          ]
    | Loading ->
        Element.box
          ~attrs:[ ("data-testid", "timeout-status") ]
          [ Element.text "Loading\u{2026}" ]
    | Success body ->
        Element.box
          ~attrs:[ ("data-testid", "timeout-result") ]
          [ Element.text body ]
    | Errored msg ->
        Element.box
          ~attrs:[ ("data-testid", "timeout-error") ]
          [ Element.text msg ]
  in
  Element.column ~style:section_style
    ~attrs:[ ("data-section", "timeout") ]
    [
      Element.text "Timeout";
      Element.button ~style:btn_style
        ~attrs:[ ("data-testid", "timeout-btn") ]
        ~on_click:TimeoutClicked (Element.text "Timeout");
      status_display;
    ]

let view _vp model =
  Element.column ~style:page_style
    [
      view_get model;
      view_post model;
      view_put model;
      view_delete model;
      view_decode model;
      view_timeout model;
    ]

let subscriptions _model = Nopal_mvu.Sub.none

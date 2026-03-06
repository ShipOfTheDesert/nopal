open Nopal_mvu

(* REQ-F15 opaqueness: App.S is a module type — structural enforcement
   is compile-time. These tests verify that a concrete module satisfying
   App.S can be instantiated and its functions produce the expected types. *)

module Counter :
  App.S with type model = int and type msg = [ `Increment | `Decrement | `Reset ] =
struct
  type model = int
  type msg = [ `Increment | `Decrement | `Reset ]

  let init () = (0, Cmd.none)

  let update model msg =
    match msg with
    | `Increment -> (model + 1, Cmd.none)
    | `Decrement -> (model - 1, Cmd.none)
    | `Reset -> (0, Cmd.none)

  let view _model = Nopal_element.Element.Empty
  let subscriptions _model = Sub.none
end

let app_module_roundtrip () =
  let model, cmd = Counter.init () in
  Alcotest.(check int) "init model is 0" 0 model;
  let msgs = ref [] in
  Cmd.execute (fun m -> msgs := m :: !msgs) cmd;
  Alcotest.(check int) "init cmd dispatches nothing" 0 (List.length !msgs);
  let model', _cmd' = Counter.update model `Increment in
  Alcotest.(check int) "update increments" 1 model';
  let elem = Counter.view model in
  Alcotest.(check bool)
    "view returns Empty" true
    (match elem with
    | Nopal_element.Element.Empty -> true
    | Nopal_element.Element.Text _
    | Nopal_element.Element.Box _
    | Nopal_element.Element.Row _
    | Nopal_element.Element.Column _
    | Nopal_element.Element.Button _
    | Nopal_element.Element.Input _
    | Nopal_element.Element.Image _
    | Nopal_element.Element.Scroll _
    | Nopal_element.Element.Keyed _ ->
        false);
  let sub = Counter.subscriptions model in
  let keys = Sub.keys sub in
  Alcotest.(check int)
    "subscriptions returns none (no keys)" 0 (List.length keys)

let app_init_with_cmd () =
  let module App : App.S with type model = int and type msg = [ `Tick ] = struct
    type model = int
    type msg = [ `Tick ]

    let init () = (0, Cmd.batch [ Cmd.none; Cmd.none ])
    let update model _msg = (model + 1, Cmd.none)
    let view _model = Nopal_element.Element.Empty
    let subscriptions _model = Sub.none
  end in
  let model, cmd = App.init () in
  Alcotest.(check int) "init model" 0 model;
  let msgs = ref [] in
  Cmd.execute (fun m -> msgs := m :: !msgs) cmd;
  Alcotest.(check int) "batch of nones dispatches nothing" 0 (List.length !msgs)

let app_update_produces_cmd () =
  let module App :
    App.S
      with type model = string list
       and type msg = [ `Add of string | `Added ] = struct
    type model = string list
    type msg = [ `Add of string | `Added ]

    let init () = ([], Cmd.none)

    let update model msg =
      match msg with
      | `Add s -> (s :: model, Cmd.perform (fun dispatch -> dispatch `Added))
      | `Added -> (model, Cmd.none)

    let view _model = Nopal_element.Element.Empty
    let subscriptions _model = Sub.none
  end in
  let model, _ = App.init () in
  let model', cmd = App.update model (`Add "hello") in
  Alcotest.(check int) "model has one item" 1 (List.length model');
  Alcotest.(check string) "item is hello" "hello" (List.hd model');
  let msgs = ref [] in
  Cmd.execute
    (fun m ->
      msgs :=
        (match m with
        | `Added -> "added"
        | `Add s -> "add:" ^ s)
        :: !msgs)
    cmd;
  Alcotest.(check (list string)) "cmd dispatches Added" [ "added" ] !msgs

let () =
  Alcotest.run "App"
    [
      ( "App.S",
        [
          Alcotest.test_case "app_module_roundtrip" `Quick app_module_roundtrip;
          Alcotest.test_case "app_init_with_cmd" `Quick app_init_with_cmd;
          Alcotest.test_case "app_update_produces_cmd" `Quick
            app_update_produces_cmd;
        ] );
    ]

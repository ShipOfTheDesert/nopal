# Task Migration Guide

Nopal's async story has shifted from callback-based `Cmd.task` to a composable
`Task.t` monad. The old `Cmd.task` accepted a callback `(('msg -> unit) -> unit)`;
the new `Cmd.task` accepts a `'msg Task.t` — a pure description of an async
operation that the runtime executes. This guide covers every migration pattern
with before/after snippets and a mechanical checklist you can follow
step-by-step.

---

## Pattern 1: `Cmd.task` callback to `Cmd.task` with `Task.t`

### Simple single-dispatch async

**Before** (callback-based):

```ocaml
let fetch_time =
  Cmd.task (fun dispatch ->
      get_current_time_async (fun time ->
          dispatch (GotTime time)))
```

**After** (`Task.t`-based):

```ocaml
let fetch_time =
  Cmd.task
    (let open Task.Syntax in
     let+ time = Task.from_callback (fun resolve -> get_current_time_async resolve) in
     GotTime time)
```

`Task.from_callback` bridges any callback-style async primitive into a `Task.t`.
The `let+` (map) operator transforms the result into a message.

### Async with result mapping

**Before**:

```ocaml
let load_data =
  Cmd.task (fun dispatch ->
      fetch_data (fun raw ->
          let parsed = parse raw in
          dispatch (DataLoaded parsed)))
```

**After**:

```ocaml
let load_data =
  Cmd.task
    (let open Task.Syntax in
     let+ raw = Task.from_callback (fun resolve -> fetch_data resolve) in
     DataLoaded (parse raw))
```

### Chaining multiple async operations

**Before**:

```ocaml
let fetch_and_process =
  Cmd.task (fun dispatch ->
      fetch_token (fun token ->
          fetch_with_token token (fun data ->
              dispatch (GotData data))))
```

**After**:

```ocaml
let fetch_and_process =
  Cmd.task
    (let open Task.Syntax in
     let* token = Task.from_callback (fun resolve -> fetch_token resolve) in
     let+ data = Task.from_callback (fun resolve -> fetch_with_token token resolve) in
     GotData data)
```

`let*` (bind) sequences tasks — the second task depends on the first's result.

### When to use `Cmd.perform` instead

`Cmd.task` dispatches **exactly one** message when the task resolves.
`Cmd.perform` is for operations that dispatch **zero or many** messages, or
that are synchronous/immediate:

```ocaml
(* Zero dispatches — fire-and-forget *)
Cmd.perform (fun _dispatch -> log_to_console "something happened")

(* Multiple dispatches — streaming, event setup *)
Cmd.perform (fun dispatch ->
    setup_listener (fun event -> dispatch (GotEvent event)))
```

**Rule of thumb:** If your callback calls `dispatch` exactly once, migrate to
`Cmd.task` with `Task.t`. If it calls `dispatch` zero times or more than once,
keep `Cmd.perform`.

---

## Pattern 2: HTTP requests

### Backend registration in `main.ml`

**Before** (old callback-based backend type):

```ocaml
(* Old backend type was:
   type backend = { send : 'msg. request -> (outcome -> 'msg) -> 'msg Cmd.t } *)
let () =
  Nopal_http.register_backend
    { send = (fun request on_result -> Nopal_http_web.send request on_result) }
```

**After** (current `Task.t`-based backend type):

```ocaml
(* Current backend type:
   type backend = { send : request -> outcome Nopal_mvu.Task.t } *)
let () =
  Nopal_http.register_backend { Nopal_http.send = Nopal_http_web.send }
```

`Nopal_http_web.send` now returns `outcome Task.t` directly, matching the
backend's `send` field signature.

For cancellable HTTP support, also register:

```ocaml
let () =
  Nopal_http.register_cancellable_backend
    { Nopal_http.send_cancellable = Nopal_http_web.send_cancellable }
```

### Using convenience functions in `update`

The `Nopal_http` convenience functions (`get`, `post`, `put`, `delete_`,
`patch`) accept an `(outcome -> 'msg)` mapper and return `'msg Cmd.t` — they
handle the `Task.t` wrapping internally. **Application code using these
functions does not need to change.**

```ocaml
(* This pattern works both before and after the migration *)
let update model = function
  | FetchItems ->
    let cmd = Nopal_http.get "/api/items" (fun outcome -> GotItems outcome) in
    (model, cmd)
  | GotItems (Ok response) ->
    ({ model with items = parse_items response.body }, Cmd.none)
  | GotItems (Error _err) ->
    ({ model with error = Some "Failed to load items" }, Cmd.none)
```

### Cancellable HTTP requests

```ocaml
let update model = function
  | FetchItems ->
    let token, cmd =
      Nopal_http.get_cancellable "/api/items" (fun outcome -> GotItems outcome)
    in
    ({ model with cancel_token = Some token }, cmd)
  | CancelFetch ->
    Option.iter Task.cancel model.cancel_token;
    ({ model with cancel_token = None }, Cmd.none)
```

### Direct `Task.t` composition with `Task.Syntax`

When you need to chain HTTP calls or transform results before dispatching,
compose tasks directly:

```ocaml
let fetch_user_and_posts user_id =
  Cmd.task
    (let open Task.Syntax in
     let* user_outcome = Nopal_http_web.get ("/api/users/" ^ user_id) in
     match user_outcome with
     | Error err -> Task.return (HttpError err)
     | Ok user_response ->
       let+ posts_outcome = Nopal_http_web.get ("/api/users/" ^ user_id ^ "/posts") in
       GotUserAndPosts (user_response, posts_outcome))
```

Note: this uses `Nopal_http_web` directly (returns `outcome Task.t`), not the
`Nopal_http` convenience functions (which return `'msg Cmd.t`).

---

## Pattern 3: Tauri one-shot bindings

Tauri bindings (`Nopal_tauri.App`, `Nopal_tauri.Os`, `Nopal_tauri.Window`)
currently use the callback pattern `(value -> unit) -> unit`. Use
`Task.from_callback` to bridge them into `Task.t`.

### One-shot query

**Before**:

```ocaml
let get_app_name =
  Cmd.perform (fun dispatch ->
      Nopal_tauri.App.get_name (fun name ->
          dispatch (GotName name)))
```

**After**:

```ocaml
let get_app_name =
  Cmd.task
    (let open Task.Syntax in
     let+ name = Task.from_callback Nopal_tauri.App.get_name in
     GotName name)
```

`Nopal_tauri.App.get_name` has the signature `(string -> unit) -> unit`, which
is exactly what `Task.from_callback` expects.

### Chaining Tauri calls

**Before**:

```ocaml
let get_app_info =
  Cmd.perform (fun dispatch ->
      Nopal_tauri.App.get_name (fun name ->
          Nopal_tauri.App.get_version (fun version ->
              dispatch (GotAppInfo (name, version)))))
```

**After**:

```ocaml
let get_app_info =
  Cmd.task
    (let open Task.Syntax in
     let* name = Task.from_callback Nopal_tauri.App.get_name in
     let+ version = Task.from_callback Nopal_tauri.App.get_version in
     GotAppInfo (name, version))
```

### Fire-and-forget Tauri operations

Operations like `Window.set_title` or `Window.minimize` that produce `unit`
and don't need to dispatch a message should stay with `Cmd.perform`:

```ocaml
(* Still uses Cmd.perform — fire-and-forget, no message dispatched *)
let set_title title =
  Cmd.perform (fun _dispatch ->
      Nopal_tauri.Window.set_title title (fun () -> ()))
```

### `Event.listen` stays callback-based

`Nopal_tauri.Event.listen` dispatches **multiple** messages (one per event
occurrence). It does not fit the single-dispatch `Task.t` model. Keep it with
`Cmd.perform`:

```ocaml
(* Event.listen dispatches many times — stays with Cmd.perform *)
let listen_for_events =
  Cmd.perform (fun dispatch ->
      Nopal_tauri.Event.listen "my-event"
        (fun event -> dispatch (GotEvent event.payload))
        (fun _unlisten -> ()))
```

---

## Dispatch Cardinality Reference

| Dispatches | Use | Example |
|---|---|---|
| Exactly one | `Cmd.task` with `Task.t` | HTTP request, Tauri query, delayed computation |
| Zero (fire-and-forget) | `Cmd.perform` | Logging, `Window.set_title` |
| Many (streaming) | `Cmd.perform` | `Event.listen`, WebSocket messages |
| Delayed one | `Cmd.after` | Debounce, timeout |

---

## Mechanical Checklist

Follow these steps in order to migrate a downstream Nopal project:

### 1. Update HTTP backend registration

Search `main.ml` for `register_backend`. Update the backend record to match
the current type:

```
(* Find *)    { send = (fun request on_result -> ...) }
(* Replace *) { Nopal_http.send = Nopal_http_web.send }
```

If using cancellable requests, add `register_cancellable_backend`:

```ocaml
Nopal_http.register_cancellable_backend
  { Nopal_http.send_cancellable = Nopal_http_web.send_cancellable }
```

### 2. Migrate `Cmd.task (fun dispatch` patterns

Search for `Cmd.task (fun dispatch` or `Cmd.task (fun d `. For each match:

1. Identify whether the callback calls dispatch exactly once.
2. If yes: rewrite using `Task.from_callback` + `Task.Syntax` (see Pattern 1).
3. If no (zero or many dispatches): change to `Cmd.perform` instead.

### 3. Migrate Tauri one-shot callbacks

Search for Tauri API calls (`Nopal_tauri.App.get_name`,
`Nopal_tauri.App.get_version`, `Nopal_tauri.App.get_tauri_version`,
`Nopal_tauri.Os.platform`, `Nopal_tauri.Window.is_fullscreen`,
`Nopal_tauri.Window.is_maximized`, `Nopal_tauri.Window.inner_size`) used
inside `Cmd.perform` where the callback dispatches exactly once.

Rewrite as `Cmd.task` with `Task.from_callback` (see Pattern 3).

Leave `Event.listen` and fire-and-forget operations (`set_title`,
`set_fullscreen`, `minimize`, `maximize`, `unmaximize`, `close`, `set_size`)
in `Cmd.perform`.

### 4. Check for direct `Nopal_http_web` usage

Search for `Nopal_http_web.send` called with a callback argument. If found,
rewrite to use the `Task.t`-returning functions directly and wrap with
`Cmd.task` + `Task.Syntax`, or switch to the `Nopal_http` convenience
functions which handle the wrapping.

### 5. Verify compilation

```bash
opam exec -- dune build
```

Fix any type errors — the compiler will catch signature mismatches.

### 6. Run tests

```bash
opam exec -- dune runtest
```

All existing tests should pass. If a test was constructing a `Cmd.task` with
the old callback form, it needs the same migration as application code.

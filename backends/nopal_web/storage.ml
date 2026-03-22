(* This module is tested via E2E (Playwright) in test/e2e/tests/storage.spec.ts
   rather than Alcotest because Brr_io.Storage.local requires a real browser
   Window object. *)

let storage () = Brr_io.Storage.local Brr.G.window

let get key =
  Brr_io.Storage.get_item (storage ()) (Jstr.of_string key)
  |> Option.map Jstr.to_string

let set key value =
  (* Quota-exceeded errors are silently ignored: callers cannot recover
     without implementing their own eviction strategy, and this is
     explicitly out of scope per PRD 0068. *)
  ignore
    (Brr_io.Storage.set_item (storage ()) (Jstr.of_string key)
       (Jstr.of_string value))

let remove key = Brr_io.Storage.remove_item (storage ()) (Jstr.of_string key)
let clear () = Brr_io.Storage.clear (storage ())

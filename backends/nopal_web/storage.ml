let storage () = Brr_io.Storage.local Brr.G.window

let get key =
  Brr_io.Storage.get_item (storage ()) (Jstr.of_string key)
  |> Option.map Jstr.to_string

let set key value =
  ignore
    (Brr_io.Storage.set_item (storage ()) (Jstr.of_string key)
       (Jstr.of_string value))

let remove key = Brr_io.Storage.remove_item (storage ()) (Jstr.of_string key)
let clear () = Brr_io.Storage.clear (storage ())

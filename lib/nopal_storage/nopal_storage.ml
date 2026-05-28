(* Re-export the shared error type and signature with explicit equations so that
   [Nopal_storage.error] is definitionally the same type as [Storage_intf.error]
   used by the [In_memory] and [With_codec] backends. *)
type error = Storage_intf.error =
  | Quota_exceeded of string
  | Permission_denied of string
  | Backend_unavailable of string
  | Backend_error of string

module type S = Storage_intf.S

let message = function
  | Quota_exceeded msg -> Printf.sprintf "Storage quota exceeded: %s" msg
  | Permission_denied msg -> Printf.sprintf "Storage permission denied: %s" msg
  | Backend_unavailable msg ->
      Printf.sprintf "Storage backend unavailable: %s" msg
  | Backend_error msg -> Printf.sprintf "Storage backend error: %s" msg

module In_memory = In_memory.Make
module With_codec = With_codec.Make

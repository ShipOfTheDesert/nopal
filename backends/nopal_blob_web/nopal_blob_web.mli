(** Browser-side blob store for Nopal.

    A leaf backend package: it depends on [brr] and [js_of_ocaml] only, so an
    HTTP or image backend can resolve a blob handle without pulling in the
    renderer, the runtime, or the element DSL. *)

module Blob_store = Blob_store
(** Session-local handle-to-blob registry. See {!Blob_store}. *)

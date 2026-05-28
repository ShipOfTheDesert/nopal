(** IndexedDB-backed implementation of {!Nopal_storage.S}.

    Records live in database [nopal_storage], object store [kv]. Values survive
    reloads and are not subject to [localStorage]'s ~5 MB cap. {!Make} is
    generative to match the platform-capability constructor shape; all instances
    share the one underlying IndexedDB database (persistence is the point). *)

module Make () : Nopal_storage.S

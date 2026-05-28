(** Web platform capabilities: History-API navigation + IndexedDB storage.

    Implements {!Nopal_platform.Platform.S}. Navigation maps onto
    [window.history] (push/replace/back) and the [popstate] event; [storage] is
    an IndexedDB-backed {!Nopal_storage.S} via {!Nopal_storage_web.Make}. Pass
    [(module Platform_web)] to {!Nopal_platform.Router.create} (which needs only
    [NAV]) or to an application functor over {!Nopal_platform.Platform.S}. *)

include Nopal_platform.Platform.S

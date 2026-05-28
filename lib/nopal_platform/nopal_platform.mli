(** Platform capability signatures and type-safe routing for Nopal applications.

    {!module:Platform} defines the platform-capability abstraction that backends
    implement ([NAV] for navigation, [S] for the full capability bundle).
    {!module:Router} provides route parsing, navigation commands, and
    subscriptions that integrate with the MVU loop. *)

module Platform = Platform
module Router = Router

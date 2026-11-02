(** The tick a drawn checkbox paints while it is ticked.

    One shape, supplied here and not configurable: a stroked check mark in a
    square [viewBox] with no intrinsic size, so it scales to whatever box the
    caller's [background-size] gives it. Only its colour varies. *)

val css_url : Nopal_style.Color.t -> string
(** [css_url mark] is a complete CSS [url("data:image/svg+xml,…")] value whose
    SVG document strokes the tick in [mark], spelled as
    {!Style_css.color_to_css} spells it everywhere else.

    The whole SVG document is percent-encoded before it is embedded: every byte
    outside the RFC 3986 unreserved set ([A-Z a-z 0-9 - . _ ~]) is written as
    [%XX] with uppercase hex digits. Nothing inside the value can therefore
    close the [url("…")] early — a [Named] colour is taken as given and may
    carry a quote or a parenthesis — and a hex colour's [#] reaches the image as
    [%23]. That second point is not cosmetic: a raw [#] starts the data URI's
    fragment, and the browser accepts the value but paints no tick, with no
    error anywhere. *)

(** The key string a keydown or keyup subscription handler receives. *)

val of_event : key:string -> ctrl:bool -> shift:bool -> string
(** [of_event ~key ~ctrl ~shift] folds the held modifiers into the single string
    a subscription matches on. [key] is the raw key name the platform reports
    for the event; [ctrl] and [shift] are that same event's modifier flags. Both
    flags are required and labelled, because each one changes the result.

    A held modifier becomes a prefix — ["Ctrl+"] for [ctrl], ["Shift+"] for
    [shift]. When both are held the prefixes appear in the canonical order
    ["Ctrl+Shift+"], which is the only accepted spelling of a two-modifier
    chord. With neither held the raw key passes through unchanged.

    Letter case is the platform's own, and it differs between the two modifiers:
    Ctrl leaves a letter lowercase, so its chord is ["Ctrl+d"], while Shift
    uppercases it, so those chords are ["Shift+D"] and ["Ctrl+Shift+D"]. Ctrl
    does not suppress Shift's uppercasing.

    Punctuation that needs Shift to type arrives with Shift held, so it carries
    the prefix: ["Shift+?"], never bare ["?"]. The bare key on that same
    physical key is a different string entirely — ["/"] on a US layout.

    A keypress of the Ctrl or Shift key itself carries no prefixes at all,
    whichever other modifier is held: pressing Ctrl while Shift is down is
    ["Control"], and releasing Shift while Ctrl is still down is ["Shift"]. The
    modifier key names reported are ["Control"] and ["Shift"], which are not the
    prefix tokens ["Ctrl+"] and ["Shift+"]. Those two names are the only ones
    exempt from prefixing — Alt and Meta are not folded, so a keydown of the Alt
    key while Ctrl is held is ["Ctrl+Alt"].

    A backend interpreting the keydown or keyup subscription atoms builds the
    handler's string with this function, so every backend delivers one grammar
    rather than each restating it. *)

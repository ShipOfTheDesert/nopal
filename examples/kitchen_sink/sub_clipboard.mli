(** Copy a key to the clipboard — kitchen sink subapp.

    {b The key is fake.} It stands in for a secret an application shows once,
    such as a newly generated API key, and is held in the model only because it
    is not a real one. An application copying a real secret keeps it out of its
    telemetry serializers and anything else it logs.

    The section shows the key, a Copy button and a status. A click on Copy
    returns {!Nopal_mvu.Cmd.write_clipboard} from the [update] that handles the
    click, which is where a browser allows the write. The outcome comes back as
    one message carrying the result and not the key, and the status reports it:
    nothing before a click, then success or the reason the write failed. *)

type model
(** The subapp model: the key on show and the last outcome. *)

(** The subapp's messages. *)
type msg =
  | Copy_clicked  (** The Copy button was pressed. *)
  | Copy_result of (unit, Nopal_mvu.Clipboard.error) result
      (** The outcome of the write a click asked for. It carries the result
          only, never the copied text. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** The fake key, with no outcome yet. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** [Copy_clicked] asks for the key to be written to the clipboard;
    [Copy_result] records the outcome. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** Renders the key, the Copy button and the status. Every element a browser
    case reaches carries a [data-testid]: [clipboard-key], [clipboard-copy] and
    [clipboard-status]. The status also carries [data-status], one of [idle],
    [copied], [not-permitted], [unavailable] or [failed]. *)

val serialize_msg : msg -> string
(** Telemetry serializer for the section's messages, prefixed with [Clipboard:]
    and terminated with [;] so one fragment cannot prefix-alias another. An
    outcome is printed by its constructor names — [Clipboard:Copy_result:Ok;] or
    [Clipboard:Copy_result:Error Not_permitted;], for example — and a [Failed]
    outcome with the platform's quoted reason. The key is never printed. *)

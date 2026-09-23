(** Pure UI description type.

    [Element.t] is the value that view functions return. It describes what
    should appear on screen without coupling to any rendering backend. The type
    is exposed (not abstract) so that renderers can exhaustively pattern-match
    on all constructors. *)

type pointer_event = {
  x : float;
  y : float;
  client_x : float;
  client_y : float;
}
(** Pointer coordinates. [x]/[y] are element-local (for hit testing and zoom
    center). [client_x]/[client_y] are viewport-relative (stable across
    re-renders — use these for drag delta computation). *)

type wheel_event = { delta_y : float; x : float; y : float }
(** Wheel event with scroll delta and element-local coordinates. *)

type select_option = { value : string; label : string; disabled : bool }
(** A single option within a [Select] element. *)

(** Which camera a capture-capable file input asks a mobile webview to prefer.
    Mobile webviews only — on a desktop browser the hint is inert and ignored,
    which is not an error. *)
type capture =
  | User  (** The front-facing camera. *)
  | Environment  (** The rear-facing camera. *)

val capture_to_string : capture -> string
(** [capture_to_string c] is the wire token for [c]: ["user"] or
    ["environment"]. The sole producer of that token — no call site spells it as
    a bare string. *)

(** Whether a {!form} asks the platform to offer remembered values for its
    fields. Named apart from an input's per-field autocomplete token, which is a
    different thing: this is one switch for the whole form. *)
type autocomplete_mode =
  | On  (** The platform may offer remembered values. *)
  | Off  (** The platform should not offer remembered values. *)

val autocomplete_mode_to_string : autocomplete_mode -> string
(** [autocomplete_mode_to_string m] is the wire token for [m]: ["on"] or
    ["off"]. The sole producer of that token — no call site spells it as a bare
    string. *)

val equal_autocomplete_mode : autocomplete_mode -> autocomplete_mode -> bool
(** Structural equality over the closed variant. The sole definition — callers
    comparing [autocomplete_mode option] values build on this with
    [Option.equal] rather than restating the match. *)

(** What kind of text an {!input} asks the platform to accept, and so which
    keyboard and which checks it offers. Closed on purpose: the kinds a text
    field cannot honour — a checkbox, a radio button, a file picker — each have
    an element of their own. A kind this type does not name stays reachable
    through a ["type"] pair in [attrs], which an input that authors no
    [input_type] leaves standing. *)
type input_type =
  | Plain  (** Plain text. *)
  | Password  (** Text the platform obscures as it is typed. *)
  | Email  (** An email address. *)
  | Tel  (** A telephone number. *)
  | Url  (** A URL. *)
  | Number  (** A number. *)
  | Search  (** A search query. *)

val input_type_to_string : input_type -> string
(** [input_type_to_string t] is the wire token for [t]: ["text"], ["password"],
    ["email"], ["tel"], ["url"], ["number"] or ["search"]. The sole producer of
    that token — both renderers call it, and no call site spells it as a bare
    string. *)

val equal_input_type : input_type -> input_type -> bool
(** Structural equality over the closed variant. The sole definition — callers
    comparing [input_type option] values build on this with [Option.equal]
    rather than restating the match. *)

(** What activating a {!button} does to the {!form} that encloses it. Outside a
    form the two are the same. *)
type button_type =
  | Submit  (** Activating it submits the enclosing form. *)
  | Push  (** Activating it does only what its [on_click] says. *)

val button_type_to_string : button_type -> string
(** [button_type_to_string t] is the wire token for [t]: ["submit"] or
    ["button"]. The sole producer of that token — no call site spells it as a
    bare string. *)

val equal_button_type : button_type -> button_type -> bool
(** Structural equality over the closed variant. The sole definition. *)

type file_info = {
  blob_id : string;
      (** Opaque handle issued by the web blob store, valid for the page
          session. Meaningful only to a [_web] backend; never fabricate one. *)
  name : string;  (** File name as reported by the user agent. *)
  size : int;
      (** Byte length. Bounded by the OCaml int: a file of 2 GB or more exceeds
          the js_of_ocaml int range, and while the value reaches this field
          intact it is not safe to do arithmetic on. *)
  mime : string;
      (** MIME type as reported by the user agent. A hint, never validation — do
          not treat it as a security check on the file's contents. *)
  last_modified : float;  (** Milliseconds since the POSIX epoch. *)
}
(** Metadata for one selected file, plus the handle to its bytes. Carries no
    platform type, so structural tests construct it directly. *)

val file_info :
  blob_id:string ->
  name:string ->
  size:int ->
  mime:string ->
  last_modified:float ->
  file_info
(** [file_info ~blob_id ~name ~size ~mime ~last_modified] creates a [file_info].
    Application code receives these from a [File_input] handler; construct one
    directly only in tests. *)

type 'msg t =
  | Empty
  | Text of { content : string; text_style : Nopal_style.Text.t option }
  | Box of {
      style : Nopal_style.Style.t;
      interaction : Nopal_style.Interaction.t;
      attrs : (string * string) list;
      children : 'msg t list;
      focusable : bool;
      on_focus : 'msg option;
      on_blur : 'msg option;
      on_pointer_move : (pointer_event -> 'msg) option;
      on_pointer_leave : 'msg option;
      on_pointer_down : (pointer_event -> 'msg) option;
      on_pointer_up : (pointer_event -> 'msg) option;
      on_wheel : (wheel_event -> 'msg) option;
    }
  | Row of {
      style : Nopal_style.Style.t;
      interaction : Nopal_style.Interaction.t;
      attrs : (string * string) list;
      children : 'msg t list;
    }
  | Column of {
      style : Nopal_style.Style.t;
      interaction : Nopal_style.Interaction.t;
      attrs : (string * string) list;
      children : 'msg t list;
    }
  | Form of {
      style : Nopal_style.Style.t;
      interaction : Nopal_style.Interaction.t;
      attrs : (string * string) list;
      children : 'msg t list;
      on_submit : 'msg option;
          (** [None] authors no submission: the form is an inert group. *)
      autocomplete : autocomplete_mode option;
          (** [None] asks for nothing and leaves the platform's default. *)
      novalidate : bool;
          (** [true] skips the platform's own constraint validation. *)
    }
  | Button of {
      style : Nopal_style.Style.t;
      interaction : Nopal_style.Interaction.t;
      attrs : (string * string) list;
      button_type : button_type;
          (** [Push] dispatches [on_click] alone; [Submit] also submits the
              enclosing form. *)
      disabled : bool;
          (** [true] keeps the button focusable and makes it inert. *)
      on_click : 'msg option;
      on_dblclick : 'msg option;
      child : 'msg t;
    }
  | Input of {
      style : Nopal_style.Style.t;
      interaction : Nopal_style.Interaction.t;
      attrs : (string * string) list;
      value : string;
      placeholder : string;
      on_change : (string -> 'msg) option;
      on_submit : 'msg option;
      on_focus : 'msg option;
      on_blur : 'msg option;
      on_keydown : (string -> 'msg option) option;
      required : bool;
          (** [false] asserts nothing: the field is not marked required. *)
      autocomplete : string option;
          (** [None] asks for nothing and leaves the platform's default. *)
      input_type : input_type option;
          (** [None] names no kind, and the platform's default is text. *)
    }
  | Checkbox of {
      style : Nopal_style.Style.t;
      interaction : Nopal_style.Interaction.t;
      attrs : (string * string) list;
      checked : bool;
      disabled : bool;
      on_toggle : (bool -> 'msg) option;
    }
  | Radio of {
      style : Nopal_style.Style.t;
      interaction : Nopal_style.Interaction.t;
      attrs : (string * string) list;
      name : string;
      checked : bool;
      disabled : bool;
      on_select : 'msg option;
    }
  | Select of {
      style : Nopal_style.Style.t;
      interaction : Nopal_style.Interaction.t;
      attrs : (string * string) list;
      options : select_option list;
      selected : string;
      disabled : bool;
      on_change : (string -> 'msg) option;
    }
  | File_input of {
      style : Nopal_style.Style.t;
      interaction : Nopal_style.Interaction.t;
      attrs : (string * string) list;
      accept : string list;  (** Empty means unrestricted. *)
      capture : capture option;
      multiple : bool;
      on_change : (file_info list -> 'msg) option;
    }
  | Image of { style : Nopal_style.Style.t; src : string; alt : string }
  | Scroll of {
      style : Nopal_style.Style.t;
      attrs : (string * string) list;
          (** Application attributes, carried to the rendered container. *)
      reveal : Reveal.t option;
          (** [None] asks for nothing and costs nothing. *)
      child : 'msg t;
    }
  | Keyed of { key : string; child : 'msg t }
  | Draw of {
      width : float;
      height : float;
      scene : Nopal_scene.Scene.t list;
      on_pointer_move : (pointer_event -> 'msg) option;
      on_click : (pointer_event -> 'msg) option;
      on_pointer_leave : 'msg option;
      on_pointer_down : (pointer_event -> 'msg) option;
      on_pointer_up : (pointer_event -> 'msg) option;
      on_wheel : (wheel_event -> 'msg) option;
      cursor : Nopal_style.Cursor.t option;
      aria_label : string option;
    }
  | Virtual_list of {
      style : Nopal_style.Style.t;
      item_count : Virtual_list.Natural.t;
      row_height : Virtual_list.Positive_float.t;
      container_height : Virtual_list.Positive_float.t;
      scroll_state : Virtual_list.fixed Virtual_list.scroll_state;
      overscan : Virtual_list.Natural.t;
      render_item : int -> 'msg t;
      on_scroll : (float -> 'msg) option;
    }

(** {1 Builders}

    Ergonomic constructors with labelled optional arguments. Application code
    should use these instead of raw variant constructors.

    {2:attribute_precedence Attribute precedence}

    Several builders take both an [?attrs] list and typed fields a backend turns
    into attributes of its own — an input's [placeholder], a radio's [name], a
    picker's [accept], a container's [focusable], a button's [button_type] and
    [disabled]. The rule is:
    {b typed-field derivations beat the [~attrs] list; within the list, the last
       pair wins.}

    Those are two tiers and they are not the same tier. A typed field sits above
    the list, so [attrs] is an escape hatch for keys the DSL does not model, not
    a way to overrule the keys it does. A pair a component puts into that list
    sits inside it, so a caller's later pair of the same name replaces it.

    The second tier is where a component's own attributes travel. A [role], an
    [aria-describedby] or a [data-field] that a component writes is an ordinary
    pair in the list it hands down, so a caller passing the same key through
    that component's attributes replaces it. That is the deliberate escape
    hatch, and the published contract of the components that document it; it is
    not a guarantee that an accessibility association or a test anchor cannot be
    replaced from the call site.

    A derivation that is absent does not erase the key: a picker with no
    [capture], or a control that is not [disabled], leaves whatever [attrs]
    declared for that name standing. Absent means the typed field is saying
    nothing, which is not the same as saying "no attribute".

    Not every derivation has an absent form. An input's [placeholder] is a
    [string] and not a [string option], so an input derives a pair for that key
    on every render and a ["placeholder"] pair in [attrs] is replaced rather
    than left standing, empty default included — as is a radio's required
    [name], a checkbox's, radio's or file picker's ["type"], and a button's
    ["type"], which [button_type] derives as ["button"] when the button names
    none. Uncovering is the behaviour of the derivations that can decline, and
    they decline in one of two shapes. A [bool] cannot say "no attribute":
    [true] asserts the key and [false] emits nothing, so a [false] uncovers a
    caller's pair rather than removing it — a control's ["disabled"], a file
    picker's ["multiple"], an input's ["required"] together with the
    ["aria-required"] it carries, a form's ["novalidate"], and a button's
    ["aria-disabled"] from its [disabled]. An option, or an empty list, asserts
    nothing when absent and uncovers the caller's pair the same way — a file
    picker's ["accept"] and ["capture"], an input's ["autocomplete"] and its
    ["type"] from [input_type], and a form's ["autocomplete"].

    Two renderers enforce this and no more than two, by two different
    mechanisms. The web backend applies the declared list before it writes any
    derivation, so application order is what carries the rule there. The
    structural test renderer appends derived pairs after the declared list and
    resolves every lookup to the last pair, so an overlay is what carries it
    there. The within-list half is the same function in both — {!Attrs.resolve}
    — so there is one definition of what a repeated key answers and nothing for
    the two to drift apart from. {!draw} carries neither a style nor an
    attribute list, so it is structurally outside the rule. A backend nobody has
    written is bound by nothing here: a rule holds where a test holds it.

    The first tier is a shared rule only for the keys the web backend writes as
    real attributes: ["disabled"], ["accept"], ["capture"], ["multiple"],
    ["placeholder"], a radio's ["name"], a control's ["type"], an input's
    ["required"], ["aria-required"] and ["autocomplete"], a form's
    ["autocomplete"] and ["novalidate"], and a button's ["type"] and
    ["aria-disabled"]. Of those, ["disabled"], ["multiple"], ["required"] and
    ["novalidate"] are spelled differently by the two — a presence attribute in
    the browser, a ["true"] pair in the structural tree — so they agree on which
    side wins and not on the value; the rest carry the same value in both, a
    button's ["aria-disabled"] being ["true"] and its ["type"] ["button"] or
    ["submit"]. A checkbox's, radio's or file picker's ["type"] is the
    structural node's tag rather than a pair, while an input's is a pair in
    both. A container's [focusable] is a first-tier derivation in both
    renderers, but each spells it in its own vocabulary — a tab-order attribute
    in the browser, ["focusable"] in the structural tree — so there is no shared
    key to compare. A checkbox's or radio's [checked], an input's or select's
    value, and an option's selection are JS {e properties} in the browser and
    never attributes, so a caller's ["checked"], ["value"] or ["selected"] pair
    in [attrs] lands on the DOM as an ordinary attribute and is not overruled
    there. The structural renderer still overlays those three, as a faithful
    read-out of the typed field, but a structural assertion on them states what
    that renderer answers and not what the browser does.

    {2:submit_contract Submit contract}

    An Enter in an {!input} can be answered by more than one handler, and the
    rule that chooses among them is one sentence:
    {b the nearest handler that accepts the Enter consumes it.} An Enter reaches
    at most one of the three handlers below, and a handler the application
    supplied is never silently dropped. One Enter can still dispatch two
    messages: an Enter deferred to the form is the platform's implicit
    submission, which clicks the form's default button, so that button's
    [on_click] comes first and the form's [on_submit] second.

    The handlers are consulted nearest first. The input's [on_keydown] comes
    first and is consulted for every key; its ['msg option] return is the
    consumption signal. [Some msg] dispatches [msg] and consumes the key, so no
    handler further out sees it; [None] declines it. The input's [on_submit]
    comes second: an Enter that [on_keydown] declined, or any Enter on an input
    with no [on_keydown], dispatches [on_submit]. [on_submit] answers Enter and
    no other key.

    Supplying both handlers on one input is therefore meaningful: [on_keydown]
    answers the keys it cares about and returns [None] for the rest, and an
    Enter it declines still submits. An [on_keydown] that returns [Some] for
    Enter takes the Enter away from [on_submit], which then never fires for it.

    The nearest enclosing {!form}'s [on_submit] comes third. An Enter that
    neither of the input's handlers answered — an Enter on a bare input, or one
    its [on_keydown] declined with no [on_submit] behind it — is deferred to the
    nearest enclosing form, whose implicit submission decides what it dispatches
    (see below). An input with no enclosing form, or inside a form that authors
    no [on_submit], dispatches nothing to the form for that Enter. An input that
    carries its own [on_submit] answers the Enter itself, so the enclosing form
    never sees it: one Enter in that field dispatches the input's message and
    not the form's. "Nearest enclosing" assumes forms do not nest; see {!form}
    for why nesting is unsupported.

    That last case is the cost of the rule, stated rather than hidden: in a form
    where one field carries its own [on_submit], Enter in that field dispatches
    a different message than Enter anywhere else in the form. Pick one level —
    submission on the form, or on each input — and do not mix the two.

    Suppression of the platform default is narrower than consumption. An Enter
    answered by either of the input's own handlers suppresses the default
    action, so the enclosing form does not also submit; Enter is the only key
    that makes a form submit implicitly. A consuming [on_keydown] on any other
    key leaves that key's default in place, so a handler that records every
    keystroke does not stop its own input from receiving text.

    Both renderers take the route from {!Submit_route.of_key}, so the web
    renderer and the structural test renderer answer every keydown alike. What a
    deferred Enter then dispatches is the platform's implicit submission, which
    is outside the route; the web renderer leaves it to the browser and the
    structural renderer models it, so the two answer it alike as Chromium
    answers it (measured). The form's default button is its first submit button
    in tree order — a {!button} typed [Submit], never one that names no type.
    When the form has one and it is enabled, the Enter clicks it: the button's
    [on_click] and then the form's [on_submit] are dispatched. When it is
    [disabled], the Enter dispatches nothing, even if an enabled submit button
    follows it. When the form has no submit button, the Enter submits only a
    form holding a single field that blocks implicit submission, dispatching the
    form's [on_submit]; a form with two such fields dispatches nothing. Every
    {!input} is such a field, whatever its [input_type]; a {!checkbox},
    {!radio}, {!select} or {!file_input} is not. An input whose type a caller
    overrides through [attrs] to a kind the browser does not count, [hidden] for
    instance, is outside the structural renderer's model. *)

val empty : 'msg t
(** An element that renders nothing. *)

val text : string -> 'msg t
(** A text node with no text style. *)

val styled_text : text_style:Nopal_style.Text.t -> string -> 'msg t
(** A text node with an explicit text style. *)

val box :
  ?style:Nopal_style.Style.t ->
  ?interaction:Nopal_style.Interaction.t ->
  ?attrs:(string * string) list ->
  ?focusable:bool ->
  ?on_focus:'msg ->
  ?on_blur:'msg ->
  ?on_pointer_move:(pointer_event -> 'msg) ->
  ?on_pointer_leave:'msg ->
  ?on_pointer_down:(pointer_event -> 'msg) ->
  ?on_pointer_up:(pointer_event -> 'msg) ->
  ?on_wheel:(wheel_event -> 'msg) ->
  'msg t list ->
  'msg t
(** A generic container. Children are laid out according to backend defaults.

    [attrs] carries key-value metadata (e.g. [data-*] attributes, ARIA labels)
    that web backends render as HTML attributes. Non-web backends may ignore
    attributes that have no native equivalent. Prefer [attrs] for test selectors
    and accessibility hints, not for styling or behavior.

    [focusable] places the container in the platform's natural keyboard
    traversal order. It is spelled as a capability rather than as an attribute
    because tab order is behaviour, and because the web spelling of it is a
    detail a native backend has no way to honour; each backend decides how a
    focusable container is reached. It defaults to not focusable, and a
    container that is not focusable can still report focus arriving on a
    focusable descendant.

    [on_focus] and [on_blur] are scoped to the whole subtree, not to the
    container alone. [on_focus] is dispatched when focus arrives at the
    container or at any element inside it from somewhere outside it, and
    [on_blur] when focus leaves the container and everything inside it. Focus
    moving between two elements that are both within the container — including
    between the container itself and one of its own descendants — is neither an
    arrival nor a departure and dispatches nothing, so a panel revealed on
    [on_focus] survives the user reaching a control inside it.

    The consequence of that scoping is that nested containers overlap: focus
    landing inside the inner one is an arrival for the inner container and for
    every focusable-subtree container enclosing it, each of which dispatches its
    own [on_focus]. *)

val row :
  ?style:Nopal_style.Style.t ->
  ?interaction:Nopal_style.Interaction.t ->
  ?attrs:(string * string) list ->
  'msg t list ->
  'msg t
(** A horizontal layout container. *)

val column :
  ?style:Nopal_style.Style.t ->
  ?interaction:Nopal_style.Interaction.t ->
  ?attrs:(string * string) list ->
  'msg t list ->
  'msg t
(** A vertical layout container. *)

val form :
  ?style:Nopal_style.Style.t ->
  ?interaction:Nopal_style.Interaction.t ->
  ?attrs:(string * string) list ->
  ?on_submit:'msg ->
  ?autocomplete:autocomplete_mode ->
  ?novalidate:bool ->
  'msg t list ->
  'msg t
(** A submission group: the children are one form, and an Enter in one of its
    fields can submit it. It is a container like {!box}, laying its children
    down the page unless [style] asks for the other direction. On a backend with
    no native form the group is an ordinary container, and the Enter routing of
    the {{!section-submit_contract} submit contract} still holds.

    When present, [on_submit] is dispatched once per submission, whether an
    Enter in a field deferred to the form or a submit button was pressed.
    Absent, a submission dispatches nothing. Either way a submission never
    navigates away from the application: a form that authors no [on_submit] is
    still submitted by the platform, and its default is cancelled all the same,
    so wrapping fields in a form for its landmark or [autocomplete] alone does
    not turn Enter or a button press into a page reload. [autocomplete] asks the
    platform to offer, or not to offer, remembered values for every field;
    absent, it asks for nothing. [novalidate] skips the platform's own
    constraint validation before a submission, and defaults to [false].

    A {!button} inside a form submits it only when it says so with
    [~button_type:Submit]: clicking it dispatches the button's own [on_click]
    and then the form's [on_submit]. A button that names no type does not
    submit, so a toggle that reveals a password, or a cancel, dispatches its
    [on_click] and nothing else. A [disabled] button dispatches nothing and
    submits nothing.

    A form is exposed to assistive technology as a landmark only once it has an
    accessible name, which travels through [attrs] — an ["aria-label"] pair, for
    instance.

    Do not nest one form inside another. Nested forms are invalid HTML, whose
    recovery each browser decides for itself, so a nested form has no stable
    meaning to render. Nothing rejects one — the constraint is documented, not
    enforced — and the submit contract's "nearest enclosing form" assumes there
    is at most one. *)

val button :
  ?style:Nopal_style.Style.t ->
  ?interaction:Nopal_style.Interaction.t ->
  ?attrs:(string * string) list ->
  ?button_type:button_type ->
  ?disabled:bool ->
  ?on_click:'msg ->
  ?on_dblclick:'msg ->
  'msg t ->
  'msg t
(** A clickable button. The child element serves as the button label.
    [button_type] says whether activating it submits the enclosing {!form};
    absent, it is [Push], so a button submits only when it says [Submit].
    [disabled], [false] when absent, keeps the button focusable and makes it
    inert: activating it dispatches nothing and submits nothing, and assistive
    technology announces it as disabled. That differs from the [disabled] of
    {!checkbox}, {!radio} and {!select}, which the web renders as the native
    attribute and so also takes the control out of the tab order. Both fields
    are typed, so a ["type"] pair in [attrs] never takes effect, and an
    ["aria-disabled"] pair only while [disabled] is [false]; see {!form} for the
    full rule. [disabled] changes no styling; pass a [~style] for the disabled
    look. Known limitation on the web backend: a disabled button's click is
    cancelled but still propagates to an ancestor's [on_click], unlike a native
    [disabled] button, which fires no click event at all. *)

val input :
  ?style:Nopal_style.Style.t ->
  ?interaction:Nopal_style.Interaction.t ->
  ?attrs:(string * string) list ->
  ?placeholder:string ->
  ?on_change:(string -> 'msg) ->
  ?on_submit:'msg ->
  ?on_focus:'msg ->
  ?on_blur:'msg ->
  ?on_keydown:(string -> 'msg option) ->
  ?required:bool ->
  ?autocomplete:string ->
  ?input_type:input_type ->
  string ->
  'msg t
(** A text input. The positional argument is the current value. [on_focus] is
    dispatched when the input takes focus and [on_blur] when it loses it; an
    input holds no children, so neither edge has a subtree to account for.
    [on_keydown] receives the key name exactly as the platform reports it, with
    no ["Ctrl+"] or ["Shift+"] prefix added for the modifiers held during the
    event — unlike the window-level key subscriptions, whose strings fold those
    modifiers into the key name. How [on_keydown] and [on_submit] share an Enter
    — [on_keydown] first, a [Some] consuming it, a declined Enter going on to
    [on_submit] — is the {{!section-submit_contract} submit contract}.

    [required] marks the field as one a submission needs, both to the platform's
    own constraint validation and to assistive technology; it defaults to
    [false]. [autocomplete] is the per-field token the platform reads to offer a
    remembered value — ["username"], ["current-password"], ["email"] and the
    rest of that open set, passed through as written. [input_type] names the
    kind of text the field takes. Each of the three is a typed field above
    [attrs], so a field that authors one replaces an [attrs] pair for the same
    key, and a field that authors none leaves that pair standing; see
    {{!section-attribute_precedence} attribute precedence}. A caller that moves
    from an [attrs] pair to the typed field finds the pair stops taking effect,
    which is the rule working. *)

val checkbox :
  ?style:Nopal_style.Style.t ->
  ?interaction:Nopal_style.Interaction.t ->
  ?attrs:(string * string) list ->
  ?disabled:bool ->
  ?on_toggle:(bool -> 'msg) ->
  bool ->
  'msg t
(** A checkbox. The positional argument is the current [checked] state. *)

val radio :
  ?style:Nopal_style.Style.t ->
  ?interaction:Nopal_style.Interaction.t ->
  ?attrs:(string * string) list ->
  ?checked:bool ->
  ?disabled:bool ->
  ?on_select:'msg ->
  name:string ->
  unit ->
  'msg t
(** A radio button. [name] groups radios so only one is selected at a time. *)

val select :
  ?style:Nopal_style.Style.t ->
  ?interaction:Nopal_style.Interaction.t ->
  ?attrs:(string * string) list ->
  ?disabled:bool ->
  ?on_change:(string -> 'msg) ->
  selected:string ->
  select_option list ->
  'msg t
(** A dropdown select. [selected] is the currently chosen option value. *)

val select_option : ?disabled:bool -> value:string -> string -> select_option
(** [select_option ~value label] creates a select option. *)

val file_input :
  ?style:Nopal_style.Style.t ->
  ?interaction:Nopal_style.Interaction.t ->
  ?attrs:(string * string) list ->
  ?accept:string list ->
  ?capture:capture ->
  ?multiple:bool ->
  ?on_change:(file_info list -> 'msg) ->
  unit ->
  'msg t
(** A native file picker.

    [accept] lists user-agent hints (MIME types or extensions) narrowing what
    the picker offers; the empty list — the default — means unrestricted. It is
    only a hint: the selection is never validated against it, so a caller that
    needs a guarantee must check [mime] or the bytes itself.

    [capture] is a mobile-webview camera preference, inert on desktop.
    [multiple] defaults to [false].

    [on_change] receives the whole selection. It also fires with [[]] when the
    user clears the picker, so a model tracking the selection is never left
    stale. Elements carry no bytes: each [file_info] carries an opaque [blob_id]
    that only a [_web] backend can resolve.

    The bytes behind a [blob_id] are owned by the application, not by the
    element and not by the mount that rendered it: they live for the page
    session and are released only by an explicit call to the web blob store's
    [remove] or [clear]. Superseding a selection does not release the handle it
    held.

    [File_input] has no label of its own to slugify, so supply any test anchor
    through [attrs] at the call site — and any accessible name, since the DSL
    has no label element to associate one with.

    [attrs] is an escape hatch for keys this builder does not model, and the
    typed arguments above outrank it wherever they assert a value: a [type], or
    an [accept], [capture] or [multiple] the arguments configure, is written
    over whatever [attrs] declared for that name, on the initial render and on
    every reconcile that leaves [attrs] unchanged. Spelling one of those keys
    through [attrs] is therefore pointless while the typed argument speaks — it
    stands only for as long as the argument declines, which [type] never does.
*)

val image :
  ?style:Nopal_style.Style.t -> src:string -> alt:string -> unit -> 'msg t
(** An image element. [src] and [alt] are required. *)

val scroll :
  ?style:Nopal_style.Style.t ->
  ?attrs:(string * string) list ->
  ?reveal:Reveal.t ->
  'msg t ->
  'msg t
(** A scrollable container wrapping a single child.

    [reveal] names a keyed descendant that must be brought into view, and the
    alignment it should come to rest under. It is a request, not an invariant: a
    backend acts on it when it changes and at no other time, so a reader who
    scrolls away from the named child keeps their position. See {!Reveal} for
    the whole rule and its consequences. Omitting the argument asks for nothing,
    and a container that asks for nothing behaves exactly as it did before the
    argument existed.

    [attrs] are application attributes, carried to the rendered container as
    written. They are the container's own identity, which is what lets a
    platform request name it directly instead of reaching it through a wrapper
    around it; an [id] is the spelling a relative-scroll request resolves
    against. The names and values are opaque application strings, never
    interpreted here, and the list is compared in order, so two containers
    carrying the same pairs in a different order are not equal. Do not put
    [style] or [class] in it: both belong to the renderer, and a [style] pair
    here overwrites the whole inline style the renderer wrote on the container —
    including the overflow that makes it scroll — so the container silently
    stops scrolling. Omitting the argument carries none, and a container
    carrying none renders exactly as it did before the argument existed. *)

val keyed : string -> 'msg t -> 'msg t
(** [keyed key child] wraps [child] with a stable identity key.

    That key is the child's identity for two purposes: reconciling a list across
    renders, and naming the child a scroll container asks to reveal. Keys must
    therefore be unique within the container that holds them; where a key is
    repeated, the first match in document order is the one that resolves. Keys
    are opaque application strings and are compared and resolved as written, so
    any punctuation is safe to use. *)

val draw :
  ?on_pointer_move:(pointer_event -> 'msg) ->
  ?on_click:(pointer_event -> 'msg) ->
  ?on_pointer_leave:'msg ->
  ?on_pointer_down:(pointer_event -> 'msg) ->
  ?on_pointer_up:(pointer_event -> 'msg) ->
  ?on_wheel:(wheel_event -> 'msg) ->
  ?cursor:Nopal_style.Cursor.t ->
  ?aria_label:string ->
  width:float ->
  height:float ->
  Nopal_scene.Scene.t list ->
  'msg t
(** [draw ~width ~height scene] creates a 2D drawing canvas element. The scene
    list describes shapes rendered onto the canvas. Optional pointer callbacks
    receive canvas-local coordinates. *)

val virtual_list :
  ?style:Nopal_style.Style.t ->
  ?on_scroll:(float -> 'msg) ->
  item_count:Virtual_list.Natural.t ->
  row_height:Virtual_list.Positive_float.t ->
  container_height:Virtual_list.Positive_float.t ->
  scroll_state:Virtual_list.fixed Virtual_list.scroll_state ->
  overscan:Virtual_list.Natural.t ->
  (int -> 'msg t) ->
  'msg t
(** [virtual_list ~item_count ~row_height ~container_height ~scroll_state
     ~overscan render_item] creates a virtualized list that renders only the
    visible window of items. [render_item] is called with each visible index.
    [on_scroll] fires with the new scroll offset when the user scrolls. *)

(** {1 Transforms} *)

val map : ('a -> 'b) -> 'a t -> 'b t
(** [map f element] transforms all messages in [element] from type ['a] to type
    ['b]. Used for embedding child components with different message types. *)

(** {1 Responsive combinators} *)

val responsive :
  Viewport.t ->
  compact:'msg t ->
  ?medium:'msg t ->
  expanded:'msg t ->
  unit ->
  'msg t
(** [responsive vp ~compact ?medium ~expanded ()] selects a subtree based on
    [vp]'s size class. When [~medium] is omitted, Compact and Medium both use
    the [~compact] branch. *)

val responsive_style :
  Viewport.t ->
  compact:Nopal_style.Style.t ->
  ?medium:Nopal_style.Style.t ->
  expanded:Nopal_style.Style.t ->
  unit ->
  Nopal_style.Style.t
(** [responsive_style vp ~compact ?medium ~expanded ()] selects a style based on
    [vp]'s size class. Same fallback semantics as [responsive]. *)

(** {1 Comparison} *)

val equal : 'msg t -> 'msg t -> bool
(** [equal a b] tests structural equality of two element trees. Data fields
    (strings, styles, dimensions) are compared structurally. Message payloads
    (e.g. [on_click]) and function handlers (e.g. [on_change] and the [Draw]
    pointer handlers) are compared by physical equality, so [equal] is total and
    never raises on closure-valued ['msg] payloads. *)

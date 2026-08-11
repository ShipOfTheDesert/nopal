(** Shared fixtures for the suites that drive the browser image pipeline against
    image_pipeline_shim.js.

    Every suite in test/unit/nopal_image_web needs the same handful of things:
    reach the shim, clear it, state the decoded size, inject one platform
    failure, drain the deferred stages, and read back what was recorded. They
    live here rather than in each suite so that a change to what the shim
    records is one edit, and so that two suites cannot silently disagree about
    what "reset" means. *)

(** {1 Reaching the shim} *)

val reset : unit -> unit
(** Clears everything the shim recorded, empties its queue of deferred
    continuations, and turns every injection switch off. Every case calls this
    before stating its own fixture: the shim's decoded size starts at 0 x 0, so
    a case that forgets fails loudly rather than inheriting a plausible size. *)

val set_source : width:int -> height:int -> unit
(** The size the next decode yields. The pipeline never supplies this, so a
    pipeline echoing its own configuration cannot match it. *)

val flush : unit -> unit
(** Runs every continuation the shim has parked, and any parked while draining.

    The decode and the encode answer on a later turn, as they do in a browser,
    so a pipeline started with {!run_pipeline} has not finished when [Task.run]
    returns. Raises if the queue feeds itself rather than hanging. *)

(** {1 Injecting failures} *)

val inject_failure : string -> unit
(** [inject_failure stage] makes one stage fail the way the platform fails it:
    ["decode"] rejects, ["context"] hands out no drawing context, ["encode"]
    produces nothing, ["pixels"] refuses the read. *)

val inject_refusal : string -> unit
(** [inject_refusal stage] makes one stage refuse synchronously, carrying
    {!refusal} — a sentence naming no stage, so an implementation reading the
    message could not tell two stages apart. Accepts ["decode"], ["bitmap"],
    ["context"], ["encode"] and ["pixels"]. *)

val starve_context_for_width : int -> unit
(** [starve_context_for_width w] makes [getContext] return no context for the
    canvas of width [w] and only that one. The pipeline allocates two canvases
    at two different sizes, so this is what reaches the second pass's failure: a
    switch starving every canvas can only ever exercise whichever comes first.
*)

val reject_decode_with : string -> unit
(** [reject_decode_with shape] chooses what an injected decode rejection
    carries: ["error"] (the default), ["nothing"], ["bare-string"] or
    ["nonstring-message"]. A rejected promise is not required to carry an
    [Error], and the binding that turns one into a sentence has an arm per
    shape. *)

val refusal : unit -> string
(** The sentence every injected synchronous refusal carries, read from the shim
    so an assertion cannot drift from what was injected. *)

val rejection : unit -> string
(** The words an injected decode rejection carries, in whichever shape
    {!reject_decode_with} selected. Read from the shim for the same reason as
    {!refusal}. *)

(** {1 Reading back what the shim recorded} *)

val calls : unit -> string list
(** The stages the pipeline called, in order. *)

val draws : unit -> (int * int) list
(** The target [(width, height)] of each draw, in order. This is what
    distinguishes the upload pass from the metric pass. *)

val encode_mimes : unit -> string list
(** The media type each encode was asked for, in order. *)

val first_encode : string -> Jv.t
(** [first_encode field] is one field of the first recorded encode call. Fails
    the case when nothing was encoded. *)

val pixel_reads : unit -> int
(** How many pixel reads completed. A read that refused is not counted: it
    crossed nothing. *)

val releases : unit -> int
(** How many times a decoded image was closed. *)

(** {1 Fixtures} *)

val capture_config :
  max_edge:int ->
  metric_edge:int ->
  quality:float ->
  format:Nopal_image.Config.format ->
  Nopal_image.Config.t
(** A configuration, or a failed case explaining why the fixture was rejected.
    Total: never reaches for a partial standard-library call. *)

val fixture_config : unit -> Nopal_image.Config.t
(** The configuration every failure case shares, so an arm cannot pass because
    its case picked friendlier numbers than its siblings. 1000 x 750 under its
    900 pixel cap downscales; the sharpness pass runs at 100. *)

val stored_source : unit -> string
(** A handle for bytes standing in for what a file input would have registered.
    The contents are never decoded — the shim's source is what a decode yields —
    so any bytes will do. *)

val released_handle : unit -> string
(** A handle the store no longer resolves. Obtained from the store and then
    released rather than written as a literal: a handle is only ever something
    the store issued, so even the unknown-handle fixture is one it issued. *)

val blob_under : string -> Brr.Blob.t
(** [blob_under handle] is what the store holds, or a failed case naming the
    handle it does not hold. *)

(** {1 Driving the pipeline} *)

val run_pipeline :
  blob_id:string ->
  config:Nopal_image.Config.t ->
  (Nopal_image.Processing.result_info, Nopal_image.Processing.error) result
(** Runs the pipeline, drains the deferred stages and answers its single
    outcome. Fails the case when the pipeline delivered no outcome or more than
    one: an outcome count is what separates a task that never answered from one
    that answered twice, and both are failures this suite exists to catch. *)

val processed :
  (Nopal_image.Processing.result_info, Nopal_image.Processing.error) result ->
  Nopal_image.Processing.result_info
(** The processed image, or a failed case carrying the failure instead. *)

val failure_of :
  (Nopal_image.Processing.result_info, Nopal_image.Processing.error) result ->
  Nopal_image.Processing.error
(** The failure, or a failed case naming the handle that was produced instead.
*)

val stage_of_error : Nopal_image.Processing.error -> string
(** The stage an error blames, without its description, so a case asserts which
    stage was held responsible rather than how the failure was worded. *)

val detail_of_error : Nopal_image.Processing.error -> string
(** The description an error carries, whichever arm it is. *)

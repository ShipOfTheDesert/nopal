(** Whether a control is painted, or present but unseen.

    A visually hidden control is still the platform's control: it keeps its
    focus, its keyboard operation, its grouping and its place in the
    accessibility tree. Only its paint and its layout space go.

    Platform-agnostic: no CSS, DOM or browser concepts here. Each backend hides
    the control by whatever means its target has that keeps the control
    operable. *)

type t =
  | Visible  (** Painted and laid out as the platform draws it. *)
  | Visually_hidden
      (** Not painted and given no layout space, yet still focusable, operable
          and announced. A user who forces their system colours sees the control
          again, drawn by the platform, so its state stays perceivable when
          backgrounds are stripped. *)

val equal : t -> t -> bool
(** Structural equality: each arm equals only itself. *)

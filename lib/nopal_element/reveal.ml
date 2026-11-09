type align = Nearest | Start | Center | End_
type t = { key : string; align : align }

let nearest key = { key; align = Nearest }
let start key = { key; align = Start }
let center key = { key; align = Center }
let end_ key = { key; align = End_ }

let align_token = function
  | Nearest -> "nearest"
  | Start -> "start"
  | Center -> "center"
  | End_ -> "end"

(* Enumerated rather than compared with [=], so a fifth alignment is a compile
   error here instead of a constructor that silently reports itself unequal to
   itself. The second row is spelled out for the same reason a catch-all is not:
   it covers exactly today's constructors and no future one. *)
let equal_align a b =
  match (a, b) with
  | Nearest, Nearest
  | Start, Start
  | Center, Center
  | End_, End_ ->
      true
  | (Nearest | Start | Center | End_), (Nearest | Start | Center | End_) ->
      false

let equal a b = String.equal a.key b.key && equal_align a.align b.align

(* All four combinations are written out: a [| _, None] row would keep
   compiling if the option ever became a variant of its own, and the two false
   arms it merges are false for different reasons — there is nothing to reveal
   in one and nothing being asked in the other. *)
let should_reveal ~previous ~next =
  match (previous, next) with
  | None, None -> false
  | Some _, None -> false
  | None, Some _ -> true
  | Some p, Some n -> not (equal p n)

let all_finite measurements = List.for_all Float.is_finite measurements

(* Every measurement below lies along one axis and counts from the start edge of
   the container's scrollable content, so nothing here knows whether it is
   working on a height or a width.

   The offsets at which a child that fits is fully visible form the closed
   interval [child_end -. viewport, child_start]: an offset at or before the
   child's start edge keeps that edge in view, and one at or after its end edge
   less the visible extent keeps the end edge in view. Nearest is the current
   offset moved the least distance into that interval, which is a clamp. A
   child larger than the visible extent never reaches this function; see
   [oversized_offset]. *)
let nearest_offset ~scroll_offset ~viewport ~child_start ~child_end =
  Float.min child_start (Float.max (child_end -. viewport) scroll_offset)

let aligned_offset ~scroll_offset ~viewport ~child_start ~child_extent ~align =
  let child_end = child_start +. child_extent in
  match align with
  | Nearest -> nearest_offset ~scroll_offset ~viewport ~child_start ~child_end
  | Start -> child_start
  | Center -> child_start +. ((child_extent -. viewport) /. 2.0)
  | End_ -> child_end -. viewport

(* A child's edges come from fractional rects while the visible extent and
   content come from rounded client extents, so a row that fills the visible
   area can miss it by a sub-pixel amount. An edge within [cover_tolerance]
   (strictly less than it) of the visible area's edge, or beyond it, counts as
   covering; edges exactly flush also count. Only this test is tolerant: the
   fully-visible clamp in [nearest_offset] stays exact. *)
let cover_tolerance = 1.0

let covers_viewport ~scroll_offset ~viewport ~child_start ~child_end =
  Float.compare (child_start -. scroll_offset) cover_tolerance < 0
  && Float.compare (scroll_offset +. viewport -. child_end) cover_tolerance < 0

(* A child larger than the visible extent cannot satisfy any alignment, so a
   named alignment shows its beginning rather than scrolling past it in pursuit
   of an edge the container can never reach. Nearest asks only for the child to
   be seen, and a child that already fills the visible area from edge to edge is
   seen as fully as it can be, so the current offset is kept; one that does not
   fill it takes the same start-edge fallback as the named alignments. *)
let oversized_offset ~scroll_offset ~viewport ~child_start ~child_extent ~align
    =
  match align with
  | Nearest ->
      let child_end = child_start +. child_extent in
      if covers_viewport ~scroll_offset ~viewport ~child_start ~child_end then
        scroll_offset
      else child_start
  | Start
  | Center
  | End_ ->
      child_start

let offset_for ~scroll_offset ~viewport ~content ~child_start ~child_extent
    ~align =
  if
    not
      (all_finite
         [ scroll_offset; viewport; content; child_start; child_extent ])
  then None
  else
    let target =
      if Float.compare child_extent viewport > 0 then
        oversized_offset ~scroll_offset ~viewport ~child_start ~child_extent
          ~align
      else
        aligned_offset ~scroll_offset ~viewport ~child_start ~child_extent
          ~align
    in
    let max_scroll = Float.max 0.0 (content -. viewport) in
    let clamped = Float.min max_scroll (Float.max 0.0 target) in
    if Float.equal clamped scroll_offset then None else Some clamped

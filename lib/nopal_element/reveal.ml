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

(* The offsets at which the child is fully visible form the closed interval
   [child_bottom -. viewport_height, child_top]: an offset at or below the child's
   top edge keeps its top in view, and one at or above its bottom edge less the
   visible height keeps its bottom in view. Nearest is the current offset moved
   the least distance into that interval, which is a clamp. When the child is
   taller than the visible height the interval is empty and the clamp collapses
   onto its upper end, the child's top edge, which is the same fallback the named
   alignments take below. *)
let nearest_offset ~scroll_offset ~viewport_height ~child_top ~child_bottom =
  Float.min child_top
    (Float.max (child_bottom -. viewport_height) scroll_offset)

let aligned_offset ~scroll_offset ~viewport_height ~child_top ~child_height
    ~align =
  let child_bottom = child_top +. child_height in
  match align with
  | Nearest ->
      nearest_offset ~scroll_offset ~viewport_height ~child_top ~child_bottom
  | Start -> child_top
  | Center -> child_top +. ((child_height -. viewport_height) /. 2.0)
  | End_ -> child_bottom -. viewport_height

let offset_for ~scroll_offset ~viewport_height ~content_height ~child_top
    ~child_height ~align =
  if
    not
      (all_finite
         [
           scroll_offset;
           viewport_height;
           content_height;
           child_top;
           child_height;
         ])
  then None
  else
    (* A child that does not fit cannot satisfy any alignment, so all four show
       its beginning rather than scrolling past it in pursuit of an edge the
       container can never reach. Nearest already lands there on its own; the
       named alignments would each overshoot. *)
    let target =
      if Float.compare child_height viewport_height > 0 then child_top
      else
        aligned_offset ~scroll_offset ~viewport_height ~child_top ~child_height
          ~align
    in
    let max_scroll = Float.max 0.0 (content_height -. viewport_height) in
    let clamped = Float.min max_scroll (Float.max 0.0 target) in
    if Float.equal clamped scroll_offset then None else Some clamped

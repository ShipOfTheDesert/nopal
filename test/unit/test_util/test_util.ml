let string_contains s ~sub =
  let len_s = String.length s in
  let len_sub = String.length sub in
  if len_sub > len_s then false
  else
    let rec check i =
      if i > len_s - len_sub then false
      else if String.sub s i len_sub = sub then true
      else check (i + 1)
    in
    check 0

open Nopal_test.Test_renderer

let pp_selector fmt sel =
  match sel with
  | By_tag t -> Format.fprintf fmt "By_tag %S" t
  | By_text t -> Format.fprintf fmt "By_text %S" t
  | By_attr (k, v) -> Format.fprintf fmt "By_attr (%S, %S)" k v
  | First_child -> Format.fprintf fmt "First_child"
  | Nth_child n -> Format.fprintf fmt "Nth_child %d" n

let error_testable =
  Alcotest.testable
    (fun fmt e ->
      match e with
      | Not_found sel -> Format.fprintf fmt "Not_found (%a)" pp_selector sel
      | No_handler { tag; event } ->
          Format.fprintf fmt "No_handler { tag = %S; event = %S }" tag event)
    ( = )

let node_pp fmt node =
  let rec aux indent = function
    | Empty -> Format.fprintf fmt "%sEmpty" indent
    | Text { content; _ } -> Format.fprintf fmt "%sText %S" indent content
    | Element { tag; attrs; children; _ } ->
        Format.fprintf fmt "%sElement { tag = %S; attrs = [%s]; children = ["
          indent tag
          (String.concat "; "
             (List.map (fun (k, v) -> Printf.sprintf "(%S, %S)" k v) attrs));
        List.iter
          (fun c ->
            Format.fprintf fmt "\n";
            aux (indent ^ "  ") c)
          children;
        Format.fprintf fmt "] }"
  in
  aux "" node

let node_equal a b =
  let rec eq a b =
    match (a, b) with
    | Empty, Empty -> true
    | ( Text { content = s1; text_style = ts1 },
        Text { content = s2; text_style = ts2 } ) ->
        String.equal s1 s2 && Option.equal Nopal_style.Text.equal ts1 ts2
    | ( Element { tag = t1; style = s1; attrs = a1; children = c1; _ },
        Element { tag = t2; style = s2; attrs = a2; children = c2; _ } ) ->
        String.equal t1 t2
        && Nopal_style.Style.equal s1 s2
        && a1 = a2
        && List.equal eq c1 c2
    | _ -> false
  in
  eq a b

let node_testable = Alcotest.testable node_pp node_equal

let check_node msg expected actual =
  Alcotest.check node_testable msg expected actual

let count_unique eq lst =
  List.length
    (List.filteri
       (fun i x ->
         let rec first_index j = function
           | [] -> j
           | hd :: tl -> if eq x hd then j else first_index (j + 1) tl
         in
         first_index 0 lst = i)
       lst)

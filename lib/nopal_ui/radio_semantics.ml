module E = Nopal_element.Element

type t = { id : string option; label : string; name : string option }

let make ~id ~label ~name = { id; label; name }

let group_name group =
  match group.name with
  | Some n -> n
  | None -> Slug.slugify group.label

let control_id group = Slug.derive_id ~explicit:group.id ~label:group.label ()

let group_label_id group =
  Slug.derive_id ~explicit:group.id ~label:group.label ~suffix:"label" ()

let option_id group ~value =
  Slug.derive_id ~explicit:group.id ~label:group.label
    ~suffix:(Slug.slugify value) ()

let option_label_id group ~value =
  Slug.derive_id
    ~explicit:(Some (option_id group ~value))
    ~label:"" ~suffix:"label" ()

type naming = Named_by_visible_label | Named_by_aria_label

let group_attrs group ~naming ~attrs =
  let naming_attr =
    match naming with
    | Named_by_visible_label -> ("aria-labelledby", group_label_id group)
    | Named_by_aria_label -> ("aria-label", group.label)
  in
  [ ("role", "radiogroup"); naming_attr; ("id", control_id group) ] @ attrs

let option_radio ?style ?interaction group ~value ~selected ~disabled
    ~presentation ~on_select =
  let on_select =
    if disabled then None else Option.map (fun f -> f value) on_select
  in
  let name = group_name group in
  E.radio ?style ?interaction
    ~attrs:
      [
        ("id", option_id group ~value);
        ("aria-labelledby", option_label_id group ~value);
        ("data-field", name);
      ]
    ~checked:(String.equal selected value)
    ~disabled ~presentation ?on_select ~name ()

let option_label ?style group ~value children =
  E.label ?style
    ~attrs:[ ("id", option_label_id group ~value) ]
    ~control_id:(option_id group ~value) children

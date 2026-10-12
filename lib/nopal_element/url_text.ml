let is_control c = Char.code c < 0x20 || Char.code c = 0x7f

let has_control_or_surrounding_space input =
  String.exists is_control input
  || String.starts_with ~prefix:" " input
  || String.ends_with ~suffix:" " input

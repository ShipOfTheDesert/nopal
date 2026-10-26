let l = Nopal_style.Style.default_layout

let _main : Nopal_style.Style.layout list =
  [
    { l with main_align = Some Start };
    { l with main_align = Some Center };
    { l with main_align = Some End_ };
    { l with main_align = Some Space_between };
  ]

let _cross : Nopal_style.Style.layout list =
  [
    { l with cross_align = Some Start };
    { l with cross_align = Some Center };
    { l with cross_align = Some End_ };
    { l with cross_align = Some Stretch };
  ]

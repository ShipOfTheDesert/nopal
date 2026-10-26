A font stack built without a last-resort generic does not type-check.

  $ ocamlfind ocamlc -package nopal_style -c snippet.ml 2> err
  [2]
  $ grep -c 'last_resort:Nopal_style.Font.Generic.t' err
  1

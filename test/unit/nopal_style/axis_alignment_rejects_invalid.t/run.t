Each axis accepts only the values the platform renders as written.

Space_between across the axis does not type-check:

  $ ocamlfind ocamlc -package nopal_style -c cross_space_between.ml 2> cross.err
  [2]
  $ grep -c 'constructor.*Space_between.*Style\.cross_align' cross.err
  1

Stretch along the axis does not type-check:

  $ ocamlfind ocamlc -package nopal_style -c main_stretch.ml 2> main.err
  [2]
  $ grep -c 'constructor.*Stretch.*Style\.align' main.err
  1

Every remaining value on each axis, written the same way, compiles:

  $ ocamlfind ocamlc -package nopal_style -c valid.ml

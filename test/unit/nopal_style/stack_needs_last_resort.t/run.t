A font stack built without a last-resort generic does not type-check.

  $ ocamlfind ocamlc -package nopal_style -c snippet.ml
  File "snippet.ml", line 2, characters 2-60:
  2 |   Nopal_style.Font.stack [ Nopal_style.Font.Custom "Geist" ]
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Error: This expression has type
           "last_resort:Nopal_style.Font.Generic.t -> Nopal_style.Font.stack"
         but an expression was expected of type "Nopal_style.Font.stack"
    Hint: This function application is partial,
    maybe some arguments are missing.
  [2]

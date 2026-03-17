(lang dune 3.20)

(name nopal)

(generate_opam_files true)

(source
 (github ShipOfTheDesert/nopal))

(authors "Author Name <author@example.com>")

(maintainers "Maintainer Name <maintainer@example.com>")

(license LICENSE)

(documentation https://url/to/documentation)

(package
 (name nopal)
 (synopsis "A short synopsis")
 (description "A longer description")
 (depends
  (alcotest
   (and
    (>= 1.9.1)
    :with-test))
  ocaml)
 (tags
  ("add topics" "to describe" your project)))

(package
 (name nopal_style)
 (synopsis "Typed style properties for Nopal")
 (depends
  (alcotest
   (and
    (>= 1.9.1)
    :with-test))
  ocaml))

(package
 (name nopal_scene)
 (synopsis "Pure scene description types for Nopal")
 (depends
  (alcotest
   (and
    (>= 1.9.1)
    :with-test))
  ocaml
  nopal_style))

(package
 (name nopal_draw)
 (synopsis "2D drawing DSL for Nopal")
 (depends
  (alcotest
   (and
    (>= 1.9.1)
    :with-test))
  ocaml
  nopal_scene
  nopal_style))

(package
 (name nopal_element)
 (synopsis "Pure element description types for Nopal")
 (depends
  (alcotest
   (and
    (>= 1.9.1)
    :with-test))
  ocaml
  nopal_scene
  nopal_style))

(package
 (name nopal_mvu)
 (synopsis "MVU architecture core for Nopal")
 (depends
  (alcotest
   (and
    (>= 1.9.1)
    :with-test))
  ocaml
  nopal_element))

(package
 (name nopal_runtime)
 (synopsis "Platform-agnostic MVU runtime for Nopal")
 (depends
  (alcotest
   (and
    (>= 1.9.1)
    :with-test))
  ocaml
  nopal_mvu
  nopal_element
  lwd))

(package
 (name nopal_router)
 (synopsis "Type-safe bidirectional router for Nopal")
 (depends
  (alcotest
   (and
    (>= 1.9.1)
    :with-test))
  ocaml
  nopal_mvu))

(package
 (name nopal_test)
 (synopsis "Pure structural test renderer for Nopal")
 (depends
  (alcotest
   (and
    (>= 1.9.1)
    :with-test))
  ocaml
  nopal_element
  nopal_style
  nopal_mvu))

(package
 (name nopal_charts)
 (synopsis "Composable, interactive chart library for Nopal")
 (depends
  (alcotest
   (and
    (>= 1.9.1)
    :with-test))
  ocaml
  nopal_draw
  nopal_element
  nopal_style))

(package
 (name nopal_http)
 (synopsis "Pure HTTP types for Nopal")
 (depends
  (alcotest
   (and
    (>= 1.9.1)
    :with-test))
  ocaml
  nopal_mvu))

(package
 (name nopal_web)
 (synopsis "Web renderer backend for Nopal")
 (depends
  (alcotest
   (and
    (>= 1.9.1)
    :with-test))
  ocaml
  nopal_runtime
  nopal_element
  nopal_style
  nopal_draw
  nopal_mvu
  nopal_router
  lwd
  brr
  js_of_ocaml))

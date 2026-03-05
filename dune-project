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
 (name nopal_element)
 (synopsis "Pure element description types for Nopal")
 (depends
  (alcotest
   (and
    (>= 1.9.1)
    :with-test))
  ocaml))

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

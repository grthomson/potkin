#lang info

(define collection 'multi)
(define deps '("base" "redex-lib"))
(define build-deps '("rackunit-lib"))
(define test-omit-paths
  '("examples/dsl-running-factorisation.rkt"
    "examples/dsl-open-context.rkt"
    "examples/dsl-hypersequent.rkt"))
(define pkg-desc "Executable CK/hypersequent proof-workflow kernel")
(define version "0.1.0")
(define pkg-authors '(gavin))

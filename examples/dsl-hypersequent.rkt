#lang racket/base

(require potkin)

(define-formula-signature L
  #:atoms [S T])

;; This is one whole boundary with three displayed components.  The two
;; [] => [S] components are separate occurrences, and the first component
;; also retains two occurrences of S in its left formula multiset.
(define Hmulti
  (hseq L
    (seq L [S S] => [T])
    (seq L [] => [S])
    (seq L [] => [S])))

(define-rule-signature Rules
  [ground #:kind material #:arity 0])

(define-occurrence b-multi
  #:type ground
  #:instance '(multi-component-with-multiplicity)
  #:premises []
  #:conclusion Hmulti)

(define-calculus K
  #:language L
  #:rules Rules
  #:occurrences [b-multi])

(define-proof multi-proof
  #:in K
  #:root Hmulti
  b-multi)

(write-analysis (analyze-derivation multi-proof))

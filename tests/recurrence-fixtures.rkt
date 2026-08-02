#lang racket/base

(require "../potkin/kernel.rkt"
         "hopf-fixtures.rkt")

(provide return-boundary
         return-calculus
         return-calculus/clone
         return-Box
         return-g
         return-C
         return-C2
         return-C3
         return-C/clone
         return-branching-context
         return-side-context
         return-side-context-squared
         colour-G
         colour-H
         colour-G-from-H-occurrence
         colour-H-loop-occurrence
         colour-H-from-G-occurrence
         colour-G-ground-occurrence
         colour-G-with-side-occurrence
         colour-calculus
         G-first-via-repeated-H
         G-first-with-off-spine-G
         recurrence-component-boundary
         split-incidence
         merge-incidence
         swap-incidence
         split-occurrence
         merge-occurrence
         swap-occurrence
         opaque-recurrence-occurrence
         component-recurrence-calculus
         split-context
         merge-context
         swap-context
         opaque-recurrence-context)

;; The established one-colour g/u/b fixture supplies the smallest useful CK
;; carrier.  These are isolated checked presentations used by recurrence tests;
;; the global degree-four generator is deliberately left untouched.
(define return-boundary hopf-S)
(define return-calculus hopf-calculus)
(define return-calculus/clone
  (make-equipped-calculus (calculus-occurrences return-calculus)))

(define return-Box (identity-context return-calculus return-boundary))
(define return-g
  (validate-candidate return-calculus hopf-g-raw #:expected return-boundary))
(define return-C
  (validate-candidate
   return-calculus (hopf-u-raw raw-hole) #:expected return-boundary))
(define return-C2
  (validate-candidate
   return-calculus
   (hopf-u-raw (hopf-u-raw raw-hole))
   #:expected return-boundary))
(define return-C3
  (validate-candidate
   return-calculus
   (hopf-u-raw (hopf-u-raw (hopf-u-raw raw-hole)))
   #:expected return-boundary))
(define return-C/clone
  (validate-candidate
   return-calculus/clone (hopf-u-raw raw-hole) #:expected return-boundary))

;; The cut family of b(u(Box),g) contains algebraic endpoints, the recursive
;; return cut (1), the off-spine cut (2), and the genuine multicut (1 2).
(define return-branching-context
  (validate-candidate
   return-calculus
   (hopf-b-raw (hopf-u-raw raw-hole) hopf-g-raw)
   #:expected return-boundary))

;; Repeating b(Box,g) makes the side-evidence forest contain two equal g
;; occurrences.  They remain a multiset rather than collapsing to one factor.
(define return-side-context
  (validate-candidate
   return-calculus
   (hopf-b-raw raw-hole hopf-g-raw)
   #:expected return-boundary))
(define return-side-context-squared
  (validate-candidate
   return-calculus
   (hopf-b-raw
    (hopf-b-raw raw-hole hopf-g-raw)
    hopf-g-raw)
   #:expected return-boundary))

;; A G-return spine can visit H repeatedly without making a proper G return.
;; A complete G rooted off that spine is likewise irrelevant to first return.
(define colour-G (singleton-hypersequent '() '(G)))
(define colour-H (singleton-hypersequent '() '(H)))

(define colour-G-from-H-occurrence
  (make-concrete-occurrence
   'recurrence-colour-G-from-H
   (list colour-H)
   colour-G
   #:tag 'colour-step))
(define colour-H-loop-occurrence
  (make-concrete-occurrence
   'recurrence-colour-H-loop
   (list colour-H)
   colour-H
   #:tag 'colour-step))
(define colour-H-from-G-occurrence
  (make-concrete-occurrence
   'recurrence-colour-H-from-G
   (list colour-G)
   colour-H
   #:tag 'colour-step))
(define colour-G-ground-occurrence
  (make-concrete-occurrence
   'recurrence-colour-G-ground
   '()
   colour-G
   #:kind 'material
   #:tag 'ground))
(define colour-G-with-side-occurrence
  (make-concrete-occurrence
   'recurrence-colour-G-with-side
   (list colour-H colour-G)
   colour-G
   #:tag 'colour-side-frame))

(define colour-calculus
  (make-equipped-calculus
   (list colour-G-from-H-occurrence
         colour-H-loop-occurrence
         colour-H-from-G-occurrence
         colour-G-ground-occurrence
         colour-G-with-side-occurrence)))

(define G-first-via-repeated-H
  (validate-candidate
   colour-calculus
   (raw-app
    'recurrence-colour-G-from-H
    (raw-app
     'recurrence-colour-H-loop
     (raw-app 'recurrence-colour-H-from-G raw-hole)))
   #:expected colour-G))

(define G-first-with-off-spine-G
  (validate-candidate
   colour-calculus
   (raw-app
    'recurrence-colour-G-with-side
    (raw-app 'recurrence-colour-H-from-G raw-hole)
    (raw-app 'recurrence-colour-G-ground))
   #:expected colour-G))

;; Three unary endocontexts on the same two-component boundary isolate split,
;; merge, and swap relations.  Their arity and boundary size are unchanged, so
;; both scalar defect coordinates are exactly zero.
(define recurrence-A=>A (make-sequent '(A) '(A)))
(define recurrence-B=>B (make-sequent '(B) '(B)))
(define recurrence-component-boundary
  (make-hypersequent (list recurrence-A=>A recurrence-B=>B)))

(define split-incidence
  (make-component-incidence
   (list recurrence-component-boundary)
   recurrence-component-boundary
   (list (make-component-edge 1 1 1)
         (make-component-edge 1 1 2))))
(define merge-incidence
  (make-component-incidence
   (list recurrence-component-boundary)
   recurrence-component-boundary
   (list (make-component-edge 1 1 1)
         (make-component-edge 1 2 1))))
(define swap-incidence
  (make-component-incidence
   (list recurrence-component-boundary)
   recurrence-component-boundary
   (list (make-component-edge 1 1 2)
         (make-component-edge 1 2 1))))

(define split-occurrence
  (make-concrete-occurrence
   'recurrence-component-split
   (list recurrence-component-boundary)
   recurrence-component-boundary
   #:kind 'structural
   #:tag 'split
   #:incidence split-incidence))
(define merge-occurrence
  (make-concrete-occurrence
   'recurrence-component-merge
   (list recurrence-component-boundary)
   recurrence-component-boundary
   #:kind 'structural
   #:tag 'merge
   #:incidence merge-incidence))
(define swap-occurrence
  (make-concrete-occurrence
   'recurrence-component-swap
   (list recurrence-component-boundary)
   recurrence-component-boundary
   #:kind 'structural
   #:tag 'swap
   #:incidence swap-incidence))
(define opaque-recurrence-occurrence
  (make-concrete-occurrence
   'recurrence-component-opaque
   (list recurrence-component-boundary)
   recurrence-component-boundary
   #:kind 'structural
   #:tag 'opaque
   #:incidence '(legacy-opaque-recurrence)))

(define component-recurrence-calculus
  (make-equipped-calculus
   (list split-occurrence
         merge-occurrence
         swap-occurrence
         opaque-recurrence-occurrence)))

(define split-context
  (corolla component-recurrence-calculus split-occurrence))
(define merge-context
  (corolla component-recurrence-calculus merge-occurrence))
(define swap-context
  (corolla component-recurrence-calculus swap-occurrence))
(define opaque-recurrence-context
  (corolla component-recurrence-calculus opaque-recurrence-occurrence))

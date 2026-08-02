#lang racket/base

(require rackunit
         "../potkin/kernel.rkt"
         "kernel-fixtures.rkt")

(define bS-proof
  (validate-candidate running-calculus (raw-app 'bS) #:expected S))
(define bS-prime-proof
  (validate-candidate running-calculus (raw-app 'bS-prime) #:expected S))
(define bT-proof
  (validate-candidate running-calculus (raw-app 'bT) #:expected T))

(check-equal? (vertex-addresses running-proof)
              '(() (1) (1 1) (1 2)))
(check-equal? (vertex-at-address running-proof '(1 2)) bT-proof)
(check-false (checked-term-at-address running-proof '(2)))
(check-true (address-prefix? '(1) '(1 2)))
(check-true (proper-address-prefix? '(1) '(1 2)))
(check-false (proper-address-prefix? '(1) '(1)))
(check-true (address<? '(1 1) '(1 2)))

(define m-corolla (corolla running-calculus m-occ))
(check-true (proof-context? m-corolla))
(check-equal? (derivation-vertex-count m-corolla) 1)
(check-equal? (puncture-addresses m-corolla) '((1) (2)))
(check-equal?
 (map telescope-entry-requirement (premise-telescope m-corolla))
 (list S T))
(check-equal? (puncture-requirement m-corolla '(1)) S)
(check-equal? (puncture-requirement m-corolla '(2)) T)

(define a-corolla (corolla running-calculus a-occ))
(check-equal? (puncture-addresses a-corolla) '((1) (2)))
(check-equal? (map telescope-entry-requirement
                   (premise-telescope a-corolla))
              (list S S))
(check-equal? (corolla running-calculus bS-occ) bS-proof)
(check-true (complete-proof? (corolla running-calculus bS-occ)))
(check-equal?
 (context-error-code
  (corolla running-calculus
           (make-concrete-occurrence 'bS '() S #:kind 'material)))
 'unadmitted-occurrence)

(define i-corolla (corolla running-calculus 'i))
(define refined (context-insert i-corolla '(1) m-corolla))
(check-equal? (puncture-addresses refined) '((1 1) (1 2)))
(check-equal?
 (map telescope-entry-requirement (premise-telescope refined))
 (list S T))

;; Proposition 1.5: refine then fill at prefixed addresses, or fill the
;; inserted context first, and obtain the same structural presentation.
(define refine-then-fill
  (complete-fill refined (list bS-proof bT-proof)))
(define fill-then-insert
  (context-insert i-corolla
                  '(1)
                  (complete-fill m-corolla (list bS-proof bT-proof))))
(check-equal? refine-then-fill fill-then-insert)
(check-equal? refine-then-fill running-proof)
(check-true (term-admitted-by? running-calculus running-proof))

;; Genuine multi-hole associativity: each outer puncture is refined by a
;; one-hole context, producing the prefixed telescope (1 1), (2 1).
(define S-wrap-occ
  (make-concrete-occurrence 'S-wrap (list S) S #:kind 'logical))
(define extended-revision
  (make-calculus-revision running-calculus '() (list S-wrap-occ)))
(define extended-calculus
  (calculus-revision-target extended-revision))
(define bS-proof/extended (lift-term extended-revision bS-proof))
(define bS-prime-proof/extended
  (lift-term extended-revision bS-prime-proof))
(define outer-a (corolla extended-calculus a-occ))
(define S-wrap (corolla extended-calculus S-wrap-occ))
(define twice-refined (context-compose outer-a (list S-wrap S-wrap)))
(check-equal? (puncture-addresses twice-refined) '((1 1) (2 1)))
(check-equal? (map telescope-entry-requirement
                   (premise-telescope twice-refined))
              (list S S))
(define outer-then-inner
  (complete-fill twice-refined
                 (list bS-proof/extended bS-prime-proof/extended)))
(define inner-then-outer
  (context-compose
   outer-a
   (list (complete-fill S-wrap (list bS-proof/extended))
         (complete-fill S-wrap (list bS-prime-proof/extended)))))
(check-equal? outer-then-inner inner-then-outer)

;; Box is a two-sided typed identity for context composition.
(define identity-V (identity-context extended-calculus V))
(define identity-S/extended (identity-context extended-calculus S))
(check-equal? (context-compose identity-V (list outer-a)) outer-a)
(check-equal? (context-compose outer-a
                               (list identity-S/extended
                                     identity-S/extended))
              outer-a)

;; Extensional registry admission and presentation equality do not establish
;; exact checked provenance. Operational composition requires an explicit
;; lift into the extension snapshot.
(define running-proof/extended
  (lift-term extended-revision running-proof))
(check-equal? running-proof running-proof/extended)
(check-true (term-admitted-by? extended-calculus running-proof))
(check-false
 (checked-term-has-exact-calculus? running-proof extended-calculus))
(define cross-snapshot-insertion
  (context-insert identity-S/extended '() bS-proof))
(check-true (context-error? cross-snapshot-insertion))
(check-equal? (context-error-code cross-snapshot-insertion)
              'wrong-calculus-provenance)
(check-true (eq? (context-error-expected cross-snapshot-insertion)
                 extended-calculus))
(check-true (eq? (context-error-actual cross-snapshot-insertion)
                 running-calculus))

;; Insertions at independent punctures commute.
(define S-then-T
  (context-insert (context-insert m-corolla '(1) bS-proof)
                  '(2)
                  bT-proof))
(define T-then-S
  (context-insert (context-insert m-corolla '(2) bT-proof)
                  '(1)
                  bS-proof))
(check-equal? S-then-T T-then-S)

(define identity-S (identity-context running-calculus S))
(check-true (proof-context? identity-S))
(check-equal? (derivation-vertex-count identity-S) 0)
(check-equal? (puncture-addresses identity-S) '(()))
(check-equal? (puncture-requirement identity-S '()) S)
(check-equal? (complete-fill identity-S (list bS-proof)) bS-proof)

;; A fresh, separately tagged same-boundary ground fills the S puncture.
(define S-hole-context
  (validate-candidate
   running-calculus
   (raw-app 'i
            (raw-app 'm raw-hole (raw-app 'bT)))
   #:expected U))
(define fresh-result (complete-fill S-hole-context (list bS-prime-proof)))
(check-true (complete-proof? fresh-result))
(check-equal?
 fresh-result
 (validate-candidate
  running-calculus
  (raw-app 'i
           (raw-app 'm (raw-app 'bS-prime) (raw-app 'bT)))
  #:expected U))

(define wrong-T (complete-fill S-hole-context (list bT-proof)))
(check-true (context-error? wrong-T))
(check-equal? (context-error-code wrong-T) 'wrong-boundary)
(check-equal? (context-error-expected wrong-T) S)
(check-equal? (context-error-actual wrong-T) T)

(define wrong-U (complete-fill S-hole-context (list running-proof)))
(check-true (context-error? wrong-U))
(check-equal? (context-error-code wrong-U) 'wrong-boundary)

(check-equal? (context-error-code
               (context-insert m-corolla '(3) bS-proof))
              'no-such-address)
(check-equal? (context-error-code
               (context-insert running-proof '(1) bS-proof))
              'not-a-puncture)
(check-equal? (context-error-code
               (complete-fill m-corolla (list bS-proof)))
              'wrong-filler-count)
(check-equal? (context-error-code
               (complete-fill identity-S (list m-corolla)))
              'incomplete-filler)

;; Root-boundary equality alone is insufficient: a replacement must first
;; carry the exact context snapshot, before extensional admission is relevant.
(define foreign-bS-occ
  (make-concrete-occurrence 'foreign-bS '() S #:kind 'material))
(define foreign-calculus (make-equipped-calculus (list foreign-bS-occ)))
(define foreign-bS-proof
  (validate-candidate foreign-calculus (raw-app 'foreign-bS) #:expected S))
(check-equal?
 (context-error-code
  (complete-fill identity-S (list foreign-bS-proof)))
  'wrong-calculus-provenance)

;; Open typing is registry-relative but does not search for a filler.
(define needs-S-occ
  (make-concrete-occurrence 'needs-S (list S) U #:kind 'logical))
(define no-S-ground-calculus (make-equipped-calculus (list needs-S-occ)))
(define empty-fibre-corolla (corolla no-S-ground-calculus needs-S-occ))
(check-true (proof-context? empty-fibre-corolla))
(check-equal? (map telescope-entry-requirement
                   (premise-telescope empty-fibre-corolla))
              (list S))
(check-false
 (for/or ([occurrence (in-list
                       (calculus-occurrences no-S-ground-calculus))])
   (equal? (concrete-occurrence-conclusion occurrence) S)))

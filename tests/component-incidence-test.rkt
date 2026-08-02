#lang racket/base

(require rackunit
         "../potkin/kernel.rkt")

(define component-a (make-sequent '(A) '(X)))
(define component-b (make-sequent '(B) '(Y)))
(define component-c (make-sequent '(C) '(Z)))

(define one-a (make-hypersequent (list component-a)))
(define one-b (make-hypersequent (list component-b)))
(define one-c (make-hypersequent (list component-c)))
(define two-ab (make-hypersequent (list component-a component-b)))

;; Edge construction and endpoint validation reject malformed local indices
;; before a typed incidence value can enter a concrete occurrence.
(check-exn exn:fail:contract?
           (lambda () (make-component-edge 0 1 1)))
(check-exn exn:fail:contract?
           (lambda () (make-component-edge 1 0 1)))
(check-exn exn:fail:contract?
           (lambda () (make-component-edge 1 1 0)))
(check-exn exn:fail:contract?
           (lambda () (make-component-edge 1 1.0 1)))
(check-exn exn:fail:contract?
           (lambda ()
             (make-component-incidence
              one-a one-a '())))
(check-exn exn:fail:contract?
           (lambda ()
             (make-component-incidence
              (list one-a) component-a '())))
(check-exn exn:fail:contract?
           (lambda ()
             (make-component-incidence
              (list one-a) one-a (list '(1 1 1)))))
(check-exn exn:fail:contract?
           (lambda ()
             (make-component-incidence
              (list one-a)
              one-a
              (list (make-component-edge 2 1 1)))))
(check-exn exn:fail:contract?
           (lambda ()
             (make-component-incidence
              (list one-a)
              one-a
              (list (make-component-edge 1 2 1)))))
(check-exn exn:fail:contract?
           (lambda ()
             (make-component-incidence
              (list one-a)
              one-a
              (list (make-component-edge 1 1 2)))))
(check-exn exn:fail:contract?
           (lambda ()
             (make-component-incidence
              '()
              one-a
              (list (make-component-edge 1 1 1)))))

;; Relations are finite sets with one deterministic numeric edge order.
(define edge-112 (make-component-edge 1 1 2))
(define edge-121 (make-component-edge 1 2 1))
(define edge-212 (make-component-edge 2 1 2))
(define canonical-forward
  (make-component-incidence
   (list two-ab one-c)
   two-ab
   (list edge-112 edge-121 edge-212 edge-121)))
(define canonical-reversed
  (make-component-incidence
   (list two-ab one-c)
   two-ab
   (list edge-212 edge-121 edge-112)))

(check-equal? canonical-forward canonical-reversed)
(check-equal? (equal-hash-code canonical-forward)
              (equal-hash-code canonical-reversed))
(check-equal? (equal-secondary-hash-code canonical-forward)
              (equal-secondary-hash-code canonical-reversed))
(check-equal? (component-incidence-edges canonical-forward)
              (list edge-112 edge-121 edge-212))

;; Typed incidence is certified for one exact ordered boundary profile.  A
;; same-breadth but different premise/conclusion, or swapped premise order,
;; cannot reuse that certificate.
(define identity-a
  (make-component-incidence
   (list one-a)
   one-a
   (list (make-component-edge 1 1 1))))
(define typed-occurrence
  (make-concrete-occurrence
   'typed-a
   (list one-a)
   one-a
   #:incidence identity-a))

(check-eq? (concrete-occurrence-incidence typed-occurrence) identity-a)
(check-true
 (component-incidence-matches-profile? identity-a (list one-a) one-a))
(check-false
 (component-incidence-matches-profile? identity-a (list one-b) one-a))
(check-false
 (component-incidence-matches-profile? identity-a (list one-a) one-b))
(check-exn exn:fail:contract?
           (lambda ()
             (make-concrete-occurrence
              'wrong-premise-profile
              (list one-b)
              one-a
              #:incidence identity-a)))
(check-exn exn:fail:contract?
           (lambda ()
             (make-concrete-occurrence
              'wrong-conclusion-profile
              (list one-a)
              one-b
              #:incidence identity-a)))

(define ordered-profile
  (make-component-incidence
   (list one-a one-b)
   one-c
   (list (make-component-edge 1 1 1)
         (make-component-edge 2 1 1))))
(check-exn exn:fail:contract?
           (lambda ()
             (make-concrete-occurrence
              'wrong-premise-order
              (list one-b one-a)
              one-c
              #:incidence ordered-profile)))

;; Equal displayed components remain separate local component occurrences.
(define repeated-aa
  (make-hypersequent (list component-a component-a)))
(define repeated-bijection
  (make-component-incidence
   (list repeated-aa)
   repeated-aa
   (list (make-component-edge 1 2 2)
         (make-component-edge 1 1 1))))

(check-equal?
 (map component-occurrence-index (hypersequent-components repeated-aa))
 '(1 2))
(check-equal?
 (map component-edge-source-index
      (component-incidence-edges repeated-bijection))
 '(1 2))
(check-equal?
 (map component-edge-target-index
      (component-incidence-edges repeated-bijection))
 '(1 2))
(check-true (component-incidence-functional? repeated-bijection))
(check-true (component-incidence-inverse-functional? repeated-bijection))
(check-true (component-incidence-total? repeated-bijection))
(check-true (component-incidence-surjective? repeated-bijection))

;; A genuinely typed empty relation stays distinguishable from both the
;; legacy opaque seam and the old absent/default payload.
(define typed-empty
  (make-component-incidence (list one-a) one-a '()))
(define typed-empty-occurrence
  (make-concrete-occurrence
   'typed-empty
   (list one-a)
   one-a
   #:incidence typed-empty))
(define legacy-payload '#(legacy opaque incidence))
(define legacy-occurrence
  (make-concrete-occurrence
   'legacy-incidence
   (list one-a)
   one-a
   #:incidence legacy-payload))
(define absent-occurrence
  (make-concrete-occurrence 'absent-incidence (list one-a) one-a))

(check-true
 (component-incidence?
  (concrete-occurrence-incidence typed-empty-occurrence)))
(check-equal? (component-incidence-edges typed-empty) '())
(check-eq? (concrete-occurrence-incidence legacy-occurrence)
           legacy-payload)
(check-false
 (component-incidence?
  (concrete-occurrence-incidence legacy-occurrence)))
(check-equal? (concrete-occurrence-incidence absent-occurrence) '())
(check-false
 (component-incidence?
  (concrete-occurrence-incidence absent-occurrence)))
(check-true (component-incidence-functional? typed-empty))
(check-true (component-incidence-inverse-functional? typed-empty))
(check-false (component-incidence-total? typed-empty))
(check-false (component-incidence-surjective? typed-empty))

;; Splitting, merger, erasure, and unsupported creation are observations, not
;; constructor restrictions.
(define split
  (make-component-incidence
   (list one-a)
   two-ab
   (list (make-component-edge 1 1 1)
         (make-component-edge 1 1 2))))
(define merge
  (make-component-incidence
   (list two-ab)
   one-a
   (list (make-component-edge 1 1 1)
         (make-component-edge 1 2 1))))
(define erase
  (make-component-incidence
   (list two-ab)
   one-a
   (list (make-component-edge 1 1 1))))
(define create
  (make-component-incidence
   (list one-a)
   two-ab
   (list (make-component-edge 1 1 1))))

(check-false (component-incidence-functional? split))
(check-true (component-incidence-inverse-functional? split))
(check-true (component-incidence-total? split))
(check-true (component-incidence-surjective? split))
(check-true (component-incidence-splitting? split))
(check-false (component-incidence-merger? split))
(check-false (component-incidence-erasure? split))
(check-false (component-incidence-unsupported-creation? split))

(check-true (component-incidence-functional? merge))
(check-false (component-incidence-inverse-functional? merge))
(check-true (component-incidence-total? merge))
(check-true (component-incidence-surjective? merge))
(check-false (component-incidence-splitting? merge))
(check-true (component-incidence-merger? merge))
(check-false (component-incidence-erasure? merge))
(check-false (component-incidence-unsupported-creation? merge))

(check-true (component-incidence-functional? erase))
(check-true (component-incidence-inverse-functional? erase))
(check-false (component-incidence-total? erase))
(check-true (component-incidence-surjective? erase))
(check-false (component-incidence-splitting? erase))
(check-false (component-incidence-merger? erase))
(check-true (component-incidence-erasure? erase))
(check-false (component-incidence-unsupported-creation? erase))

(check-true (component-incidence-functional? create))
(check-true (component-incidence-inverse-functional? create))
(check-true (component-incidence-total? create))
(check-false (component-incidence-surjective? create))
(check-false (component-incidence-splitting? create))
(check-false (component-incidence-merger? create))
(check-false (component-incidence-erasure? create))
(check-true (component-incidence-unsupported-creation? create))

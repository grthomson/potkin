#lang racket/base

(require rackunit
         "../potkin/main.rkt"
         "hopf-fixtures.rkt")

(define (key . forests)
  (vector->immutable-vector (list->vector forests)))

(define (singleton-forest term)
  (make-proof-forest (checked-term-calculus term) (list term)))

(define g
  (validate-candidate
   hopf-calculus hopf-g-raw #:expected hopf-S))
(define u-Box
  (validate-candidate
   hopf-calculus (hopf-u-raw raw-hole) #:expected hopf-S))
(define g-forest (singleton-forest g))
(define u-Box-forest (singleton-forest u-Box))
(define one/H (empty-proof-forest hopf-calculus))
(define sample-rank-two
  (pure-tensor hopf-calculus (key u-Box-forest one/H)))

;; Registry equality remains structural, but revision equality is operational:
;; exact source and target snapshot identities are part of the arrow.
(define hopf-calculus-clone
  (make-equipped-calculus (calculus-occurrences hopf-calculus)))
(check-equal? hopf-calculus-clone hopf-calculus)
(check-false (eq? hopf-calculus-clone hopf-calculus))

(define copy-revision
  (make-calculus-revision hopf-calculus '() '()))
(define clone-copy-revision
  (make-calculus-revision hopf-calculus-clone '() '()))
(check-false (equal? copy-revision clone-copy-revision))
(check-equal?
 (hash-count
  (hash copy-revision 'source
        clone-copy-revision 'clone))
 2)

;; The legacy empty D/A constructor remains a genuine rebase to a freshly
;; allocated target. It is not the exact identity revision.
(define copied-calculus (calculus-revision-target copy-revision))
(check-equal? copied-calculus hopf-calculus)
(check-false (eq? copied-calculus hopf-calculus))

(define exact-identity
  (identity-calculus-revision hopf-calculus))
(check-true (calculus-revision? exact-identity))
(check-true
 (eq? (calculus-revision-source exact-identity) hopf-calculus))
(check-true
 (eq? (calculus-revision-target exact-identity) hopf-calculus))
(check-equal? (calculus-revision-withdrawn-ids exact-identity) '())
(check-equal? (calculus-revision-additions exact-identity) '())
(check-false (equal? exact-identity copy-revision))
(check-equal? exact-identity
              (identity-calculus-revision hopf-calculus))
(check-equal? (equal-hash-code exact-identity)
              (equal-hash-code
               (identity-calculus-revision hopf-calculus)))

(define identity-g (lift-term exact-identity g))
(define identity-context (lift-context exact-identity u-Box))
(define identity-forest
  (lift-proof-forest exact-identity u-Box-forest))
(check-equal? identity-g g)
(check-equal? identity-context u-Box)
(check-equal? identity-forest u-Box-forest)
(check-true (eq? (checked-term-calculus identity-g) hopf-calculus))
(check-true
 (eq? (checked-term-calculus identity-context) hopf-calculus))
(check-true
 (eq? (proof-forest-calculus identity-forest) hopf-calculus))
(check-equal?
 (formal-revision-map exact-identity sample-rank-two)
 sample-rank-two)

;; Empty paths are exact identity paths. Their operations return the input
;; value itself, while still rejecting a foreign exact source snapshot.
(define empty-chain (make-revision-chain hopf-calculus '()))
(check-true (revision-chain? empty-chain))
(check-true (eq? (revision-chain-source empty-chain) hopf-calculus))
(check-true (eq? (revision-chain-target empty-chain) hopf-calculus))
(check-equal? (revision-chain-steps empty-chain) '())
(check-true (eq? (lift-term-through empty-chain g) g))
(check-true (eq? (lift-context-through empty-chain u-Box) u-Box))
(check-true
 (eq? (lift-proof-forest-through empty-chain u-Box-forest)
      u-Box-forest))
(check-true
 (eq? (formal-revision-map-chain empty-chain sample-rank-two)
      sample-rank-two))

;; One-step paths agree with their existing one-step operations.
(define one-step-chain
  (make-revision-chain hopf-calculus (list copy-revision)))
(check-true (revision-chain? one-step-chain))
(check-true
 (eq? (revision-chain-target one-step-chain) copied-calculus))
(check-equal? (revision-chain-steps one-step-chain)
              (list copy-revision))
(check-equal? (lift-term-through one-step-chain g)
              (lift-term copy-revision g))
(check-equal? (lift-context-through one-step-chain u-Box)
              (lift-context copy-revision u-Box))
(check-equal? (lift-proof-forest-through one-step-chain u-Box-forest)
              (lift-proof-forest copy-revision u-Box-forest))
(check-equal? (formal-revision-map-chain one-step-chain sample-rank-two)
              (formal-revision-map copy-revision sample-rank-two))

;; Composition is exact at every intermediate registry object, not merely at
;; a structurally equal registry presentation.
(define delete-g-after-copy
  (make-calculus-revision copied-calculus '(g) '()))
(define two-step-chain
  (make-revision-chain
   hopf-calculus (list copy-revision delete-g-after-copy)))
(define two-step-target
  (calculus-revision-target delete-g-after-copy))
(check-true (revision-chain? two-step-chain))
(check-true
 (eq? (revision-chain-target two-step-chain) two-step-target))
(check-equal?
 (lift-context-through two-step-chain u-Box)
 (lift-context
  delete-g-after-copy (lift-context copy-revision u-Box)))
(check-equal?
 (lift-proof-forest-through two-step-chain u-Box-forest)
 (lift-proof-forest
  delete-g-after-copy
  (lift-proof-forest copy-revision u-Box-forest)))

(define (sequential-two-step-map value)
  (formal-revision-map
   delete-g-after-copy
   (formal-revision-map copy-revision value)))

(for ([value
       (in-list
        (list (forest-basis u-Box-forest)
              (forest-basis g-forest)
              sample-rank-two
              (formal-zero hopf-calculus 3)))])
  (check-equal?
   (formal-revision-map-chain two-step-chain value)
   (sequential-two-step-map value)))

;; The Hopf-map laws hold for each step and for their composite path. This is
;; finite-input executable evidence, not a universal persistence proof.
(define retained-value (forest-basis u-Box-forest))
(define copied-retained
  (formal-revision-map copy-revision retained-value))

(define (check-naturality mapper value)
  (define image (mapper value))
  (check-true (formal-sum? image))
  (check-equal? (mapper (coproduct value))
                (coproduct image))
  (check-equal? (counit image) (counit value))
  (check-equal? (mapper (antipode value))
                (antipode image)))

(check-naturality
 (lambda (value) (formal-revision-map copy-revision value))
 retained-value)
(check-naturality
 (lambda (value) (formal-revision-map delete-g-after-copy value))
 copied-retained)
(check-naturality
 (lambda (value) (formal-revision-map-chain two-step-chain value))
 retained-value)
(check-naturality
 (lambda (value) (formal-revision-map-chain two-step-chain value))
 (forest-basis g-forest))

;; A chain constructor rejects even structurally equal intermediate snapshots
;; unless they are the exact same object.
(define wrong-first-source
  (make-revision-chain hopf-calculus-clone (list copy-revision)))
(check-true (revision-error? wrong-first-source))
(check-equal? (revision-error-code wrong-first-source)
              'noncomposable-revision-chain)
(check-equal?
 (hash-ref (revision-error-details wrong-first-source) 'step-index)
 1)

(define clone-g
  (validate-candidate
   hopf-calculus-clone hopf-g-raw #:expected hopf-S))
(define clone-u-Box
  (validate-candidate
   hopf-calculus-clone (hopf-u-raw raw-hole) #:expected hopf-S))
(define clone-u-Box-forest (singleton-forest clone-u-Box))
(for ([result
       (in-list
        (list (lift-term-through empty-chain clone-g)
              (lift-context-through empty-chain clone-u-Box)
              (lift-proof-forest-through
               empty-chain clone-u-Box-forest)))])
  (check-true (revision-error? result))
  (check-equal? (revision-error-code result)
                'wrong-source-calculus))
(define wrong-formal-source
  (formal-revision-map-chain
   empty-chain (formal-zero hopf-calculus-clone)))
(check-true (revision-map-error? wrong-formal-source))
(check-equal? (revision-map-error-code wrong-formal-source)
              'wrong-source-calculus)
(check-equal? (revision-map-error-operation wrong-formal-source)
              'formal-revision-map-chain)

;; Temporal ID reuse is legal only as two steps. Reintroduce a newly allocated
;; occurrence structurally identical to the historical b, making the final
;; registry structurally equal to K0. Sequential deletion still prevents the
;; historical b monomial from being resurrected.
(define retire-b
  (make-calculus-revision hopf-calculus '(b) '()))
(define without-b (calculus-revision-target retire-b))
(define second-generation-b
  (make-concrete-occurrence
   (concrete-occurrence-id hopf-b-occurrence)
   (vector->list (concrete-occurrence-premises hopf-b-occurrence))
   (concrete-occurrence-conclusion hopf-b-occurrence)
   #:kind (concrete-occurrence-kind hopf-b-occurrence)
   #:tag (concrete-occurrence-tag hopf-b-occurrence)
   #:instance (concrete-occurrence-instance hopf-b-occurrence)
   #:incidence (concrete-occurrence-incidence hopf-b-occurrence)))
(check-equal? second-generation-b hopf-b-occurrence)
(check-false (eq? second-generation-b hopf-b-occurrence))

(define reuse-b
  (make-calculus-revision without-b '() (list second-generation-b)))
(check-true (calculus-revision? reuse-b))
(define restored-calculus (calculus-revision-target reuse-b))
(check-equal? restored-calculus hopf-calculus)
(check-false (eq? restored-calculus hopf-calculus))
(define reuse-chain
  (make-revision-chain hopf-calculus (list retire-b reuse-b)))
(check-true (revision-chain? reuse-chain))
(check-true
 (eq? (revision-chain-target reuse-chain) restored-calculus))

(define historical-b
  (validate-candidate
   hopf-calculus
   (hopf-b-raw raw-hole raw-hole)
   #:expected hopf-S))
(define restored-b
  (validate-candidate
   restored-calculus
   (hopf-b-raw raw-hole raw-hole)
   #:expected hopf-S))
(check-equal? historical-b restored-b)
(check-false
 (eq? (checked-term-calculus historical-b)
      (checked-term-calculus restored-b)))

(define historical-b-value (checked-node-basis historical-b))
(define first-image
  (formal-revision-map retire-b historical-b-value))
(define sequential-image
  (formal-revision-map reuse-b first-image))
(define chain-image
  (formal-revision-map-chain reuse-chain historical-b-value))
(check-equal? first-image (formal-zero without-b))
(check-equal? sequential-image (formal-zero restored-calculus))
(check-equal? chain-image sequential-image)
(check-true (formal-zero? chain-image))
(check-false (formal-zero? (checked-node-basis restored-b)))
(check-not-equal? chain-image (checked-node-basis restored-b))

(define historical-through-result
  (lift-term-through reuse-chain historical-b))
(check-true (revision-error? historical-through-result))
(check-equal? (revision-error-code historical-through-result)
              'inactive-occurrences)

;; The same-ID withdrawal/addition cannot be flattened into one revision,
;; because additions are fresh relative to that one step's entire source.
(define illegal-flattening
  (make-calculus-revision
   hopf-calculus '(b) (list second-generation-b)))
(check-true (revision-error? illegal-flattening))
(check-equal? (revision-error-code illegal-flattening)
              'nonfresh-addition)

#lang racket/base

(require racket/list
         rackunit
         "../potkin/kernel.rkt"
         "revision-fixtures.rkt")

(define (check-revision-failure result expected-code)
  (check-true (revision-error? result))
  (check-equal? (revision-error-code result) expected-code)
  (check-true (string? (revision-error-message result)))
  (check-false (string=? (revision-error-message result) ""))
  (check-true (hash? (revision-error-details result))))

(define (diagnostic-addresses diagnostics)
  (map liveness-diagnostic-address diagnostics))

(define (diagnostic-ids diagnostics)
  (map (lambda (diagnostic)
         (concrete-occurrence-id
          (liveness-diagnostic-occurrence diagnostic)))
       diagnostics))

(define (diagnostic-classifications diagnostics)
  (map liveness-diagnostic-classification diagnostics))

;; Revision construction computes (K0 minus D) plus A without changing K0.
(check-true (calculus-revision? retire-bS-revision))
(check-true (eq? (calculus-revision-source retire-bS-revision) K0))
(check-true (eq? (calculus-revision-target retire-bS-revision) K1))
(check-equal? (calculus-revision-withdrawn-ids retire-bS-revision) '(bS))
(check-equal? (calculus-revision-additions retire-bS-revision)
              (list bS-prime-occ))
(check-equal? (calculus-size K0) 6)
(check-equal? (calculus-size K1) 6)
(check-true (calculus-admits? K0 bS-occ))
(check-false (calculus-admits? K1 bS-occ))
(check-false (calculus-admits? K0 bS-prime-occ))
(check-true (calculus-admits? K1 bS-prime-occ))
(for ([retained (in-list (list bS-keep-occ bT-occ m-occ i-occ a-occ))])
  (define id (concrete-occurrence-id retained))
  (check-true (eq? (calculus-lookup K0 id) retained))
  (check-true (eq? (calculus-lookup K1 id) retained)))

;; The invariant-bearing revision is opaque.  Its target was freshly built,
;; while the immutable source registry and every retained occurrence remain
;; the exact objects supplied above.
(check-false (eq? K1 K0))
(define-values (revision-struct-type revision-skipped?)
  (struct-info retire-bS-revision))
(check-false revision-struct-type)
(check-true revision-skipped?)

;; Withdrawal and addition identities are exact, not profile based.
(check-revision-failure
 (make-calculus-revision K0 '(bS bS) '())
 'duplicate-withdrawal)
(check-revision-failure
 (make-calculus-revision K0 '(not-in-K0) '())
 'unknown-withdrawal)
(check-revision-failure
 (make-calculus-revision K0 '()
                         (list bS-prime-occ bS-prime-occ))
 'duplicate-addition)
(check-revision-failure
 (make-calculus-revision K0 '(bS) (list bS-occ))
 'nonfresh-addition)
(define redefined-bS
  (make-concrete-occurrence
   'bS '() S #:kind 'material #:tag 'ground #:instance 'counterfeit))
(check-revision-failure
 (make-calculus-revision K0 '(bS) (list redefined-bS))
 'nonfresh-addition)

;; A revision changes target-relative liveness, never the historical
;; certification or the complete/open status of an already checked term.
(check-true (term-historically-valid? t))
(check-true (derivation-complete? t))
(check-false (proof-context? t))
(check-true (term-historically-valid? R))
(check-false (derivation-complete? R))
(check-true (proof-context? R))
(check-true (eq? (checked-term-calculus t) K0))
(check-equal? (validate-candidate K0 t-raw #:expected U) t)

(define t-diagnostics
  (revision-liveness-diagnostics retire-bS-revision t))
(check-true (andmap liveness-diagnostic? t-diagnostics))
(check-equal? t-diagnostics
              (term-liveness-diagnostics K1 t #:retired-ids '(bS)))
(check-equal? (diagnostic-addresses t-diagnostics) '((1 1)))
(check-equal? (diagnostic-ids t-diagnostics) '(bS))
(check-equal? (diagnostic-classifications t-diagnostics) '(retired))
(check-false (liveness-diagnostic-target-occurrence
              (first t-diagnostics)))
(check-false (revision-term-live? retire-bS-revision t))
(check-true (revision-term-live? retire-bS-revision R))
(check-true (term-live-in? K1 R #:retired-ids '(bS)))
(check-equal?
 (diagnostic-classifications (term-liveness-diagnostics K1 t))
 '(unknown))
(define bS-prime-proof/K1
  (validate-candidate K1 (raw-app 'bS-prime) #:expected S))
(check-true (term-historically-valid? bS-prime-proof/K1))
(check-true (term-live-in? K1 bS-prime-proof/K1
                           #:retired-ids '(bS)))
(check-equal? (term-liveness-diagnostics K1 bS-prime-proof/K1
                                         #:retired-ids '(bS))
              '())

;; The general target-relative query reports every retired occurrence, in
;; lexicographic address order, rather than stopping at the first failure.
(define repeated-retired
  (validate-candidate
   K0
   (raw-app 'a (raw-app 'bS) (raw-app 'bS))
   #:expected V))
(define repeated-retired-diagnostics
  (term-liveness-diagnostics K1 repeated-retired
                             #:retired-ids '(bS)))
(check-equal? (diagnostic-addresses repeated-retired-diagnostics)
              '((1) (2)))
(check-equal? (diagnostic-ids repeated-retired-diagnostics) '(bS bS))
(check-equal? (diagnostic-classifications repeated-retired-diagnostics)
              '(retired retired))
(check-false (term-live-in? K1 repeated-retired #:retired-ids '(bS)))

;; Missing IDs not designated retired are unknown at every occurrence.
(define alien-occ
  (make-concrete-occurrence
   'alien '() S #:kind 'material #:tag 'ground #:instance 'alien))
(define alien-calculus (make-equipped-calculus (list alien-occ a-occ)))
(define alien-proof
  (validate-candidate
   alien-calculus
   (raw-app 'a (raw-app 'alien) (raw-app 'alien))
   #:expected V))
(define alien-diagnostics
  (term-liveness-diagnostics K1 alien-proof #:retired-ids '(bS)))
(check-equal? (diagnostic-addresses alien-diagnostics) '((1) (2)))
(check-equal? (diagnostic-ids alien-diagnostics) '(alien alien))
(check-equal? (diagnostic-classifications alien-diagnostics)
              '(unknown unknown))
(for ([diagnostic (in-list alien-diagnostics)])
  (check-false (liveness-diagnostic-target-occurrence diagnostic)))

;; Reusing a retained ID for a different full concrete occurrence is an
;; incompatibility even when its arity and whole boundary agree exactly.
(define incompatible-S-occ
  (make-concrete-occurrence
   'bS-keep '() S
   #:kind 'material #:tag 'ground #:instance 'incompatible-S-keep))
(define incompatible-calculus
  (make-equipped-calculus (list incompatible-S-occ a-occ)))
(define incompatible-proof
  (validate-candidate
   incompatible-calculus
   (raw-app 'a (raw-app 'bS-keep) (raw-app 'bS-keep))
   #:expected V))
(define incompatible-diagnostics
  (term-liveness-diagnostics K1 incompatible-proof
                             #:retired-ids '(bS)))
(check-equal? (diagnostic-addresses incompatible-diagnostics) '((1) (2)))
(check-equal? (diagnostic-ids incompatible-diagnostics)
              '(bS-keep bS-keep))
(check-equal? (diagnostic-classifications incompatible-diagnostics)
              '(incompatible/redefined incompatible/redefined))
(for ([diagnostic (in-list incompatible-diagnostics)])
  (check-equal? (liveness-diagnostic-target-occurrence diagnostic)
                bS-keep-occ))

;; A same-ID target mismatch takes precedence over the retired-ID hint.  The
;; hint describes an exact old occurrence; it cannot turn a redefinition into
;; a legitimate retirement.
(define redefined-bS-target
  (make-equipped-calculus (list redefined-bS)))
(define redefined-and-retired-diagnostics
  (term-liveness-diagnostics redefined-bS-target bS-proof
                             #:retired-ids '(bS)))
(check-equal? (diagnostic-addresses redefined-and-retired-diagnostics)
              '(()))
(check-equal? (diagnostic-ids redefined-and-retired-diagnostics) '(bS))
(check-equal?
 (diagnostic-classifications redefined-and-retired-diagnostics)
 '(incompatible/redefined))
(check-equal?
 (liveness-diagnostic-target-occurrence
  (first redefined-and-retired-diagnostics))
 redefined-bS)
(check-false
 (term-live-in? redefined-bS-target bS-proof #:retired-ids '(bS)))

;; A lift rejects inactive and wrong-source terms with explicit values.  The
;; historical source remains usable after either failure.
(define inactive-lift (lift-term retire-bS-revision t))
(check-revision-failure inactive-lift 'inactive-occurrences)
(check-true (term-historically-valid? t))
(check-true (eq? (checked-term-calculus t) K0))
(check-revision-failure
 (lift-term retire-bS-revision alien-proof)
 'wrong-source-calculus)

;; Retained complete terms and open contexts are rebuilt from their raw form
;; under K1.  Presentation equality deliberately omits this provenance.
(define lifted-retained (lift-term retire-bS-revision retained-proof))
(check-true (complete-proof? lifted-retained))
(check-equal? lifted-retained retained-proof)
(check-equal? (checked-term->raw lifted-retained)
              (checked-term->raw retained-proof))
(check-equal? (vertex-addresses lifted-retained)
              (vertex-addresses retained-proof))
(check-true (eq? (checked-term-calculus lifted-retained) K1))
(check-false (eq? (checked-term-calculus lifted-retained) K0))

(define lifted-bT (lift-term retire-bS-revision bT-proof))
(check-equal? lifted-bT bT-proof)
(check-equal? (checked-term->raw lifted-bT) (raw-app 'bT))
(check-true (eq? (checked-term-calculus lifted-bT) K1))

;; Forest lifting rechecks every repeated connected factor under one target
;; registry.  The algebra unit stays the empty forest, never a Box context.
(define retained-forest/K0
  (make-proof-forest K0
                     (list retained-proof retained-proof bT-proof)))
(define retained-forest/K1
  (lift-proof-forest retire-bS-revision retained-forest/K0))
(check-true (proof-forest? retained-forest/K1))
(check-equal? retained-forest/K1 retained-forest/K0)
(check-equal? (proof-forest-size retained-forest/K1) 3)
(check-equal? (proof-forest-count retained-forest/K1 lifted-retained) 2)
(check-exn exn:fail:contract?
           (lambda ()
             (proof-forest-count retained-forest/K1 retained-proof)))
(check-true (eq? (proof-forest-calculus retained-forest/K1) K1))
(for ([factor (in-list (proof-forest-factors retained-forest/K1))])
  (check-true (eq? (checked-term-calculus factor) K1)))

(define empty-forest/K0 (empty-proof-forest K0))
(define empty-forest/K1
  (lift-proof-forest retire-bS-revision empty-forest/K0))
(check-true (proof-forest? empty-forest/K1))
(check-true (proof-forest-empty? empty-forest/K1))
(check-equal? (proof-forest-size empty-forest/K1) 0)
(check-true (eq? (proof-forest-calculus empty-forest/K1) K1))

(define lifted-R (lift-context retire-bS-revision R))
(check-true (proof-context? lifted-R))
(check-equal? lifted-R R)
(check-equal? (checked-term->raw lifted-R) (checked-term->raw R))
(check-equal? (derivation-root-boundary lifted-R)
              (derivation-root-boundary R))
(check-equal? (vertex-addresses lifted-R) (vertex-addresses R))
(check-equal? (puncture-addresses lifted-R) (puncture-addresses R))
(check-equal? (premise-telescope lifted-R) (premise-telescope R))
(check-true (eq? (checked-term-calculus lifted-R) K1))
(for ([address (in-list (vertex-addresses lifted-R))])
  (check-true
   (eq? (checked-node-calculus (vertex-at-address lifted-R address)) K1)))
(for ([address (in-list (puncture-addresses lifted-R))])
  (check-true
   (eq? (checked-hole-calculus
         (checked-term-at-address lifted-R address))
        K1)))
(check-revision-failure
 (lift-context retire-bS-revision retained-proof)
 'not-context)

;; Two distinct premise requirements retain both their address and their
;; literal S,T order.  The nodeless identity is also a liftable checked term,
;; not an empty forest or a special unchecked cast.
(define two-hole-context
  (validate-candidate
   K0
   (raw-app 'i (raw-app 'm raw-hole raw-hole))
   #:expected U))
(define lifted-two-hole-context
  (lift-context retire-bS-revision two-hole-context))
(check-equal? (checked-term->raw lifted-two-hole-context)
              (checked-term->raw two-hole-context))
(check-equal? (puncture-addresses lifted-two-hole-context)
              '((1 1) (1 2)))
(check-equal?
 (map telescope-entry-requirement
      (premise-telescope lifted-two-hole-context))
 (list S T))
(check-true (eq? (checked-term-calculus lifted-two-hole-context) K1))

(define Box-S (identity-context K0 S))
(define lifted-Box-S (lift-term retire-bS-revision Box-S))
(check-true (proof-context? lifted-Box-S))
(check-equal? (checked-term->raw lifted-Box-S) raw-hole)
(check-equal? (puncture-addresses lifted-Box-S) '(()))
(check-equal? (puncture-requirement lifted-Box-S '()) S)
(check-true (eq? (checked-term-calculus lifted-Box-S) K1))

;; An identity revision still creates a different registry object.  This
;; distinguishes target provenance even though both registries and checked
;; presentations are structurally equal.
(check-true (calculus-revision? identity-revision))
(check-equal? K0/copy K0)
(check-false (eq? K0/copy K0))
(check-equal? (calculus-revision-withdrawn-ids identity-revision) '())
(check-equal? (calculus-revision-additions identity-revision) '())
(define identity-lifted-t (lift-term identity-revision t))
(check-equal? identity-lifted-t t)
(check-true (eq? (checked-term-calculus identity-lifted-t) K0/copy))
(check-false (eq? (checked-term-calculus identity-lifted-t) K0))
(check-revision-failure
 (lift-term identity-revision identity-lifted-t)
 'wrong-source-calculus)

;; Proposition 1.5/base extension in one persistent case:
;; lift(fill(R,p)) = fill(lift(R),lift(p)).
(define source-filled (complete-fill R (list bS-proof)))
(check-equal? source-filled t)
(define lift-after-fill
  (lift-term persistent-revision source-filled))
(define fill-after-lift
  (complete-fill
   (lift-context persistent-revision R)
   (list (lift-term persistent-revision bS-proof))))
(check-true (complete-proof? lift-after-fill))
(check-true (complete-proof? fill-after-lift))
(check-equal? lift-after-fill fill-after-lift)
(check-equal? (checked-term->raw lift-after-fill) t-raw)
(check-equal? (checked-term->raw fill-after-lift) t-raw)
(check-true (eq? (checked-term-calculus lift-after-fill) K+))
(check-true (eq? (checked-term-calculus fill-after-lift) K+))

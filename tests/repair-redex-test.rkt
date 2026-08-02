#lang racket/base

(require rackunit
         "../potkin/kernel.rkt"
         "../potkin/model/kernel-redex.rkt")

;; Keep this fixture local: the Redex agreement checks should cross the public
;; raw bridge produced by revision and repair, not rely on a parallel model
;; fixture or a Redex-only representation.
(define S (singleton-hypersequent '() '(S)))
(define T (singleton-hypersequent '() '(T)))
(define U (singleton-hypersequent '() '(U)))
(define V (singleton-hypersequent '() '(V)))
(define ST (hypersequent-union S T))

(define bS-occ
  (make-concrete-occurrence
   'bS '() S #:kind 'material #:tag 'ground #:instance 'retired-S))
(define bS-keep-occ
  (make-concrete-occurrence
   'bS-keep '() S #:kind 'material #:tag 'ground #:instance 'retained-S))
(define bS-new-occ
  (make-concrete-occurrence
   'bS-new '() S #:kind 'material #:tag 'ground #:instance 'fresh-S))
(define bT-occ
  (make-concrete-occurrence
   'bT '() T #:kind 'material #:tag 'ground #:instance 'retired-T))
(define m-occ
  (make-concrete-occurrence
   'm (list S T) ST #:kind 'structural #:tag 'assembly))
(define i-occ
  (make-concrete-occurrence
   'i (list ST) U #:kind 'logical #:tag 'i))
;; A distinct retained constructor with exactly the same profile as i.  It is
;; well typed in Redex but does not preserve i in a particular repair context.
(define i-alt-occ
  (make-concrete-occurrence
   'i-alt (list ST) U #:kind 'logical #:tag 'i))
(define a-occ
  (make-concrete-occurrence
   'a (list S S) V #:kind 'logical #:tag 'a))

(define K0
  (make-equipped-calculus
   (list bS-occ bS-keep-occ bT-occ m-occ i-occ i-alt-occ a-occ)))
(define retire-bS-revision
  (make-calculus-revision K0 '(bS) (list bS-new-occ)))
(check-true (calculus-revision? retire-bS-revision))
(define K1 (calculus-revision-target retire-bS-revision))

(define t-raw
  (raw-app 'i
           (raw-app 'm
                    (raw-app 'bS)
                    (raw-app 'bT))))
(define t (validate-candidate K0 t-raw #:expected U))
(check-true (complete-proof? t))

;; The independent recursive judgment accepts the historical source exactly
;; where it was certified.  Withdrawal does not rewrite that history, but the
;; same raw presentation is no longer live in K1.
(check-true (redex-check? K0 t-raw U))
(check-equal? (redex-root-boundaries K0 t-raw) (list U))
(check-false (redex-check? K1 t-raw U))
(check-false (redex-valid? K1 t-raw))
(check-false (redex-check? K1 (raw-app 'bS) S))

(define plan (plan-ground-repair retire-bS-revision t))
(check-true (nonroot-ground-repair-plan? plan))
(check-true (ground-repair-plan? plan))

;; Both the historical cut remainder and its target-certified lift have the
;; same raw open presentation.  Redex checks each independently in its own
;; registry; a puncture needs no currently enumerated filler.
(define source-witness
  (nonroot-ground-repair-plan-source-witness plan))
(define source-remainder (cut-witness-remainder source-witness))
(define target-remainder
  (nonroot-ground-repair-plan-target-remainder plan))
(define source-remainder-raw (checked-term->raw source-remainder))
(define target-remainder-raw (checked-term->raw target-remainder))
(check-equal? source-remainder-raw target-remainder-raw)
(check-equal?
 target-remainder-raw
 (raw-app 'i (raw-app 'm raw-hole (raw-app 'bT))))
(check-true (redex-check? K0 source-remainder-raw U))
(check-true (redex-check? K1 target-remainder-raw U))
(check-equal? (redex-root-boundaries K1 target-remainder-raw) (list U))

(define bS-new/K1
  (validate-candidate K1 (raw-app 'bS-new) #:expected S))
(define bS-keep/K1
  (validate-candidate K1 (raw-app 'bS-keep) #:expected S))

;; Fresh and already-retained evidence are two distinct points of the same
;; exact filling fibre.  Every repaired raw result is judged directly by
;; Redex under K1.
(define repaired-with-new
  (apply-repair-plan plan (list bS-new/K1)))
(define repaired-with-retained
  (apply-repair-plan plan (list bS-keep/K1)))
(check-true (complete-proof? repaired-with-new))
(check-true (complete-proof? repaired-with-retained))
(for ([repaired (in-list (list repaired-with-new repaired-with-retained))])
  (define repaired-raw (checked-term->raw repaired))
  (check-true (redex-check? K1 repaired-raw U))
  (check-equal? (redex-root-boundaries K1 repaired-raw) (list U)))

;; The source witness remains a K0 reconstruction device using the original
;; detached ground.  It is not retroactively rebased into K1.
(define reconstructed (reconstruct-cut-witness source-witness))
(define reconstructed-raw (checked-term->raw reconstructed))
(check-equal? reconstructed t)
(check-true (eq? (checked-term-calculus reconstructed) K0))
(check-true (redex-check? K0 reconstructed-raw U))
(check-false (redex-check? K1 reconstructed-raw U))

;; Equal retired grounds at distinct addresses retain two independent holes.
;; The repaired result deliberately uses two different live S proofs.
(define repeated-source-raw
  (raw-app 'a (raw-app 'bS) (raw-app 'bS)))
(define repeated-source
  (validate-candidate K0 repeated-source-raw #:expected V))
(define repeated-plan
  (plan-ground-repair retire-bS-revision repeated-source))
(check-true (nonroot-ground-repair-plan? repeated-plan))
(define repeated-repaired
  (apply-repair-plan repeated-plan (list bS-new/K1 bS-keep/K1)))
(define repeated-repaired-raw (checked-term->raw repeated-repaired))
(check-equal?
 repeated-repaired-raw
 (raw-app 'a (raw-app 'bS-new) (raw-app 'bS-keep)))
(check-true (redex-check? K1 repeated-repaired-raw V))
(check-equal? (redex-root-boundaries K1 repeated-repaired-raw) (list V))

;; The theorem's excluded one-vertex source uses the separate whole-proof
;; endpoint.  Its Box^S target context checks with an external boundary but
;; does not synthesize one; applying the endpoint supplies the whole proof.
(define bS/K0 (validate-candidate K0 (raw-app 'bS) #:expected S))
(define whole-plan
  (plan-ground-repair retire-bS-revision bS/K0))
(check-true (whole-ground-replacement-plan? whole-plan))
(check-true
 (redex-check?
  K0
  (checked-term->raw
   (whole-ground-replacement-plan-detached-source whole-plan))
  S))
(check-false
 (redex-check?
  K1
  (checked-term->raw
   (whole-ground-replacement-plan-detached-source whole-plan))
  S))
(check-true
 (redex-check?
  K1
  (checked-term->raw
   (whole-ground-replacement-plan-target-identity-context whole-plan))
  S))
(check-false
 (redex-valid?
  K1
  (checked-term->raw
   (whole-ground-replacement-plan-target-identity-context whole-plan))))
(define whole-repaired
  (apply-repair-plan whole-plan (list bS-new/K1)))
(check-equal? (checked-term->raw whole-repaired) (raw-app 'bS-new))
(check-true (redex-check? K1 (checked-term->raw whole-repaired) S))

;; Redex checks typing and exact target admission, independently of repair.
;; It therefore rejects the relevant malformed or ill-typed raw candidates.
(check-false (redex-check? K1 (raw-app 'bS-new) T))
(check-false
 (redex-check?
  K1
  (raw-app 'i
           (raw-app 'm (raw-app 'bT) (raw-app 'bS-new)))
  U))
(check-false
 (redex-check? K1 (raw-app 'm (raw-app 'bS-new)) ST))
(check-false (redex-check? K1 (raw-app 'unknown-ground) S))
(for ([malformed (in-list (list '(app 17)
                                  '(not-a-candidate)
                                  (cons 'app
                                        (cons 'bS-new 'improper-tail))))])
  (check-false (redex-check? K1 malformed S)))

;; Redex accepts this target proof because i-alt is an admitted, type-correct
;; constructor.  Exact extraction rejects it because repair preserves the
;; retained i/m/bT presentation and permits variation only at its puncture.
(define different-retained-raw
  (raw-app 'i-alt
           (raw-app 'm
                    (raw-app 'bS-new)
                    (raw-app 'bT))))
(check-true (redex-check? K1 different-retained-raw U))
(check-equal? (redex-root-boundaries K1 different-retained-raw) (list U))
(define different-retained
  (validate-candidate K1 different-retained-raw #:expected U))
(check-true (complete-proof? different-retained))
(define extraction-result (extract-fillers plan different-retained))
(check-true (repair-error? extraction-result))
(check-true (repair-extraction-error? extraction-result))

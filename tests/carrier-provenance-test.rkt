#lang racket/base

(require racket/list
         rackunit
         "../potkin/kernel.rkt"
         "revision-fixtures.rkt")

;; Presentation equality deliberately omits provenance. These registries and
;; checked trees compare structurally equal while remaining distinct snapshots.
(define Kclone
  (make-equipped-calculus (calculus-occurrences K0)))
(define t/clone
  (validate-candidate Kclone t-raw #:expected U))
(define bS/clone
  (validate-candidate Kclone (raw-app 'bS) #:expected S))

(check-equal? K0 Kclone)
(check-false (eq? K0 Kclone))
(check-equal? t t/clone)
(check-false (eq? (checked-term-calculus t)
                  (checked-term-calculus t/clone)))
(check-true (checked-term-has-exact-calculus? t K0))
(check-true (checked-term-has-exact-calculus? t/clone Kclone))
(check-false (checked-term-has-exact-calculus? t/clone K0))
;; Extensional admission cannot authorize a carrier operation by itself.
(check-true (term-admitted-by? K0 t/clone))

;; Forest construction never silently rechecks or rebases a clone factor.
(check-exn exn:fail:contract?
           (lambda () (make-proof-forest K0 (list t/clone))))
(define t-forest/K0 (make-proof-forest K0 (list t t)))
(define t-forest/Kclone
  (make-proof-forest Kclone (list t/clone t/clone)))
(check-equal? t-forest/K0 t-forest/Kclone)
(check-equal? (proof-forest-count t-forest/K0 t) 2)
(check-equal?
 (proof-forest-count
  t-forest/K0
  (validate-candidate K0 (raw-app 'bT) #:expected T))
 0)
(check-exn exn:fail:contract?
           (lambda () (proof-forest-count t-forest/K0 t/clone)))
(for ([left+right
       (in-list
        (list (list t-forest/K0 t-forest/Kclone)
              (list t-forest/Kclone t-forest/K0)
              (list (empty-proof-forest K0)
                    (empty-proof-forest Kclone))
              (list (empty-proof-forest Kclone)
                    (empty-proof-forest K0))))])
  (check-exn exn:fail:contract?
             (lambda ()
               (forest-union (first left+right) (second left+right)))))
(check-equal?
 (proof-forest-size
  (forest-union t-forest/K0 (empty-proof-forest K0)))
 2)

;; Context filling also requires exact snapshot identity, even for a complete
;; replacement with the right whole hypersequent and extensional admission.
(check-true (term-admitted-by? K0 bS/clone))
(define cross-insert (context-insert R '(1 1) bS/clone))
(check-true (context-error? cross-insert))
(check-equal? (context-error-code cross-insert)
              'wrong-calculus-provenance)
(check-equal? (context-error-address cross-insert) '(1 1))
(check-true (eq? (context-error-expected cross-insert) K0))
(check-true (eq? (context-error-actual cross-insert) Kclone))
(define cross-fill (complete-fill R (list bS/clone)))
(check-true (context-error? cross-fill))
(check-equal? (context-error-code cross-fill)
              'wrong-calculus-provenance)

;; An explicit empty revision is the bridge between structurally equal
;; snapshots. Once every operand is lifted, all carrier operations succeed.
(define empty-revision (make-calculus-revision K0 '() '()))
(define K1/empty (calculus-revision-target empty-revision))
(define t/K1 (lift-term empty-revision t))
(define R/K1 (lift-context empty-revision R))
(define bS/K1 (lift-term empty-revision bS-proof))
(check-equal? K0 K1/empty)
(check-false (eq? K0 K1/empty))
(check-true (checked-term-has-exact-calculus? t/K1 K1/empty))
(define t-forest/K1 (make-proof-forest K1/empty (list t/K1 t/K1)))
(check-equal? (proof-forest-count t-forest/K1 t/K1) 2)
(check-exn exn:fail:contract?
           (lambda () (proof-forest-count t-forest/K1 t)))
(check-equal?
 (proof-forest-size
  (forest-union t-forest/K1 (empty-proof-forest K1/empty)))
 2)
(define explicitly-filled (context-insert R/K1 '(1 1) bS/K1))
(check-equal? explicitly-filled t/K1)
(check-true (eq? (checked-term-calculus explicitly-filled) K1/empty))
(check-equal?
 (context-error-code (context-insert R/K1 '(1 1) bS-proof))
 'wrong-calculus-provenance)

;; Hopf factors have at least one rule vertex. A rooted punctured corolla is
;; admissible, whereas either typed nodeless Box context is not.
(define m-corolla (corolla K0 'm))
(check-true (checked-node? m-corolla))
(check-true (proof-context? m-corolla))
(define punctured-forest (make-proof-forest K0 (list m-corolla)))
(check-equal? (proof-forest-count punctured-forest m-corolla) 1)
(for ([factor (in-list (proof-forest-factors punctured-forest))])
  (check-true (checked-term-has-exact-calculus? factor K0)))
(for ([box (in-list (list (identity-context K0 S)
                          (identity-context K0 T)))])
  (check-exn exn:fail:contract?
             (lambda () (make-proof-forest K0 (list box))))
  (define deletion-result (constructor-delete empty-revision box))
  (check-true (deletion-domain-error? deletion-result))
  (check-equal? (deletion-domain-error-code deletion-result)
                'not-positive-vertex-basis)
  (check-false (survivor? deletion-result))
  (check-false (algebraic-zero? deletion-result)))
(define punctured-node-deletion
  (constructor-delete empty-revision m-corolla))
(check-true (survivor? punctured-node-deletion))
(check-true (checked-node? (survivor-value punctured-node-deletion)))
(check-true
 (checked-term-has-exact-calculus?
  (survivor-value punctured-node-deletion) K1/empty))
(define punctured-deletion
  (constructor-delete empty-revision punctured-forest))
(check-true (survivor? punctured-deletion))
(check-true (proof-forest? (survivor-value punctured-deletion)))
(check-true
 (eq? (proof-forest-calculus (survivor-value punctured-deletion))
      K1/empty))

;; Stricter insertion and forest construction leave existing CK witnesses and
;; exact repair intact because their components already share provenance.
(define source-witness (make-cut-witness t '((1 1))))
(check-true (cut-witness? source-witness))
(check-true (cut-witness-reconstructs? source-witness))
(check-equal? (reconstruct-cut-witness source-witness) t)
(check-true
 (checked-term-has-exact-calculus?
  (cut-witness-remainder source-witness) K0))
(for ([factor
       (in-list
        (proof-forest-factors (cut-witness-forest source-witness)))])
  (check-true (checked-term-has-exact-calculus? factor K0)))

(define repair-plan (plan-ground-repair retire-bS-revision t))
(check-true (nonroot-ground-repair-plan? repair-plan))
(check-true
 (checked-term-has-exact-calculus?
  (ground-repair-plan-target-context repair-plan) K1))
(define bS-prime/K1
  (validate-candidate K1 (raw-app 'bS-prime) #:expected S))
(define repaired (apply-repair-plan repair-plan (list bS-prime/K1)))
(check-true (complete-proof? repaired))
(check-true (checked-term-has-exact-calculus? repaired K1))
(define extracted (extract-fillers repair-plan repaired))
(check-equal? extracted (list bS-prime/K1))
(check-equal? (apply-repair-plan repair-plan extracted) repaired)

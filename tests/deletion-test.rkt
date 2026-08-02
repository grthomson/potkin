#lang racket/base

(require racket/list
         rackunit
         "../potkin/kernel.rkt"
         "revision-fixtures.rkt")

(define (offense-addresses zero)
  (map constructor-offense-address (algebraic-zero-offenses zero)))

(define (offense-ids zero)
  (map constructor-offense-occurrence-id
       (algebraic-zero-offenses zero)))

(define (offense-multiplicities zero)
  (map constructor-offense-multiplicity
       (algebraic-zero-offenses zero)))

;; q_D kills a connected basis proof explicitly and retains its exact
;; historical source plus every offending local address and identity.
(define t-zero (constructor-delete retire-bS-revision t))
(check-true (algebraic-zero? t-zero))
(check-false (survivor? t-zero))
(check-false (eq? t-zero #f))
(check-true (eq? (algebraic-zero-historical-source t-zero) t))
(check-equal? (offense-addresses t-zero) '((1 1)))
(check-equal? (offense-ids t-zero) '(bS))
(check-equal? (offense-multiplicities t-zero) '(1))
(define t-offense (first (algebraic-zero-offenses t-zero)))
(check-true (constructor-offense? t-offense))
(check-true (eq? (constructor-offense-factor t-offense) t))
(check-true (eq? (constructor-offense-occurrence t-offense) bS-occ))
(check-false (checked-term? t-zero))
(check-false (proof-forest? t-zero))
(check-false (equal? t-zero (empty-proof-forest K1)))
(check-false (equal? t-zero (identity-context K1 U)))
(check-true (term-historically-valid? t))
(check-true (eq? (checked-term-calculus t) K0))

;; A clean connected basis proof survives as a target-certified lift.  Its
;; presentation is unchanged while its operational provenance is K1.
(define retained-survivor
  (constructor-delete retire-bS-revision retained-proof))
(check-true (survivor? retained-survivor))
(check-false (algebraic-zero? retained-survivor))
(define retained/K1 (survivor-value retained-survivor))
(check-true (complete-proof? retained/K1))
(check-equal? retained/K1 retained-proof)
(check-equal? (checked-term->raw retained/K1)
              (checked-term->raw retained-proof))
(check-true (eq? (checked-term-calculus retained/K1) K1))
(check-false (eq? (checked-term-calculus retained/K1) K0))

;; A forest monomial is killed as a whole.  Its clean factors are not returned
;; as a smaller forest, and the exact original monomial remains inspectable.
(define mixed-forest
  (make-proof-forest K0 (list retained-proof t bT-proof)))
(define mixed-zero
  (constructor-delete retire-bS-revision mixed-forest))
(check-true (algebraic-zero? mixed-zero))
(check-false (survivor? mixed-zero))
(check-true (eq? (algebraic-zero-historical-source mixed-zero)
                 mixed-forest))
(check-equal? (proof-forest-size mixed-forest) 3)
(check-equal? (offense-addresses mixed-zero) '((1 1)))
(check-equal? (offense-ids mixed-zero) '(bS))
(check-equal? (offense-multiplicities mixed-zero) '(1))
(define mixed-offense (first (algebraic-zero-offenses mixed-zero)))
(check-true
 (ormap (lambda (factor)
          (eq? factor (constructor-offense-factor mixed-offense)))
        (proof-forest-factors mixed-forest)))
(check-false (proof-forest? mixed-zero))

;; Equal bad factors are one commutative factor with multiplicity two; the
;; offense record does not invent an ordering between equal occurrences.
(define doubled-bad-forest (make-proof-forest K0 (list t t)))
(define doubled-bad-zero
  (constructor-delete retire-bS-revision doubled-bad-forest))
(check-true (algebraic-zero? doubled-bad-zero))
(check-equal? (length (algebraic-zero-offenses doubled-bad-zero)) 1)
(check-equal? (offense-addresses doubled-bad-zero) '((1 1)))
(check-equal? (offense-ids doubled-bad-zero) '(bS))
(check-equal? (offense-multiplicities doubled-bad-zero) '(2))
(check-equal?
 (proof-forest-count
  doubled-bad-forest
  (constructor-offense-factor
   (first (algebraic-zero-offenses doubled-bad-zero))))
 2)

;; Distinct occurrences inside one connected factor retain separate local
;; addresses even when their one-vertex subproofs are structurally equal.
(define repeated-bS-proof
  (validate-candidate
   K0
   (raw-app 'a (raw-app 'bS) (raw-app 'bS))
   #:expected V))
(define repeated-bS-zero
  (constructor-delete retire-bS-revision repeated-bS-proof))
(check-true (algebraic-zero? repeated-bS-zero))
(check-equal? (offense-addresses repeated-bS-zero) '((1) (2)))
(check-equal? (offense-ids repeated-bS-zero) '(bS bS))
(check-equal? (offense-multiplicities repeated-bS-zero) '(1 1))
(for ([offense (in-list (algebraic-zero-offenses repeated-bS-zero))])
  (check-true (eq? (constructor-offense-factor offense)
                   repeated-bS-proof))
  (check-true (eq? (constructor-offense-occurrence offense) bS-occ)))

;; The commutative algebra unit survives and is rebuilt under the target.  It
;; is neither algebraic zero nor the nodeless identity context.
(define empty/K0 (empty-proof-forest K0))
(define empty-result
  (constructor-delete retire-bS-revision empty/K0))
(check-true (survivor? empty-result))
(check-false (algebraic-zero? empty-result))
(define empty/K1 (survivor-value empty-result))
(check-true (proof-forest? empty/K1))
(check-true (proof-forest-empty? empty/K1))
(check-equal? (proof-forest-size empty/K1) 0)
(check-true (eq? (proof-forest-calculus empty/K1) K1))
(check-false (equal? empty/K1 (identity-context K1 U)))

;; D = empty is the identity on basis presentations, while still performing
;; an explicit checked rebase into the revision's distinct target registry.
(define identity-result (constructor-delete identity-revision t))
(check-true (survivor? identity-result))
(check-false (algebraic-zero? identity-result))
(check-equal? (survivor-value identity-result) t)
(check-equal? (checked-term->raw (survivor-value identity-result)) t-raw)
(check-true (eq? (checked-term-calculus (survivor-value identity-result))
                 K0/copy))
(check-false (eq? (checked-term-calculus (survivor-value identity-result))
                  K0))

;; Typed idempotence is expressed by an empty revision whose source is the
;; first projection's target.  No unchecked cast sends a K1 proof back to K0.
(define K1-empty-revision (make-calculus-revision K1 '() '()))
(define retained-twice
  (constructor-delete K1-empty-revision retained/K1))
(check-true (survivor? retained-twice))
(check-equal? (survivor-value retained-twice) retained/K1)
(check-equal? (checked-term->raw (survivor-value retained-twice))
              (checked-term->raw retained/K1))
(check-true
 (eq? (checked-term-calculus (survivor-value retained-twice))
      (calculus-revision-target K1-empty-revision)))
(check-false
 (eq? (checked-term-calculus (survivor-value retained-twice)) K1))

;; Sequential deletion by disjoint D1,D2 agrees observationally with direct
;; deletion by their union.  The comparison covers killing at the first step,
;; killing at the second step, and surviving both steps.
(define D1-revision (make-calculus-revision K0 '(bS) '()))
(define K/D1 (calculus-revision-target D1-revision))
(define D2-after-D1-revision
  (make-calculus-revision K/D1 '(bT) '()))
(define K/D1/D2
  (calculus-revision-target D2-after-D1-revision))
(define D1-union-D2-revision
  (make-calculus-revision K0 '(bS bT) '()))
(define K/D12 (calculus-revision-target D1-union-D2-revision))
(check-equal? K/D1/D2 K/D12)
(check-false (eq? K/D1/D2 K/D12))

(define t-after-D1 (constructor-delete D1-revision t))
(define t-after-union (constructor-delete D1-union-D2-revision t))
(check-true (algebraic-zero? t-after-D1))
(check-true (algebraic-zero? t-after-union))
(check-equal? (offense-addresses t-after-D1) '((1 1)))
(check-equal? (offense-ids t-after-D1) '(bS))
(check-equal? (offense-addresses t-after-union) '((1 1) (1 2)))
(check-equal? (offense-ids t-after-union) '(bS bT))

(define bT-after-D1 (constructor-delete D1-revision bT-proof))
(check-true (survivor? bT-after-D1))
(define bT-after-D1-then-D2
  (constructor-delete D2-after-D1-revision
                      (survivor-value bT-after-D1)))
(define bT-after-union
  (constructor-delete D1-union-D2-revision bT-proof))
(check-true (algebraic-zero? bT-after-D1-then-D2))
(check-true (algebraic-zero? bT-after-union))
(check-equal? (offense-addresses bT-after-D1-then-D2) '(()))
(check-equal? (offense-addresses bT-after-union) '(()))
(check-equal? (offense-ids bT-after-D1-then-D2) '(bT))
(check-equal? (offense-ids bT-after-union) '(bT))

(define retained-after-D1
  (constructor-delete D1-revision retained-proof))
(check-true (survivor? retained-after-D1))
(define retained-after-D1-then-D2
  (constructor-delete D2-after-D1-revision
                      (survivor-value retained-after-D1)))
(define retained-after-union
  (constructor-delete D1-union-D2-revision retained-proof))
(check-true (survivor? retained-after-D1-then-D2))
(check-true (survivor? retained-after-union))
(check-equal? (survivor-value retained-after-D1-then-D2)
              (survivor-value retained-after-union))
(check-equal? (checked-term->raw
               (survivor-value retained-after-D1-then-D2))
              (checked-term->raw (survivor-value retained-after-union)))
(check-true
 (eq? (checked-term-calculus
       (survivor-value retained-after-D1-then-D2))
      K/D1/D2))
(check-true
 (eq? (checked-term-calculus (survivor-value retained-after-union))
      K/D12))

;; Same-profile fresh evidence is live in K1, but cannot revive the retired
;; concrete occurrence decorating the historical source proof.
(check-equal? (concrete-occurrence-conclusion bS-prime-occ)
              (concrete-occurrence-conclusion bS-occ))
(check-not-equal? (concrete-occurrence-id bS-prime-occ)
                  (concrete-occurrence-id bS-occ))
(check-true (calculus-admits? K1 bS-prime-occ))
(check-false (calculus-admits? K1 bS-occ))
(check-true (algebraic-zero? t-zero))
(check-equal? (offense-ids t-zero) '(bS))

;; Finite witness-level coideal oracle for a killed proof: at every CK cut,
;; the exact retired occurrence lies in the detached forest or the retained
;; remainder.  Reconstruction continues to use historical K0 evidence.
(define t-witnesses
  (for/list ([witness (in-admissible-cut-witnesses t)]) witness))
(check-equal? (length t-witnesses) 5)
(for ([witness (in-list t-witnesses)])
  (check-true (cut-witness-reconstructs? witness))
  (define reconstructed (reconstruct-cut-witness witness))
  (check-equal? reconstructed t)
  (check-true (eq? (checked-term-calculus reconstructed) K0))
  (define source-result
    (constructor-delete retire-bS-revision
                        (cut-witness-source witness)))
  (define detached-result
    (constructor-delete retire-bS-revision
                        (cut-witness-forest witness)))
  (define remainder-result
    (constructor-delete retire-bS-revision
                        (cut-witness-remainder witness)))
  (check-true (algebraic-zero? source-result))
  (check-true (or (algebraic-zero? detached-result)
                  (algebraic-zero? remainder-result))))

;; Conversely, every factor of every cut witness of a retained source also
;; survives and is certified in the revision target.
(define retained-witnesses
  (for/list ([witness (in-admissible-cut-witnesses retained-proof)])
    witness))
(check-equal? (length retained-witnesses) 4)
(for ([witness (in-list retained-witnesses)])
  (check-true (cut-witness-reconstructs? witness))
  (check-equal? (reconstruct-cut-witness witness) retained-proof)
  (define source-result
    (constructor-delete retire-bS-revision
                        (cut-witness-source witness)))
  (define detached-result
    (constructor-delete retire-bS-revision
                        (cut-witness-forest witness)))
  (define remainder-result
    (constructor-delete retire-bS-revision
                        (cut-witness-remainder witness)))
  (check-true (survivor? source-result))
  (check-true (survivor? detached-result))
  (check-true (survivor? remainder-result)))

;; Wrong historical provenance is a revision error, never algebraic zero.
;; K0/copy is structurally equal to K0 but is a distinct certified registry.
(define t/K0-copy (survivor-value identity-result))
(define wrong-source-result
  (constructor-delete retire-bS-revision t/K0-copy))
(check-true (revision-error? wrong-source-result))
(check-equal? (revision-error-code wrong-source-result)
              'wrong-source-calculus)
(check-false (algebraic-zero? wrong-source-result))
(check-false (survivor? wrong-source-result))

(define empty/K0-copy (empty-proof-forest K0/copy))
(define wrong-source-empty-result
  (constructor-delete retire-bS-revision empty/K0-copy))
(check-true (revision-error? wrong-source-empty-result))
(check-equal? (revision-error-code wrong-source-empty-result)
              'wrong-source-calculus)
(check-false (algebraic-zero? wrong-source-empty-result))

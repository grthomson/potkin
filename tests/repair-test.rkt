#lang racket/base

(require racket/list
         rackunit
         "../potkin/kernel.rkt"
         "revision-fixtures.rkt")

(define (check-repair-error result phase code)
  (check-true (repair-error? result))
  (check-equal? (repair-error-phase result) phase)
  (check-equal? (repair-error-code result) code)
  (check-true (string? (repair-error-message result)))
  (check-false (string=? (repair-error-message result) ""))
  (check-true (hash? (repair-error-details result)))
  (check-equal? (repair-scope-error? result) (eq? phase 'scope))
  (check-equal? (repair-application-error? result)
                (eq? phase 'application))
  (check-equal? (repair-extraction-error? result)
                (eq? phase 'extraction)))

(define (plan-telescope-addresses plan)
  (map telescope-entry-address (ground-repair-plan-telescope plan)))

(define (plan-telescope-requirements plan)
  (map telescope-entry-requirement (ground-repair-plan-telescope plan)))

(define (detached-addresses witness)
  (map detached-entry-address (cut-witness-detached witness)))

(define (detached-ids witness)
  (map (lambda (entry)
         (concrete-occurrence-id
          (checked-node-occurrence (detached-entry-term entry))))
       (cut-witness-detached witness)))

(define (scope-issues error)
  (hash-ref (repair-error-details error) 'scope-issues '()))

(define (scope-reasons error)
  (map repair-scope-issue-reason (scope-issues error)))

;; Retiring the exact bS occurrence exposes the one leaf at (1 1).  The plan
;; retains both its historical K0 cut witness and the lifted K1 remainder.
(define bS-plan (plan-ground-repair retire-bS-revision t))
(check-true (ground-repair-plan? bS-plan))
(check-true (nonroot-ground-repair-plan? bS-plan))
(check-false (whole-ground-replacement-plan? bS-plan))
(check-true (eq? (nonroot-ground-repair-plan-revision bS-plan)
                 retire-bS-revision))
(check-true (eq? (ground-repair-plan-revision bS-plan)
                 retire-bS-revision))
(check-true (eq? (ground-repair-plan-source bS-plan) t))
(check-equal? (ground-repair-plan-addresses bS-plan) '((1 1)))

(define bS-source-witness
  (nonroot-ground-repair-plan-source-witness bS-plan))
(check-true (cut-witness? bS-source-witness))
(check-true (eq? (cut-witness-source bS-source-witness) t))
(check-equal? (cut-witness-addresses bS-source-witness) '((1 1)))
(check-equal? (detached-addresses bS-source-witness) '((1 1)))
(check-equal? (detached-ids bS-source-witness) '(bS))
(check-equal? (proof-forest-size
               (cut-witness-forest bS-source-witness))
              1)
(check-equal? (proof-forest-count
               (cut-witness-forest bS-source-witness)
               bS-proof)
              1)
(check-equal? (checked-term->raw
               (cut-witness-remainder bS-source-witness))
              (raw-app 'i
                       (raw-app 'm raw-hole (raw-app 'bT))))
(check-equal?
 (map telescope-entry-address
      (premise-telescope (cut-witness-remainder bS-source-witness)))
 '((1 1)))
(check-equal?
 (map telescope-entry-requirement
      (premise-telescope (cut-witness-remainder bS-source-witness)))
 (list S))
(check-true
 (term-historically-valid? (cut-witness-remainder bS-source-witness)))
(check-true
 (revision-term-live? retire-bS-revision
                      (cut-witness-remainder bS-source-witness)))
(check-true
 (eq? (checked-term-calculus
       (cut-witness-remainder bS-source-witness))
      K0))
(check-true (cut-witness-reconstructs? bS-source-witness))
(define bS-reconstructed (reconstruct-cut-witness bS-source-witness))
(check-equal? bS-reconstructed t)
(check-true (eq? (checked-term-calculus bS-reconstructed) K0))

(define bS-target-remainder
  (nonroot-ground-repair-plan-target-remainder bS-plan))
(check-true (eq? (ground-repair-plan-target-context bS-plan)
                 bS-target-remainder))
(check-true (proof-context? bS-target-remainder))
(check-equal? bS-target-remainder
              (cut-witness-remainder bS-source-witness))
(check-equal? (checked-term->raw bS-target-remainder)
              (raw-app 'i
                       (raw-app 'm raw-hole (raw-app 'bT))))
(check-true (eq? (checked-term-calculus bS-target-remainder) K1))
(check-false (eq? (checked-term-calculus bS-target-remainder) K0))
(check-true (term-live-in? K1 bS-target-remainder
                           #:retired-ids '(bS)))
(check-equal? (puncture-addresses bS-target-remainder) '((1 1)))
(check-equal? (plan-telescope-addresses bS-plan) '((1 1)))
(check-equal? (plan-telescope-requirements bS-plan) (list S))
(check-equal? (ground-repair-plan-telescope bS-plan)
              (premise-telescope bS-target-remainder))

;; The planner never chooses or enumerates evidence.  Applying its fixed open
;; context requires an explicit address-ordered list of complete K1 proofs.
(define no-automatic-choice (apply-repair-plan bS-plan '()))
(check-repair-error no-automatic-choice 'application 'wrong-filler-count)
(check-equal? (repair-error-expected no-automatic-choice) 1)
(check-equal? (repair-error-actual no-automatic-choice) 0)

(define bS-prime/K1
  (validate-candidate K1 (raw-app 'bS-prime) #:expected S))
(define repaired-with-prime
  (apply-repair-plan bS-plan (list bS-prime/K1)))
(check-true (complete-proof? repaired-with-prime))
(check-equal? (checked-term->raw repaired-with-prime)
              (raw-app 'i
                       (raw-app 'm
                                (raw-app 'bS-prime)
                                (raw-app 'bT))))
(check-true (eq? (checked-term-calculus repaired-with-prime) K1))
(check-equal? (derivation-root-boundary repaired-with-prime) U)
(check-equal? (reconstruct-cut-witness bS-source-witness) t)

;; Whole-boundary equality is necessary but not sufficient.  Old bS has the
;; right S boundary yet is inactive; live T and U proofs fail by boundary.
(define old-bS-result
  (apply-repair-plan bS-plan (list bS-proof)))
(check-repair-error old-bS-result 'application 'inactive-filler)
(check-equal? (repair-error-address old-bS-result) '(1 1))
(check-equal? (repair-error-expected old-bS-result) S)
(check-equal? (repair-error-actual old-bS-result) S)

(define bT/K1
  (validate-candidate K1 (raw-app 'bT) #:expected T))
(define wrong-T-result
  (apply-repair-plan bS-plan (list bT/K1)))
(check-repair-error wrong-T-result 'application 'wrong-filler-boundary)
(check-equal? (repair-error-address wrong-T-result) '(1 1))
(check-equal? (repair-error-expected wrong-T-result) S)
(check-equal? (repair-error-actual wrong-T-result) T)

(define live-U/K1
  (validate-candidate
   K1
   (raw-app 'i
            (raw-app 'm (raw-app 'bS-keep) (raw-app 'bT)))
   #:expected U))
(define wrong-U-result
  (apply-repair-plan bS-plan (list live-U/K1)))
(check-repair-error wrong-U-result 'application 'wrong-filler-boundary)
(check-equal? (repair-error-address wrong-U-result) '(1 1))
(check-equal? (repair-error-expected wrong-U-result) S)
(check-equal? (repair-error-actual wrong-U-result) U)

(define source-bS-keep-result
  (apply-repair-plan bS-plan (list bS-keep-proof)))
(check-repair-error source-bS-keep-result
                    'application
                    'wrong-target-calculus)

;; With both historical grounds retired, the exact address order is S then T.
(define bT-prime-occ
  (make-concrete-occurrence
   'bT-prime '() T #:kind 'material #:tag 'ground #:instance 'T-prime))
(define retire-bS+bT-revision
  (make-calculus-revision K0 '(bS bT)
                          (list bS-prime-occ bT-prime-occ)))
(define K/ST-prime
  (calculus-revision-target retire-bS+bT-revision))
(define bS+bT-plan
  (plan-ground-repair retire-bS+bT-revision t))
(check-true (nonroot-ground-repair-plan? bS+bT-plan))
(check-equal? (ground-repair-plan-addresses bS+bT-plan)
              '((1 1) (1 2)))
(check-equal? (plan-telescope-addresses bS+bT-plan)
              '((1 1) (1 2)))
(check-equal? (plan-telescope-requirements bS+bT-plan) (list S T))
(define bS+bT-witness
  (nonroot-ground-repair-plan-source-witness bS+bT-plan))
(check-equal? (detached-addresses bS+bT-witness)
              '((1 1) (1 2)))
(check-equal? (detached-ids bS+bT-witness) '(bS bT))
(check-equal? (proof-forest-size (cut-witness-forest bS+bT-witness)) 2)
(check-equal? (proof-forest-count
               (cut-witness-forest bS+bT-witness) bS-proof)
              1)
(check-equal? (proof-forest-count
               (cut-witness-forest bS+bT-witness) bT-proof)
              1)
(check-equal? (checked-term->raw
               (cut-witness-remainder bS+bT-witness))
              (raw-app 'i (raw-app 'm raw-hole raw-hole)))
(check-equal? (checked-term->raw
               (ground-repair-plan-target-context bS+bT-plan))
              (raw-app 'i (raw-app 'm raw-hole raw-hole)))
(check-true
 (eq? (checked-term-calculus
       (ground-repair-plan-target-context bS+bT-plan))
      K/ST-prime))
(check-equal? (reconstruct-cut-witness bS+bT-witness) t)

(define bS-prime/KST
  (validate-candidate K/ST-prime (raw-app 'bS-prime) #:expected S))
(define bT-prime/KST
  (validate-candidate K/ST-prime (raw-app 'bT-prime) #:expected T))
(define repaired-both
  (apply-repair-plan bS+bT-plan
                     (list bS-prime/KST bT-prime/KST)))
(check-true (complete-proof? repaired-both))
(check-equal? (checked-term->raw repaired-both)
              (raw-app 'i
                       (raw-app 'm
                                (raw-app 'bS-prime)
                                (raw-app 'bT-prime))))
(check-true (eq? (checked-term-calculus repaired-both) K/ST-prime))
(define swapped-both-result
  (apply-repair-plan bS+bT-plan
                     (list bT-prime/KST bS-prime/KST)))
(check-repair-error swapped-both-result
                    'application
                    'wrong-filler-boundary)
(check-equal? (repair-error-address swapped-both-result) '(1 1))
(check-equal? (repair-error-expected swapped-both-result) S)
(check-equal? (repair-error-actual swapped-both-result) T)

;; Equal detached grounds retain two aligned occurrences and forest
;; multiplicity two.  Their holes may receive different live S proofs.
(define repeated-source
  (validate-candidate
   K0
   (raw-app 'a (raw-app 'bS) (raw-app 'bS))
   #:expected V))
(define repeated-plan
  (plan-ground-repair retire-bS-revision repeated-source))
(check-true (nonroot-ground-repair-plan? repeated-plan))
(check-equal? (ground-repair-plan-addresses repeated-plan) '((1) (2)))
(check-equal? (plan-telescope-addresses repeated-plan) '((1) (2)))
(check-equal? (plan-telescope-requirements repeated-plan) (list S S))
(define repeated-witness
  (nonroot-ground-repair-plan-source-witness repeated-plan))
(check-equal? (detached-addresses repeated-witness) '((1) (2)))
(check-equal? (detached-ids repeated-witness) '(bS bS))
(check-equal? (proof-forest-size (cut-witness-forest repeated-witness)) 2)
(check-equal? (proof-forest-count
               (cut-witness-forest repeated-witness) bS-proof)
              2)
(check-equal? (checked-term->raw
               (ground-repair-plan-target-context repeated-plan))
              (raw-app 'a raw-hole raw-hole))

(define bS-keep/K1
  (validate-candidate K1 (raw-app 'bS-keep) #:expected S))
(define distinct-fillers (list bS-prime/K1 bS-keep/K1))
(define repeated-filled
  (apply-repair-plan repeated-plan distinct-fillers))
(check-true (complete-proof? repeated-filled))
(check-equal? (checked-term->raw repeated-filled)
              (raw-app 'a
                       (raw-app 'bS-prime)
                       (raw-app 'bS-keep)))
(check-true (eq? (checked-term-calculus repeated-filled) K1))

;; First round trip: extraction in address order is inverse to filling.
(define extracted-distinct
  (extract-fillers repeated-plan repeated-filled))
(check-true (list? extracted-distinct))
(check-false (repair-error? extracted-distinct))
(check-equal? extracted-distinct distinct-fillers)
(check-equal? (map checked-term->raw extracted-distinct)
              (list (raw-app 'bS-prime) (raw-app 'bS-keep)))
(check-equal? (apply-repair-plan repeated-plan extracted-distinct)
              repeated-filled)

;; Second round trip: an independently checked candidate preserving exactly
;; this retained context is recovered from, and rebuilt with, its subproofs.
(define preserving-candidate
  (validate-candidate
   K1
   (raw-app 'a (raw-app 'bS-keep) (raw-app 'bS-prime))
   #:expected V))
(define preserving-extracted
  (extract-fillers repeated-plan preserving-candidate))
(check-true (list? preserving-extracted))
(check-equal? (map checked-term->raw preserving-extracted)
              (list (raw-app 'bS-keep) (raw-app 'bS-prime)))
(check-equal? (apply-repair-plan repeated-plan preserving-extracted)
              preserving-candidate)

;; Same profile is not retained identity: an alternative target-admitted root
;; constructor does not belong to the fixed a-context repair fibre.
(define a-alt-occ
  (make-concrete-occurrence
   'a-alt (list S S) V #:kind 'logical #:tag 'a-alt))
(define alternate-retained-revision
  (make-calculus-revision K0 '(bS)
                          (list bS-prime-occ a-alt-occ)))
(define K1+a-alt
  (calculus-revision-target alternate-retained-revision))
(define alternate-plan
  (plan-ground-repair alternate-retained-revision repeated-source))
(check-true (nonroot-ground-repair-plan? alternate-plan))
(define alternate-candidate
  (validate-candidate
   K1+a-alt
   (raw-app 'a-alt (raw-app 'bS-prime) (raw-app 'bS-keep))
   #:expected V))
(define alternate-extraction
  (extract-fillers alternate-plan alternate-candidate))
(check-repair-error alternate-extraction
                    'extraction
                    'retained-context-mismatch)
(check-equal? (repair-error-address alternate-extraction) root-address)
(check-equal? (repair-error-expected alternate-extraction) a-occ)
(check-equal? (repair-error-actual alternate-extraction) a-alt-occ)

;; A withdrawn one-vertex ground is a separate whole-proof replacement
;; endpoint.  It uses Box^S and never manufactures a CK root cut.
(define whole-plan
  (plan-ground-repair retire-bS-revision bS-proof))
(check-true (ground-repair-plan? whole-plan))
(check-true (whole-ground-replacement-plan? whole-plan))
(check-false (nonroot-ground-repair-plan? whole-plan))
(check-true (eq? (whole-ground-replacement-plan-revision whole-plan)
                 retire-bS-revision))
(check-true (eq? (ground-repair-plan-revision whole-plan)
                 retire-bS-revision))
(check-true (eq? (whole-ground-replacement-plan-detached-source whole-plan)
                 bS-proof))
(check-true (eq? (ground-repair-plan-source whole-plan) bS-proof))
(define Box-S/K1
  (whole-ground-replacement-plan-target-identity-context whole-plan))
(check-true (eq? (ground-repair-plan-target-context whole-plan) Box-S/K1))
(check-true (proof-context? Box-S/K1))
(check-equal? (checked-term->raw Box-S/K1) raw-hole)
(check-equal? (derivation-root-boundary Box-S/K1) S)
(check-true (eq? (checked-term-calculus Box-S/K1) K1))
(check-equal? (ground-repair-plan-addresses whole-plan)
              (list root-address))
(check-equal? (plan-telescope-addresses whole-plan)
              (list root-address))
(check-equal? (plan-telescope-requirements whole-plan) (list S))
(check-equal? (apply-repair-plan whole-plan (list bS-prime/K1))
              bS-prime/K1)
(define whole-extracted
  (extract-fillers whole-plan bS-prime/K1))
(check-equal? whole-extracted (list bS-prime/K1))
(check-equal? (apply-repair-plan whole-plan whole-extracted)
              bS-prime/K1)
(check-equal? (for/list ([cut (in-admissible-cuts bS-proof)]) cut)
              (list '()))
(check-false (member (list root-address)
                     (for/list ([cut (in-admissible-cuts bS-proof)]) cut)))
(define forbidden-root-witness
  (make-cut-witness bS-proof (list root-address)))
(check-true (cut-error? forbidden-root-witness))
(check-equal? (cut-error-code forbidden-root-witness) 'root-cut)

;; Scope errors retain every relevant reason.  Build explicit material,
;; logical, and structural fixtures rather than inferring kind from names.
(define positive-material-occ
  (make-concrete-occurrence
   'positive-material (list S) S #:kind 'material #:tag 'material-rule))
(define nullary-logical-occ
  (make-concrete-occurrence
   'nullary-logical '() S #:kind 'logical #:tag 'logical-ground))
(define nullary-structural-occ
  (make-concrete-occurrence
   'nullary-structural '() S #:kind 'structural #:tag 'structural-ground))
(define scope-calculus
  (make-equipped-calculus
   (append (calculus-occurrences K0)
           (list positive-material-occ
                 nullary-logical-occ
                 nullary-structural-occ))))

(define positive-material-proof
  (validate-candidate
   scope-calculus
   (raw-app 'positive-material (raw-app 'bS))
   #:expected S))
(define positive-material-revision
  (make-calculus-revision scope-calculus '(positive-material) '()))
(define positive-material-error
  (plan-ground-repair positive-material-revision positive-material-proof))
(check-repair-error positive-material-error
                    'scope
                    'unsupported-repair-scope)
(check-true (andmap repair-scope-issue?
                    (scope-issues positive-material-error)))
(check-equal? (scope-reasons positive-material-error) '(positive-arity))
(check-equal? (map repair-scope-issue-address
                   (scope-issues positive-material-error))
              (list root-address))
(check-true (eq? (repair-scope-issue-occurrence
                  (first (scope-issues positive-material-error)))
                 positive-material-occ))

(define nullary-logical-proof
  (validate-candidate scope-calculus
                      (raw-app 'nullary-logical)
                      #:expected S))
(define nullary-logical-revision
  (make-calculus-revision scope-calculus '(nullary-logical) '()))
(define nullary-logical-error
  (plan-ground-repair nullary-logical-revision nullary-logical-proof))
(check-repair-error nullary-logical-error
                    'scope
                    'unsupported-repair-scope)
(check-equal? (scope-reasons nullary-logical-error) '(logical))
(check-equal? (map concrete-occurrence-kind
                    (map repair-scope-issue-occurrence
                         (scope-issues nullary-logical-error)))
              '(logical))

(define nullary-structural-proof
  (validate-candidate scope-calculus
                      (raw-app 'nullary-structural)
                      #:expected S))
(define nullary-structural-revision
  (make-calculus-revision scope-calculus '(nullary-structural) '()))
(define nullary-structural-error
  (plan-ground-repair nullary-structural-revision
                      nullary-structural-proof))
(check-repair-error nullary-structural-error
                    'scope
                    'unsupported-repair-scope)
(check-equal? (scope-reasons nullary-structural-error) '(structural))
(check-equal? (map concrete-occurrence-kind
                    (map repair-scope-issue-occurrence
                         (scope-issues nullary-structural-error)))
              '(structural))

;; The existing positive-arity structural m is generically deleted, but it is
;; outside automatic ground repair.
(define retire-m-revision (make-calculus-revision K0 '(m) '()))
(define m-zero (constructor-delete retire-m-revision t))
(check-true (algebraic-zero? m-zero))
(check-equal? (map constructor-offense-address
                   (algebraic-zero-offenses m-zero))
              '((1)))
(define m-scope-error (plan-ground-repair retire-m-revision t))
(check-repair-error m-scope-error 'scope 'unsupported-repair-scope)
(check-not-false (member 'structural (scope-reasons m-scope-error)))
(check-not-false (member 'positive-arity (scope-reasons m-scope-error)))

;; Deleting m together with its bS descendant reports the unsupported
;; ancestor/descendant frontier structurally; it never calls CK with a bad
;; antichain and never turns the error into a repair plan.
(define retire-m+bS-revision
  (make-calculus-revision K0 '(m bS) '()))
(check-true (algebraic-zero?
             (constructor-delete retire-m+bS-revision t)))
(define m+bS-scope-error
  (plan-ground-repair retire-m+bS-revision t))
(check-true (repair-scope-error? m+bS-scope-error))
(check-not-false (memq (repair-error-code m+bS-scope-error)
                       '(unsupported-repair-scope invalid-repair-frontier)))
(check-false (cut-error? m+bS-scope-error))
(check-not-false (member 'structural (scope-reasons m+bS-scope-error)))
(check-not-false (member 'positive-arity (scope-reasons m+bS-scope-error)))
(check-not-false (member 'ancestor-descendant
                         (scope-reasons m+bS-scope-error)))
(define ancestry-issue
  (findf (lambda (issue)
           (eq? (repair-scope-issue-reason issue)
                'ancestor-descendant))
         (scope-issues m+bS-scope-error)))
(check-true (repair-scope-issue? ancestry-issue))
(check-equal? (hash-ref (repair-scope-issue-details ancestry-issue)
                        'ancestor)
              '(1))
(check-equal? (hash-ref (repair-scope-issue-details ancestry-issue)
                        'descendant)
              '(1 1))

;; A complete proof from the wrong historical registry can still be diagnosed
;; against K1.  Same ID plus a different occurrence is incompatible/redefined,
;; not a withdrawn ground repair.
(define incompatible-bS-keep-occ
  (make-concrete-occurrence
   'bS-keep '() S
   #:kind 'material #:tag 'ground #:instance 'foreign-bS-keep))
(define incompatible-source-calculus
  (make-equipped-calculus (list incompatible-bS-keep-occ)))
(define incompatible-source-proof
  (validate-candidate incompatible-source-calculus
                      (raw-app 'bS-keep)
                      #:expected S))
(define wrong-source-error
  (plan-ground-repair retire-bS-revision incompatible-source-proof))
(check-repair-error wrong-source-error 'scope 'wrong-source-calculus)
(define wrong-source-diagnostics
  (hash-ref (repair-error-details wrong-source-error)
            'liveness-diagnostics))
(check-equal? (map liveness-diagnostic-address wrong-source-diagnostics)
              (list root-address))
(check-equal? (map liveness-diagnostic-classification
                   wrong-source-diagnostics)
              '(incompatible/redefined))
(check-true
 (eq? (liveness-diagnostic-target-occurrence
       (first wrong-source-diagnostics))
      bS-keep-occ))

;; Already-open sources and unaffected complete proofs are explicitly outside
;; this milestone rather than silently becoming empty/no-op plans.
(define open-source-error
  (plan-ground-repair retire-bS-revision R))
(check-repair-error open-source-error 'scope 'incomplete-source)
(define unaffected-source-error
  (plan-ground-repair retire-bS-revision retained-proof))
(check-repair-error unaffected-source-error
                    'scope
                    'no-inactive-occurrences)

;; A target need not currently contain any proof of the exposed requirement.
;; Planning is structural and leaves a valid open K1 context without searching
;; for, choosing, or enumerating prospective fillers.
(define no-filler-K0
  (make-equipped-calculus (list bS-occ bT-occ m-occ i-occ)))
(define no-filler-source
  (validate-candidate no-filler-K0 t-raw #:expected U))
(define no-filler-revision
  (make-calculus-revision no-filler-K0 '(bS) '()))
(define no-filler-K1
  (calculus-revision-target no-filler-revision))
(check-false
 (for/or ([occurrence (in-list (calculus-occurrences no-filler-K1))])
   (equal? (concrete-occurrence-conclusion occurrence) S)))
(define no-filler-plan
  (plan-ground-repair no-filler-revision no-filler-source))
(check-true (nonroot-ground-repair-plan? no-filler-plan))
(check-equal? (ground-repair-plan-addresses no-filler-plan) '((1 1)))
(check-equal? (plan-telescope-requirements no-filler-plan) (list S))
(check-true (proof-context?
             (ground-repair-plan-target-context no-filler-plan)))
(check-true
 (eq? (checked-term-calculus
       (ground-repair-plan-target-context no-filler-plan))
      no-filler-K1))
(check-equal? (checked-term->raw
               (ground-repair-plan-target-context no-filler-plan))
              (raw-app 'i
                       (raw-app 'm raw-hole (raw-app 'bT))))
(define no-filler-application
  (apply-repair-plan no-filler-plan '()))
(check-repair-error no-filler-application
                    'application
                    'wrong-filler-count)

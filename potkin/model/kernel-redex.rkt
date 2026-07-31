#lang racket

(require redex/reduction-semantics
         "../kernel/boundary.rkt"
         "../kernel/calculus.rkt"
         "../kernel/syntax.rkt")

(provide PotkinKernel
         candidate-checks
         candidate-synthesizes
         redex-root-boundaries
         redex-valid?
         redex-check?)

;; The grammar consumes the same s-expression candidates as raw-app and
;; validate-candidate. There is intentionally no second Redex-only AST.
(define-language PotkinKernel
  ;; Registry keys are arbitrary symbols, including names that are literals
  ;; elsewhere in the grammar. Admission is decided by occurrence-profile.
  (occurrence-key variable)
  (H any)
  (candidate (puncture)
             (app occurrence-key candidate ...)))

(define (registered-profile calculus occurrence-id)
  (and (equipped-calculus? calculus)
       (let ([occurrence (calculus-lookup calculus occurrence-id)])
         (and occurrence
              (list
               (vector->list (concrete-occurrence-premises occurrence))
               (concrete-occurrence-conclusion occurrence))))))

(define-metafunction PotkinKernel
  occurrence-profile : any occurrence-key -> any
  [(occurrence-profile any_calculus occurrence-key)
   ,(or (registered-profile (term any_calculus)
                            (term occurrence-key))
        'unknown)])

;; Pair requirements with children before recursing. This keeps the judgment
;; total on wrong arities and retains literal premise-slot order.
(define-metafunction PotkinKernel
  zip-profile : (H ...) (candidate ...) -> any
  [(zip-profile () ()) ()]
  [(zip-profile (H_0 H_rest ...) (candidate_0 candidate_rest ...))
   ((H_0 candidate_0) any_pair ...)
   (where (any_pair ...)
          (zip-profile (H_rest ...) (candidate_rest ...)))]
  [(zip-profile any_1 any_2) arity-mismatch])

(define-judgment-form PotkinKernel
  #:mode (candidate-checks I I I)
  #:contract (candidate-checks any H candidate)
  [(side-condition ,(equipped-calculus? (term any_calculus)))
   (side-condition ,(hypersequent? (term H)))
   -------------------------------------------
   (candidate-checks any_calculus H (puncture))]
  [(where ((H_input ...) H_output)
          (occurrence-profile any_calculus occurrence-key))
   (where ((H_child candidate_child) ...)
          (zip-profile (H_input ...) (candidate ...)))
   (side-condition ,(equal? (term H_expected) (term H_output)))
   (candidate-checks any_calculus H_child candidate_child) ...
   ----------------------------------------------------------------
   (candidate-checks any_calculus
                     H_expected
                     (app occurrence-key candidate ...))])

(define-judgment-form PotkinKernel
  #:mode (candidate-synthesizes I I O)
  #:contract (candidate-synthesizes any candidate H)
  [(where ((H_input ...) H_output)
          (occurrence-profile any_calculus occurrence-key))
   (where ((H_child candidate_child) ...)
          (zip-profile (H_input ...) (candidate ...)))
   (candidate-checks any_calculus H_child candidate_child) ...
   ----------------------------------------------------------------
   (candidate-synthesizes any_calculus
                          (app occurrence-key candidate ...)
                          H_output)])

(define (redex-root-boundaries calculus candidate)
  (if (redex-match? PotkinKernel candidate candidate)
      (judgment-holds
       (candidate-synthesizes ,calculus ,candidate H_result)
       H_result)
      '()))

(define (redex-valid? calculus candidate)
  (= 1 (length (redex-root-boundaries calculus candidate))))

(define (redex-check? calculus candidate boundary)
  (and (equipped-calculus? calculus)
       (hypersequent? boundary)
       (redex-match? PotkinKernel candidate candidate)
       (judgment-holds
        (candidate-checks ,calculus ,boundary ,candidate))))

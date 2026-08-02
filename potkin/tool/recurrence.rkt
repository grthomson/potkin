#lang racket/base

(require "../algebra/formal-sum.rkt"
         "../analysis/ancestry.rkt"
         "../analysis/cocycle.rkt"
         "../analysis/derivative-frame.rkt"
         "../analysis/recurrence.rkt"
         "../kernel/boundary.rkt"
         "../kernel/calculus.rkt"
         "../kernel/check.rkt")

(provide (struct-out calculus-recurrence-report)
         (struct-out return-context-report)
         (struct-out grafting-cocycle-report)
         (struct-out protected-defect-report)
         analyze-calculus-recurrence
         analyze-return-context
         analyze-grafting-cocycle
         analyze-protected-defect)

;; These reports retain their exact executable calculus and checked values.
;; `present.rkt` is the separate, deliberately provenance-forgetting layer.
(struct calculus-recurrence-report
  (calculus
   boundary
   graph
   recurrence
   status
   return-report
   component-bound
   limit)
  #:transparent)

(struct return-context-report
  (calculus
   boundary
   source
   character
   certificate
   status
   component-recurrence
   component-status
   component-bound
   limit)
  #:transparent)

(struct grafting-cocycle-report
  (calculus occurrence inputs certificate status limit)
  #:transparent)

(struct protected-defect-report
  (calculus context inputs protected-positions certificate status limit)
  #:transparent)

(define default-component-bound 8)

(define (check-component-bound who bound)
  (unless (exact-nonnegative-integer? bound)
    (raise-argument-error who "exact-nonnegative-integer?" bound)))

(define (return-certificate-status value)
  (cond
    [(analysis-limit? value) 'analysis-limit]
    [(analysis-error? value) 'analysis-error]
    [(not (first-return-certificate? value)) 'analysis-error]
    [(not (first-return-certificate-theorem-holds? value))
     'return-theorem-failed]
    [(= (first-return-certificate-first-return-indicator value) 1)
     'first-return]
    [else 'composite]))

(define (component-result-status value)
  (cond
    [(analysis-limit? value) 'analysis-limit]
    [(analysis-error? value) 'analysis-error]
    [(component-recurrence-analysis? value)
     (component-recurrence-analysis-status value)]
    [else 'analysis-error]))

(define (analyze-return-context
         source
         #:component-bound [component-bound default-component-bound]
         #:limit [limit analysis-default-limit])
  (unless (checked-node? source)
    (raise-argument-error 'analyze-return-context "checked-node?" source))
  (check-component-bound 'analyze-return-context component-bound)
  (define calculus (checked-term-calculus source))
  (define boundary (derivation-root-boundary source))
  (define character (make-boundary-return-character calculus boundary))
  (unless (boundary-return-context? character source)
    (raise-arguments-error
     'analyze-return-context
     "the source must be a positive one-hole endocontext"
     "source" source
     "root boundary" boundary))
  (define certificate
    (certify-first-return character source #:limit limit))
  (define status (return-certificate-status certificate))
  (define component-result
    (if (first-return-certificate? certificate)
        (component-recurrence-powers
         source component-bound #:limit limit)
        #f))
  (return-context-report
   calculus
   boundary
   source
   character
   certificate
   status
   component-result
   (if component-result
       (component-result-status component-result)
       'not-computed)
   component-bound
   limit))

(define (analyze-calculus-recurrence
         calculus boundary
         #:component-bound [component-bound default-component-bound]
         #:limit [limit analysis-default-limit])
  (unless (equipped-calculus? calculus)
    (raise-argument-error
     'analyze-calculus-recurrence "equipped-calculus?" calculus))
  (unless (hypersequent? boundary)
    (raise-argument-error
     'analyze-calculus-recurrence "hypersequent?" boundary))
  (check-component-bound 'analyze-calculus-recurrence component-bound)
  (define graph (derivative-frame-graph-of calculus))
  (define recurrence
    (boundary-recurrence-of graph boundary #:limit limit))
  (define status
    (cond
      [(analysis-limit? recurrence) 'analysis-limit]
      [(analysis-error? recurrence) 'analysis-error]
      [(boundary-recurrence? recurrence)
       (boundary-recurrence-status recurrence)]
      [else 'analysis-error]))
  (define realised-return
    (and (boundary-recurrence? recurrence)
         (boundary-recurrence-realisation recurrence)
         (frame-realisation-context
          (boundary-recurrence-realisation recurrence))))
  (define return-report
    (and realised-return
         (analyze-return-context
          realised-return
          #:component-bound component-bound
          #:limit limit)))
  (calculus-recurrence-report
   calculus boundary graph recurrence status return-report
   component-bound limit))

(define (infer-grafting-calculus who supplied inputs)
  (cond
    [supplied
     (unless (equipped-calculus? supplied)
       (raise-argument-error who "equipped-calculus? #:calculus" supplied))
     supplied]
    [(pair? inputs)
     (unless (checked-term? (car inputs))
       (raise-argument-error who "(listof checked-term?)" inputs))
     (checked-term-calculus (car inputs))]
    [else
     (raise-arguments-error
      who
      "a nullary occurrence has no input from which to recover provenance; supply #:calculus"
      "inputs" inputs)]))

(define (analyze-grafting-cocycle
         occurrence inputs
         #:calculus [supplied-calculus #f]
         #:limit [limit analysis-default-limit])
  (unless (concrete-occurrence? occurrence)
    (raise-argument-error
     'analyze-grafting-cocycle "concrete-occurrence?" occurrence))
  (unless (list? inputs)
    (raise-argument-error 'analyze-grafting-cocycle "list?" inputs))
  (define calculus
    (infer-grafting-calculus
     'analyze-grafting-cocycle supplied-calculus inputs))
  (define certificate
    (typed-grafting-cocycle
     calculus occurrence inputs #:limit limit))
  (define status
    (cond
      [(analysis-limit? certificate) 'analysis-limit]
      [(analysis-error? certificate) 'analysis-error]
      [(not (typed-grafting-cocycle-certificate? certificate))
       'analysis-error]
      [(and
        (typed-grafting-cocycle-certificate-equal? certificate)
        (typed-grafting-cocycle-certificate-witness-bijection? certificate))
       'zero-cocycle-defect]
      [(typed-grafting-cocycle-certificate-equal? certificate)
       'cocycle-witness-failure]
      [else 'nonzero-cocycle-defect]))
  (grafting-cocycle-report
   calculus
   (if (typed-grafting-cocycle-certificate? certificate)
       (typed-grafting-cocycle-certificate-occurrence certificate)
       occurrence)
   (for/list ([input (in-list inputs)]) input)
   certificate
   status
   limit))

(define (analyze-protected-defect
         context inputs protected-positions
         #:limit [limit analysis-default-limit])
  (unless (checked-node? context)
    (raise-argument-error
     'analyze-protected-defect "checked-node?" context))
  (define certificate
    (protected-context-factorization-defect
     context inputs protected-positions #:limit limit))
  (define status
    (cond
      [(analysis-limit? certificate) 'analysis-limit]
      [(analysis-error? certificate) 'analysis-error]
      [(not (protected-factorization-certificate? certificate))
       'analysis-error]
      [(not
        (and
         (protected-factorization-certificate-support-theorem? certificate)
         (protected-factorization-certificate-collected-coefficients-agree?
          certificate)
         (protected-factorization-certificate-cancellation-bijection?
          certificate)))
       'protected-defect-theorem-failed]
      [(formal-zero?
        (protected-factorization-certificate-defect certificate))
       'zero-protected-defect]
      [else 'nonzero-protected-defect]))
  (protected-defect-report
   (checked-term-calculus context)
   context
   (for/list ([input (in-list inputs)]) input)
   (if (protected-factorization-certificate? certificate)
       (protected-factorization-certificate-protected-positions certificate)
       (if (list? protected-positions)
           (sort protected-positions <)
           protected-positions))
   certificate
   status
   limit))

#lang racket/base

(require rackunit
         "../potkin/kernel.rkt"
         "../potkin/analysis.rkt"
         "../potkin/tool.rkt"
         "cocycle-fixtures.rkt"
         "derivative-frame-fixtures.rkt"
         "recurrence-fixtures.rkt")

(define first-report
  (analyze-return-context return-C #:component-bound 3))
(define composite-report
  (analyze-return-context return-C2 #:component-bound 3))
(define opaque-report
  (analyze-return-context opaque-recurrence-context #:component-bound 3))
(define limited-report
  (analyze-return-context return-C #:component-bound 3 #:limit 0))

(check-true (return-context-report? first-report))
(check-equal? (return-context-report-status first-report) 'first-return)
(check-equal? (return-context-report-status composite-report) 'composite)
(check-equal? (return-context-report-component-status opaque-report)
              'component-analysis-unavailable)
(check-equal? (return-context-report-status limited-report) 'analysis-limit)

(define acyclic-report
  (analyze-calculus-recurrence acyclic-calculus frame-H))
(define raw-report
  (analyze-calculus-recurrence blocked-cycle-calculus frame-G))
(define no-seed-report
  (analyze-calculus-recurrence self-no-seed-calculus frame-G))
(define seeded-report
  (analyze-calculus-recurrence self-with-seed-calculus frame-G))

(check-equal? (calculus-recurrence-report-status acyclic-report) 'acyclic)
(check-equal? (calculus-recurrence-report-status raw-report) 'raw-unrealised)
(check-equal? (calculus-recurrence-report-status no-seed-report)
              'realised-no-seed)
(check-equal? (calculus-recurrence-report-status seeded-report)
              'realised-with-seed)
(check-true
 (frame-context-decomposition?
  (boundary-recurrence-decomposition
   (calculus-recurrence-report-recurrence seeded-report))))

(define graft-report
  (analyze-grafting-cocycle
   cocycle-unary-occurrence (list cocycle-g)))
(define nullary-graft-report
  (analyze-grafting-cocycle
   cocycle-g-occurrence '() #:calculus cocycle-calculus))
(define zero-defect-report
  (analyze-protected-defect
   (corolla cocycle-calculus cocycle-binary-occurrence)
   (list cocycle-g cocycle-g)
   '(1 2)))
(define nonzero-defect-report
  (analyze-protected-defect
   cocycle-running-context (list cocycle-g) '(1)))

(check-equal? (grafting-cocycle-report-status graft-report)
              'zero-cocycle-defect)
(check-equal? (grafting-cocycle-report-status nullary-graft-report)
              'zero-cocycle-defect)
(check-equal? (protected-defect-report-status zero-defect-report)
              'zero-protected-defect)
(check-equal? (protected-defect-report-status nonzero-defect-report)
              'nonzero-protected-defect)

;; Presentation is deterministic and accepts both top-level reports and their
;; theorem-level decomposition/bijection certificates.
(for ([value
       (in-list
        (list first-report
              composite-report
              opaque-report
              limited-report
              acyclic-report
              raw-report
              no-seed-report
              seeded-report
              graft-report
              zero-defect-report
              nonzero-defect-report
              (return-context-report-certificate first-report)
              (calculus-recurrence-report-recurrence seeded-report)
              (grafting-cocycle-report-certificate graft-report)
              (protected-defect-report-certificate nonzero-defect-report)))])
  (define first-datum (analysis->datum value))
  (define second-datum (analysis->datum value))
  (check-equal? first-datum second-datum)
  (check-true (pair? first-datum)))

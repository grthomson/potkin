#lang racket/base

(require "../potkin/main.rkt"
         "../potkin/analysis/atomic-cycle-ck.rkt")

(define certificate (certify-atomic-four-cycle #:limit 64))

(cond
  [(analysis-limit? certificate)
   (displayln
    (list 'inconclusive
          (analysis-limit-operation certificate)
          (analysis-limit-required certificate)))]
  [else
   (define fixture (atomic-cycle-ck-certificate-fixture certificate))
   (define source-audit
     (atomic-cycle-ck-certificate-source-coaction certificate))
   (define comb (atomic-cycle-ck-certificate-comb certificate))
   (define balanced (atomic-cycle-ck-certificate-balanced certificate))
   (displayln
    (list
     'atomic-four-cycle
     (list 'validity
           (atomic-preorder-result-status
            (atomic-four-cycle-fixture-decision fixture)))
     (list 'removal-countermodels
           (andmap atomic-removal-certificate-verified?
                   (atomic-cycle-ck-certificate-removals certificate)))
     (list 'selected-coaction-counts
           (material-query-result-coefficient
            (atomic-coaction-audit-result source-audit))
           (material-query-result-coefficient
            (atomic-coaction-audit-result
             (atomic-target-ck-certificate-coaction comb)))
           (material-query-result-coefficient
            (atomic-coaction-audit-result
             (atomic-target-ck-certificate-coaction balanced))))
     (list 'new-proper-full-support
           (length
            (atomic-target-ck-certificate-new-full-support-witnesses comb))
           (length
            (atomic-target-ck-certificate-new-full-support-witnesses
             balanced)))
     (list 'verified
           (atomic-cycle-ck-certificate-verified? certificate))))])

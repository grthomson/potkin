#lang racket

(require rackunit
         redex/reduction-semantics
         "../potkin/kernel.rkt"
         "../potkin/model.rkt"
         "kernel-fixtures.rkt")

(check-true (redex-match? PotkinKernel candidate running-raw))

(define fixtures
  (list
   (list running-raw U)
   (list (raw-app 'm raw-hole raw-hole) ST)
   (list raw-hole S)
   (list (raw-app 'm (raw-app 'bS)) ST)
   (list (raw-app 'not-admitted) S)
   (list (raw-app 'counterfeit) S)
   (list (raw-app 'm (raw-app 'bT) (raw-app 'bS)) ST)
   (list '(app 17) S)
   (list '(not-a-candidate) S)
   (list (cons 'app (cons 'bS 'tail)) S)
   (list running-raw S)
   (list (raw-app 'i (raw-app 'm (raw-app 'bS))) U)
   (list (raw-app 'i
                  (raw-app 'm (raw-app 'bT) (raw-app 'bS)))
         U)
   (list (raw-app 'a (raw-app 'bS) (raw-app 'bS-prime)) V)
   (list (raw-app 'a (raw-app 'bS-prime) (raw-app 'bS)) V)))

(for ([fixture (in-list fixtures)])
  (define candidate (first fixture))
  (define expected (second fixture))
  (define ordinary-result
    (validate-candidate running-calculus candidate #:expected expected))
  (check-equal?
   (redex-check? running-calculus candidate expected)
   (validation-success? ordinary-result)
   (format "checker disagreement on ~s" candidate)))

(check-equal? (redex-root-boundaries running-calculus running-raw)
              (list U))
(check-equal? (redex-root-boundaries running-calculus
                                     (raw-app 'm raw-hole raw-hole))
              (list ST))
(check-equal? (redex-root-boundaries running-calculus raw-hole) '())
(check-false
 (judgment-holds
  (candidate-checks not-a-calculus ,S (puncture))))
(check-true (redex-valid? running-calculus running-raw))
(check-false (redex-valid? running-calculus raw-hole))
(check-false (redex-valid? running-calculus
                           (raw-app 'm (raw-app 'bS))))

;; Literal-looking symbols are still legal concrete occurrence identities.
(define app-occurrence
  (make-concrete-occurrence 'app '() S #:kind 'material))
(define puncture-occurrence
  (make-concrete-occurrence 'puncture '() T #:kind 'material))
(define reserved-key-calculus
  (make-equipped-calculus (list app-occurrence puncture-occurrence)))
(for ([candidate+boundary
       (in-list (list (list (raw-app 'app) S)
                      (list (raw-app 'puncture) T)))])
  (define candidate (first candidate+boundary))
  (define boundary (second candidate+boundary))
  (check-true
   (validation-success?
    (validate-candidate reserved-key-calculus
                        candidate
                        #:expected boundary)))
  (check-true (redex-check? reserved-key-calculus candidate boundary))
  (check-equal? (redex-root-boundaries reserved-key-calculus candidate)
                (list boundary)))

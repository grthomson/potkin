#lang racket/base

(require rackunit
         "../potkin/kernel.rkt"
         "kernel-fixtures.rkt")

(check-true (validation-success? running-proof))
(check-true (derivation-complete? running-proof))
(check-equal? (derivation-root-boundary running-proof) U)
(check-equal? (derivation-vertex-count running-proof) 4)
(check-equal? (checked-term->raw running-proof) running-raw)

;; Invariant-bearing structs are opaque: renamed constructors alone are not
;; enough, because a transparent struct's constructor is reflectively exposed.
(for ([protected-value
       (in-list (list running-proof S running-calculus bS-occ))])
  (define-values (reflected-type skipped?) (struct-info protected-value))
  (check-false reflected-type)
  (check-true skipped?))

(define wrong-arity
  (validate-candidate running-calculus
                      (raw-app 'm (raw-app 'bS))))
(check-true (validation-error? wrong-arity))
(check-equal? (validation-error-code wrong-arity) 'wrong-arity)
(check-equal? (validation-error-address wrong-arity) '())

(define unknown
  (validate-candidate running-calculus (raw-app 'not-admitted)))
(check-equal? (validation-error-code unknown) 'unknown-occurrence)

;; A counterfeit key is not admitted merely because one could give it the
;; same nullary S profile as bS.
(define counterfeit
  (make-concrete-occurrence 'counterfeit '() S #:kind 'material))
(check-false (calculus-admits? running-calculus counterfeit))
(define unknown-same-profile
  (validate-candidate running-calculus (raw-app 'counterfeit)))
(check-equal? (validation-error-code unknown-same-profile)
              'unknown-occurrence)

(define wrong-child
  (validate-candidate
   running-calculus
   (raw-app 'm (raw-app 'bT) (raw-app 'bS))))
(check-equal? (validation-error-code wrong-child) 'wrong-boundary)
(check-equal? (validation-error-address wrong-child) '(1))
(check-equal? (validation-error-expected wrong-child) S)
(check-equal? (validation-error-actual wrong-child) T)

(define malformed
  (validate-candidate running-calculus '(app 17)))
(check-equal? (validation-error-code malformed) 'malformed-candidate)
(define malformed-improper
  (validate-candidate running-calculus (cons 'app (cons 'bS 'tail))))
(check-equal? (validation-error-code malformed-improper)
              'malformed-candidate)

(check-exn
 exn:fail:contract?
 (lambda ()
   (make-concrete-occurrence
    'mutable-instance '() S #:instance (vector 'can-change))))
(check-exn
 exn:fail:contract?
 (lambda ()
   (make-concrete-occurrence
    (string->uninterned-symbol "ground") '() S #:kind 'material)))

(define open-m
  (validate-candidate running-calculus (raw-app 'm raw-hole raw-hole)))
(check-true (validation-success? open-m))
(check-false (derivation-complete? open-m))
(check-equal? (derivation-vertex-count open-m) 1)
(check-equal? (checked-term->raw open-m)
              (raw-app 'm raw-hole raw-hole))

;; Ordered premise slots remain visible in structural proof equality.
(define left-first
  (validate-candidate running-calculus
                      (raw-app 'a (raw-app 'bS) (raw-app 'bS-prime))))
(define right-first
  (validate-candidate running-calculus
                      (raw-app 'a (raw-app 'bS-prime) (raw-app 'bS))))
(check-true (validation-success? left-first))
(check-true (validation-success? right-first))
(check-not-equal? left-first right-first)

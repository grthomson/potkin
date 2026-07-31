#lang racket/base

(require "../potkin/kernel.rkt")

(provide S T ST U V
         bS-occ bS-prime-occ bT-occ m-occ i-occ a-occ
         running-calculus
         running-raw
         running-proof)

(define S (singleton-hypersequent '() '(S)))
(define T (singleton-hypersequent '() '(T)))
(define U (singleton-hypersequent '() '(U)))
(define V (singleton-hypersequent '() '(V)))
(define ST
  (hypersequent-union S T))

(define bS-occ
  (make-concrete-occurrence
   'bS '() S #:kind 'material #:tag 'ground #:instance 'S))
(define bS-prime-occ
  (make-concrete-occurrence
   'bS-prime '() S #:kind 'material #:tag 'ground #:instance 'S-prime))
(define bT-occ
  (make-concrete-occurrence
   'bT '() T #:kind 'material #:tag 'ground #:instance 'T))
(define m-occ
  (make-concrete-occurrence
   'm (list S T) ST #:kind 'structural #:tag 'assembly))
(define i-occ
  (make-concrete-occurrence
   'i (list ST) U #:kind 'logical #:tag 'i))
(define a-occ
  (make-concrete-occurrence
   'a (list S S) V #:kind 'logical #:tag 'a))

(define running-calculus
  (make-equipped-calculus
   (list bS-occ bS-prime-occ bT-occ m-occ i-occ a-occ)))

(define running-raw
  (raw-app 'i
           (raw-app 'm
                    (raw-app 'bS)
                    (raw-app 'bT))))

(define running-proof
  (validate-candidate running-calculus running-raw #:expected U))

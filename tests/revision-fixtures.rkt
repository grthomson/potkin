#lang racket/base

(require "../potkin/kernel.rkt")

(provide S T ST U V
         bS-occ bS-keep-occ bS-prime-occ bT-occ m-occ i-occ a-occ
         K0
         t-raw t
         bS-proof bS-keep-proof bT-proof
         retained-proof
         R
         retire-bS-revision K1
         persistent-revision K+
         identity-revision K0/copy)

(define S (singleton-hypersequent '() '(S)))
(define T (singleton-hypersequent '() '(T)))
(define U (singleton-hypersequent '() '(U)))
(define V (singleton-hypersequent '() '(V)))
(define ST (hypersequent-union S T))

;; K0 deliberately omits bS-prime.  The primed occurrence is genuinely fresh
;; evidence, even though its whole boundary agrees with bS and bS-keep.
(define bS-occ
  (make-concrete-occurrence
   'bS '() S #:kind 'material #:tag 'ground #:instance 'S))
(define bS-keep-occ
  (make-concrete-occurrence
   'bS-keep '() S #:kind 'material #:tag 'ground #:instance 'S-keep))
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

(define K0
  (make-equipped-calculus
   (list bS-occ bS-keep-occ bT-occ m-occ i-occ a-occ)))

(define t-raw
  (raw-app 'i
           (raw-app 'm
                    (raw-app 'bS)
                    (raw-app 'bT))))
(define t (validate-candidate K0 t-raw #:expected U))

(define bS-proof
  (validate-candidate K0 (raw-app 'bS) #:expected S))
(define bS-keep-proof
  (validate-candidate K0 (raw-app 'bS-keep) #:expected S))
(define bT-proof
  (validate-candidate K0 (raw-app 'bT) #:expected T))

;; A complete proof whose every vertex is retained by the bS revision.
(define retained-proof
  (validate-candidate
   K0
   (raw-app 'a (raw-app 'bS-keep) (raw-app 'bS-keep))
   #:expected V))

;; The retained one-hole context underlying t.
(define R
  (validate-candidate
   K0
   (raw-app 'i
            (raw-app 'm raw-hole (raw-app 'bT)))
   #:expected U))

(define retire-bS-revision
  (make-calculus-revision K0 '(bS) (list bS-prime-occ)))
(define K1 (calculus-revision-target retire-bS-revision))

;; This persistent extension is the fixture for base-extension/filling
;; naturality: no old occurrence is withdrawn.
(define persistent-revision
  (make-calculus-revision K0 '() (list bS-prime-occ)))
(define K+ (calculus-revision-target persistent-revision))

;; Even the identity revision receives a freshly constructed target registry,
;; so checked provenance can witness rebasing without changing presentation.
(define identity-revision
  (make-calculus-revision K0 '() '()))
(define K0/copy (calculus-revision-target identity-revision))

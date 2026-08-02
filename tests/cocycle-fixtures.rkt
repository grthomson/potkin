#lang racket/base

(require "../potkin/kernel.rkt")

(provide cocycle-S
         cocycle-T
         cocycle-ST
         cocycle-U
         cocycle-g-occurrence
         cocycle-t-occurrence
         cocycle-unary-occurrence
         cocycle-binary-occurrence
         cocycle-m-occurrence
         cocycle-i-occurrence
         cocycle-calculus
         cocycle-clone-calculus
         cocycle-g
         cocycle-t-ground
         cocycle-u-g
         cocycle-u-u-g
         cocycle-b-g-g
         cocycle-b-u-g-u-g
         cocycle-box-S
         cocycle-u-box
         cocycle-b-box-box
         cocycle-running-context
         cocycle-running-proof
         cocycle-local-context-0
         cocycle-local-context-1
         cocycle-local-context-2
         cocycle-clone-g)

(define cocycle-S (singleton-hypersequent '() '(S)))
(define cocycle-T (singleton-hypersequent '() '(T)))
(define cocycle-ST (hypersequent-union cocycle-S cocycle-T))
(define cocycle-U (singleton-hypersequent '() '(U)))

(define cocycle-g-occurrence
  (make-concrete-occurrence
   'cocycle-g
   '()
   cocycle-S
   #:kind 'material
   #:tag 'ground
   #:instance 'S))

(define cocycle-t-occurrence
  (make-concrete-occurrence
   'cocycle-t
   '()
   cocycle-T
   #:kind 'material
   #:tag 'ground
   #:instance 'T))

(define cocycle-unary-occurrence
  (make-concrete-occurrence
   'cocycle-u
   (list cocycle-S)
   cocycle-S
   #:kind 'logical
   #:tag 'unary
   #:incidence 'opaque-unary-incidence))

;; The equal premise boundaries remain two distinct ordered slots.  Incidence
;; is deliberately opaque: component analysis is unavailable on its open
;; corolla even though the constructor-level CK equation remains decidable.
(define cocycle-binary-occurrence
  (make-concrete-occurrence
   'cocycle-b
   (list cocycle-S cocycle-S)
   cocycle-S
   #:kind 'logical
   #:tag 'binary
   #:incidence 'opaque-binary-incidence))

(define cocycle-m-occurrence
  (make-concrete-occurrence
   'cocycle-m
   (list cocycle-S cocycle-T)
   cocycle-ST
   #:kind 'structural
   #:tag 'assembly
   #:incidence 'opaque-assembly-incidence))

(define cocycle-i-occurrence
  (make-concrete-occurrence
   'cocycle-i
   (list cocycle-ST)
   cocycle-U
   #:kind 'logical
   #:tag 'inclusion
   #:incidence 'opaque-inclusion-incidence))

(define cocycle-calculus
  (make-equipped-calculus
   (list cocycle-g-occurrence
         cocycle-t-occurrence
         cocycle-unary-occurrence
         cocycle-binary-occurrence
         cocycle-m-occurrence
         cocycle-i-occurrence)))

;; Structurally the same finite registry, but intentionally a different exact
;; snapshot for provenance rejection tests.
(define cocycle-clone-calculus
  (make-equipped-calculus (calculus-occurrences cocycle-calculus)))

(define (checked calculus raw expected)
  (define result (validate-candidate calculus raw #:expected expected))
  (when (validation-error? result)
    (error 'cocycle-fixtures
           "fixture failed validation: ~e; error: ~e"
           raw
           result))
  result)

(define cocycle-g
  (checked cocycle-calculus (raw-app 'cocycle-g) cocycle-S))
(define cocycle-t-ground
  (checked cocycle-calculus (raw-app 'cocycle-t) cocycle-T))
(define cocycle-u-g
  (checked
   cocycle-calculus
   (raw-app 'cocycle-u (raw-app 'cocycle-g))
   cocycle-S))
(define cocycle-u-u-g
  (checked
   cocycle-calculus
   (raw-app 'cocycle-u
            (raw-app 'cocycle-u (raw-app 'cocycle-g)))
   cocycle-S))
(define cocycle-b-g-g
  (checked
   cocycle-calculus
   (raw-app 'cocycle-b
            (raw-app 'cocycle-g)
            (raw-app 'cocycle-g))
   cocycle-S))
(define cocycle-b-u-g-u-g
  (checked
   cocycle-calculus
   (raw-app 'cocycle-b
            (raw-app 'cocycle-u (raw-app 'cocycle-g))
            (raw-app 'cocycle-u (raw-app 'cocycle-g)))
   cocycle-S))

(define cocycle-box-S
  (identity-context cocycle-calculus cocycle-S))
(define cocycle-u-box
  (checked
   cocycle-calculus
   (raw-app 'cocycle-u raw-hole)
   cocycle-S))
(define cocycle-b-box-box
  (checked
   cocycle-calculus
   (raw-app 'cocycle-b raw-hole raw-hole)
   cocycle-S))

;; s(x)=i(m(x,b_T)) and its complete evaluation at b_S.
(define cocycle-running-context
  (checked
   cocycle-calculus
   (raw-app 'cocycle-i
            (raw-app 'cocycle-m
                     raw-hole
                     (raw-app 'cocycle-t)))
   cocycle-U))
(define cocycle-running-proof
  (checked
   cocycle-calculus
   (raw-app 'cocycle-i
            (raw-app 'cocycle-m
                     (raw-app 'cocycle-g)
                     (raw-app 'cocycle-t)))
   cocycle-U))

;; Three compatible local replacements: identical root and the same single
;; addressed S-puncture at (1), but increasingly large fixed context data.
(define cocycle-local-context-0 cocycle-u-box)
(define cocycle-local-context-1
  (checked
   cocycle-calculus
   (raw-app 'cocycle-b raw-hole (raw-app 'cocycle-g))
   cocycle-S))
(define cocycle-local-context-2
  (checked
   cocycle-calculus
   (raw-app 'cocycle-b
            raw-hole
            (raw-app 'cocycle-u (raw-app 'cocycle-g)))
   cocycle-S))

(define cocycle-clone-g
  (checked
   cocycle-clone-calculus
   (raw-app 'cocycle-g)
   cocycle-S))

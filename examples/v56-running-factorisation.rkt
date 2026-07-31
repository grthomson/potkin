#lang racket/base

(require "../potkin/kernel.rkt")

(provide S T ST U
         bS-occurrence bT-occurrence m-occurrence i-occurrence
         example-calculus
         t
         example-admissible-cuts
         two-leaf-witness
         two-leaf-detached
         two-leaf-remainder
         two-leaf-telescope
         two-leaf-reconstructs?)

(define S (singleton-hypersequent '() '(S)))
(define T (singleton-hypersequent '() '(T)))
(define ST (hypersequent-union S T))
(define U (singleton-hypersequent '() '(U)))

(define bS-occurrence
  (make-concrete-occurrence 'bS '() S #:kind 'material #:tag 'ground))
(define bT-occurrence
  (make-concrete-occurrence 'bT '() T #:kind 'material #:tag 'ground))
(define m-occurrence
  (make-concrete-occurrence
   'm (list S T) ST #:kind 'structural #:tag 'assembly))
(define i-occurrence
  (make-concrete-occurrence 'i (list ST) U #:kind 'logical))

(define example-calculus
  (make-equipped-calculus
   (list bS-occurrence bT-occurrence m-occurrence i-occurrence)))

(define t
  (validate-candidate
   example-calculus
   (raw-app 'i
            (raw-app 'm (raw-app 'bS) (raw-app 'bT)))
   #:expected U))

(define example-admissible-cuts
  (for/list ([cut (in-admissible-cuts t)]) cut))

(define two-leaf-witness
  (make-cut-witness t '((1 1) (1 2))))
(define two-leaf-detached
  (for/list ([entry (in-list (cut-witness-detached two-leaf-witness))])
    (list (detached-entry-address entry)
          (checked-term->raw (detached-entry-term entry)))))
(define two-leaf-remainder
  (checked-term->raw (cut-witness-remainder two-leaf-witness)))
(define two-leaf-telescope
  (for/list ([entry (in-list
                     (premise-telescope
                      (cut-witness-remainder two-leaf-witness)))])
    (list (telescope-entry-address entry)
          (cond
            [(equal? (telescope-entry-requirement entry) S) 'S]
            [(equal? (telescope-entry-requirement entry) T) 'T]))))
(define two-leaf-reconstructs?
  (cut-witness-reconstructs? two-leaf-witness))

(module+ main
  (displayln (vertex-addresses t))
  (for ([cut (in-list example-admissible-cuts)])
    (displayln cut))
  (displayln (list 'detached two-leaf-detached))
  (displayln (list 'remainder two-leaf-remainder))
  (displayln (list 'telescope two-leaf-telescope))
  (displayln (list 'reconstructs? two-leaf-reconstructs?)))

#lang racket/base

(require "../potkin/main.rkt")

(provide P=>A
         Q=>B
         P=>B
         Q=>A
         left-boundary
         right-boundary
         communication-boundary
         assembly-boundary
         communication-incidence
         assembly-incidence
         left-ground-occurrence
         right-ground-occurrence
         communication-occurrence
         assembly-occurrence
         component-calculus
         left-proof
         right-proof
         communication-proof
         assembly-proof
         immediate-cut-addresses
         component-index-of)

(define P=>A (make-sequent '(P) '(A)))
(define Q=>B (make-sequent '(Q) '(B)))
(define P=>B (make-sequent '(P) '(B)))
(define Q=>A (make-sequent '(Q) '(A)))

(define left-boundary (make-hypersequent (list P=>A)))
(define right-boundary (make-hypersequent (list Q=>B)))
(define communication-boundary (make-hypersequent (list P=>B Q=>A)))
(define assembly-boundary
  (hypersequent-union left-boundary right-boundary))

(define (component-index-of boundary component)
  (or
   (for/first ([occurrence (in-list (hypersequent-components boundary))]
               #:when
               (equal? component
                       (component-occurrence-sequent occurrence)))
     (component-occurrence-index occurrence))
   (raise-arguments-error
    'component-index-of
    "the displayed component is not present in the boundary"
    "boundary" boundary
    "component" component)))

(define communication-target-1
  (component-index-of communication-boundary P=>B))
(define communication-target-2
  (component-index-of communication-boundary Q=>A))
(define assembly-left-target
  (component-index-of assembly-boundary P=>A))
(define assembly-right-target
  (component-index-of assembly-boundary Q=>B))

(define communication-incidence
  (make-component-incidence
   (list left-boundary right-boundary)
   communication-boundary
   (list
    (make-component-edge 1 1 communication-target-1)
    (make-component-edge 1 1 communication-target-2)
    (make-component-edge 2 1 communication-target-1)
    (make-component-edge 2 1 communication-target-2))))

(define assembly-incidence
  (make-component-incidence
   (list left-boundary right-boundary)
   assembly-boundary
   (list
    (make-component-edge 1 1 assembly-left-target)
    (make-component-edge 2 1 assembly-right-target))))

(define left-ground-occurrence
  (make-concrete-occurrence
   'component-left-ground
   '()
   left-boundary
   #:kind 'material
   #:tag 'ground
   #:instance '(P-to-A)
   #:incidence
   (make-component-incidence '() left-boundary '())))

(define right-ground-occurrence
  (make-concrete-occurrence
   'component-right-ground
   '()
   right-boundary
   #:kind 'material
   #:tag 'ground
   #:instance '(Q-to-B)
   #:incidence
   (make-component-incidence '() right-boundary '())))

(define communication-occurrence
  (make-concrete-occurrence
   'component-communication
   (list left-boundary right-boundary)
   communication-boundary
   #:kind 'structural
   #:tag 'communication
   #:instance '(crossed-components)
   #:incidence communication-incidence))

(define assembly-occurrence
  (make-concrete-occurrence
   'component-bar-assembly
   (list left-boundary right-boundary)
   assembly-boundary
   #:kind 'structural
   #:tag 'bar-assembly
   #:instance '(disjoint-hypersequent-union)
   #:incidence assembly-incidence))

(define component-calculus
  (make-equipped-calculus
   (list left-ground-occurrence
         right-ground-occurrence
         communication-occurrence
         assembly-occurrence)))

(define left-proof
  (validate-candidate
   component-calculus
   (raw-app 'component-left-ground)
   #:expected left-boundary))

(define right-proof
  (validate-candidate
   component-calculus
   (raw-app 'component-right-ground)
   #:expected right-boundary))

(define communication-proof
  (validate-candidate
   component-calculus
   (raw-app 'component-communication
            (checked-term->raw left-proof)
            (checked-term->raw right-proof))
   #:expected communication-boundary))

(define assembly-proof
  (validate-candidate
   component-calculus
   (raw-app 'component-bar-assembly
            (checked-term->raw left-proof)
            (checked-term->raw right-proof))
   #:expected assembly-boundary))

(define immediate-cut-addresses '((1) (2)))

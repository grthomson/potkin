#lang racket/base

(require racket/list
         racket/vector
         rackunit
         "../potkin/kernel.rkt"
         "../potkin/analysis/recurrence.rkt"
         "recurrence-fixtures.rkt")

;; ONE TINY BOUNDED FALSIFICATION ORACLE
;; -------------------------------------
;; This generator is deliberately independent of hopf-fixtures.rkt's global
;; degree-four layers.  It constructs only complete g/u/b terms and positive
;; one-hole g/u/b contexts through degree three.

(define oracle-maximum-degree 3)
(define complete-raw-layers
  (make-vector (add1 oracle-maximum-degree) '()))
(define context-raw-layers
  (make-vector (add1 oracle-maximum-degree) '()))
(vector-set! context-raw-layers 0 (list raw-hole))

(for ([degree (in-range 1 (add1 oracle-maximum-degree))])
  (define complete-ground
    (if (= degree 1) (list (raw-app 'g)) '()))
  (define complete-unary
    (for/list
        ([child (in-list (vector-ref complete-raw-layers (sub1 degree)))])
      (raw-app 'u child)))
  (define complete-binary
    (for*/list
        ([left-degree (in-range 1 (sub1 degree))]
         [left (in-list (vector-ref complete-raw-layers left-degree))]
         [right
          (in-list
           (vector-ref complete-raw-layers
                       (- (sub1 degree) left-degree)))])
      (raw-app 'b left right)))
  (vector-set!
   complete-raw-layers
   degree
   (remove-duplicates
    (append complete-ground complete-unary complete-binary)
    equal?))

  (define context-unary
    (for/list
        ([child (in-list (vector-ref context-raw-layers (sub1 degree)))])
      (raw-app 'u child)))
  (define context-on-left
    (for*/list
        ([context-degree (in-range 0 (sub1 degree))]
         [context (in-list (vector-ref context-raw-layers context-degree))]
         [complete
          (in-list
           (vector-ref complete-raw-layers
                       (- (sub1 degree) context-degree)))])
      (raw-app 'b context complete)))
  (define context-on-right
    (for*/list
        ([complete-degree (in-range 1 degree)]
         [complete (in-list (vector-ref complete-raw-layers complete-degree))]
         [context
          (in-list
           (vector-ref context-raw-layers
                       (- (sub1 degree) complete-degree)))])
      (raw-app 'b complete context)))
  (vector-set!
   context-raw-layers
   degree
   (remove-duplicates
    (append context-unary context-on-left context-on-right)
    equal?)))

(define oracle-raw-distribution
  (for/list ([degree (in-range 1 (add1 oracle-maximum-degree))])
    (vector-ref context-raw-layers degree)))
(define oracle-object-distribution (map length oracle-raw-distribution))
(define oracle-raw-contexts (append* oracle-raw-distribution))

(define oracle-contexts
  (for/list ([raw (in-list oracle-raw-contexts)])
    (define checked
      (validate-candidate return-calculus raw #:expected return-boundary))
    (when (validation-error? checked)
      (error
       'first-return-bounded-oracle
       "a generated positive one-hole raw context failed checking: ~e"
       checked))
    checked))

(define oracle-character
  (make-boundary-return-character return-calculus return-boundary))
(define oracle-certificates
  (for/list ([context (in-list oracle-contexts)])
    (certify-first-return oracle-character context #:limit #f)))
(define aggregate-theorem-holds?
  (andmap first-return-certificate-theorem-holds? oracle-certificates))

(printf
 "TINY BOUNDED FIRST-RETURN FALSIFICATION ORACLE: ~a generated objects; degree distribution ~a; aggregate theorem agreement ~a.~n"
 (length oracle-contexts)
 oracle-object-distribution
 aggregate-theorem-holds?)
(displayln
 "Finite agreement is falsification evidence only; it is not the universal proof.")

(check-equal? oracle-object-distribution '(1 3 7))
(check-equal? (length oracle-contexts) 11)
(check-equal? (length (remove-duplicates oracle-raw-contexts equal?)) 11)

(define expected-oracle-raws
  (list
   (raw-app 'u raw-hole)
   (raw-app 'u (raw-app 'u raw-hole))
   (raw-app 'b raw-hole (raw-app 'g))
   (raw-app 'b (raw-app 'g) raw-hole)
   (raw-app 'u (raw-app 'u (raw-app 'u raw-hole)))
   (raw-app 'u (raw-app 'b raw-hole (raw-app 'g)))
   (raw-app 'u (raw-app 'b (raw-app 'g) raw-hole))
   (raw-app 'b (raw-app 'u raw-hole) (raw-app 'g))
   (raw-app 'b (raw-app 'g) (raw-app 'u raw-hole))
   (raw-app 'b raw-hole (raw-app 'u (raw-app 'g)))
   (raw-app 'b (raw-app 'u (raw-app 'g)) raw-hole)))
(check-equal? (sort oracle-raw-contexts symbolic-datum<?)
              (sort expected-oracle-raws symbolic-datum<?))

(for ([degree (in-range 1 (add1 oracle-maximum-degree))]
      [layer (in-list oracle-raw-distribution)])
  (for ([raw (in-list layer)])
    (define context
      (validate-candidate return-calculus raw #:expected return-boundary))
    (check-true (checked-node? context))
    (check-eq? (checked-term-calculus context) return-calculus)
    (check-equal? (derivation-vertex-count context) degree)
    (check-equal? (length (puncture-addresses context)) 1)
    (check-true (boundary-return-context? oracle-character context))))

(check-equal?
 (for/list ([return-count '(0 1 2)])
   (count
    (lambda (certificate)
      (= (length
          (first-return-certificate-proper-return-addresses certificate))
         return-count))
    oracle-certificates))
 '(5 5 1))
(check-true aggregate-theorem-holds?)
(for ([certificate (in-list oracle-certificates)])
  (check-true (first-return-certificate? certificate))
  (check-true
   (first-return-certificate-polynomial-antipode-sign-law? certificate))
  (check-true (first-return-certificate-indicator-law? certificate))
  (check-true (first-return-certificate-theorem-holds? certificate)))

#lang racket/base

(require rackunit
         "../potkin/kernel.rkt")

(define gamma-1 (make-formula-context '(A B A)))
(define gamma-2 (make-formula-context '(B A A)))
(check-equal? gamma-1 gamma-2)
(check-equal? (formula-context-count gamma-1 'A) 2)
(check-equal? (formula-context-size gamma-1) 3)

(define repeated (make-sequent '(A) '(B)))
(define exchanged
  (make-hypersequent
   (list (make-sequent '(C) '(D)) repeated repeated)))
(define exchanged-again
  (make-hypersequent
   (list repeated (make-sequent '(C) '(D)) repeated)))
(check-equal? exchanged exchanged-again)
(check-equal? (hypersequent-size exchanged) 3)
(check-equal? (map component-occurrence-index
                   (hypersequent-components exchanged))
              '(1 2 3))
(check-equal? (hypersequent-count exchanged repeated) 2)

(define complex-1
  (make-sequent (list '(f A) '#(x 2) '#:left) '(Z)))
(define complex-2
  (make-sequent (list '(g B) '#(x 1) '#:right) '(Z)))
(define complex-order-1 (make-hypersequent (list complex-1 complex-2)))
(define complex-order-2 (make-hypersequent (list complex-2 complex-1)))
(check-equal?
 (map component-occurrence-sequent
      (hypersequent-components complex-order-1))
 (map component-occurrence-sequent
      (hypersequent-components complex-order-2)))

(check-exn exn:fail:contract?
           (lambda () (make-hypersequent '())))

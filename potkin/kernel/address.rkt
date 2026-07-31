#lang racket/base

(require racket/list
         "check.rkt")

(provide root-address
         address?
         address<?
         address-prefix?
         proper-address-prefix?
         address-append
         checked-term-at-address
         vertex-at-address
         vertex-addresses)

(define root-address '())

(define (address? value)
  (and (list? value) (andmap exact-positive-integer? value)))

(define (address<? left right)
  (unless (address? left)
    (raise-argument-error 'address<? "address?" left))
  (unless (address? right)
    (raise-argument-error 'address<? "address?" right))
  (cond
    [(null? left) (pair? right)]
    [(null? right) #f]
    [(< (car left) (car right)) #t]
    [(> (car left) (car right)) #f]
    [else (address<? (cdr left) (cdr right))]))

(define (address-prefix? prefix address)
  (unless (address? prefix)
    (raise-argument-error 'address-prefix? "address?" prefix))
  (unless (address? address)
    (raise-argument-error 'address-prefix? "address?" address))
  (and (<= (length prefix) (length address))
       (equal? prefix (take address (length prefix)))))

(define (proper-address-prefix? prefix address)
  (and (address-prefix? prefix address)
       (< (length prefix) (length address))))

(define (address-append prefix suffix)
  (unless (address? prefix)
    (raise-argument-error 'address-append "address?" prefix))
  (unless (address? suffix)
    (raise-argument-error 'address-append "address?" suffix))
  (append prefix suffix))

(define (checked-term-at-address term address)
  (unless (checked-term? term)
    (raise-argument-error
     'checked-term-at-address "checked-term?" term))
  (unless (address? address)
    (raise-argument-error 'checked-term-at-address "address?" address))
  (let loop ([current term] [remaining address])
    (cond
      [(null? remaining) current]
      [(checked-hole? current) #f]
      [else
       (define slot (car remaining))
       (define children (checked-node-children current))
       (if (<= slot (length children))
           (loop (list-ref children (sub1 slot)) (cdr remaining))
           #f)])))

(define (vertex-at-address term address)
  (define found (checked-term-at-address term address))
  (and (checked-node? found) found))

(define (vertex-addresses term)
  (unless (checked-term? term)
    (raise-argument-error 'vertex-addresses "checked-term?" term))
  (define (walk current prefix)
    (if (checked-hole? current)
        '()
        (cons
         prefix
         (append-map
          (lambda (slot+child)
            (define slot (car slot+child))
            (define child (cdr slot+child))
            (walk child (append prefix (list slot))))
          (for/list ([child (in-list (checked-node-children current))]
                     [slot (in-naturals 1)])
            (cons slot child))))))
  (walk term root-address))

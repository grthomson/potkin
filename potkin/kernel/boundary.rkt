#lang racket/base

(require racket/list)

(provide formula-datum?
         symbolic-datum<?
         formula-context?
         make-formula-context
         empty-formula-context
         formula-context-count
         formula-context-size
         formula-context->list
         sequent?
         make-sequent
         sequent-left
         sequent-right
         hypersequent?
         make-hypersequent
         singleton-hypersequent
         hypersequent-count
         hypersequent-size
         hypersequent-sequents
         hypersequent-components
         hypersequent-union
         component-occurrence?
         component-occurrence-index
         component-occurrence-sequent)

;; Formulae are syntax data, not mutable host-language objects. Keeping keys
;; immutable makes multiset equality stable after construction.
(define (formula-datum? value)
  (cond
    [(or (and (symbol? value) (symbol-interned? value))
         (keyword? value)
         (and (number? value) (exact? value))
         (boolean? value)
         (char? value)
         (null? value))
     #t]
    [(string? value) (immutable? value)]
    [(bytes? value) (immutable? value)]
    [(pair? value)
     (and (formula-datum? (car value))
          (formula-datum? (cdr value)))]
    [(vector? value)
     (and (immutable? value)
          (for/and ([item (in-vector value)])
            (formula-datum? item)))]
    [else #f]))

(struct formula-context (counts)
  #:constructor-name make-formula-context/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (formula-context? right)
          (recur (formula-context-counts left)
                 (formula-context-counts right))))
   (lambda (value recur) (recur (formula-context-counts value)))
   (lambda (value recur) (recur (formula-context-counts value)))))

(define empty-formula-context
  (make-formula-context/internal (hash)))

(define (make-formula-context formulae)
  (unless (list? formulae)
    (raise-argument-error 'make-formula-context "list?" formulae))
  (make-formula-context/internal
   (for/fold ([counts (hash)]) ([formula (in-list formulae)])
     (unless (formula-datum? formula)
       (raise-arguments-error
        'make-formula-context
        "formulae must be immutable symbolic data"
        "formula" formula))
     (hash-update counts formula add1 0))))

(define (formula-context-count context formula)
  (unless (formula-context? context)
    (raise-argument-error 'formula-context-count "formula-context?" context))
  (hash-ref (formula-context-counts context) formula 0))

(define (formula-context-size context)
  (unless (formula-context? context)
    (raise-argument-error 'formula-context-size "formula-context?" context))
  (for/sum ([count (in-hash-values (formula-context-counts context))])
    count))

(define (datum-rank value)
  (cond
    [(null? value) 0]
    [(boolean? value) 1]
    [(char? value) 2]
    [(number? value) 3]
    [(symbol? value) 4]
    [(keyword? value) 5]
    [(string? value) 6]
    [(bytes? value) 7]
    [(pair? value) 8]
    [(vector? value) 9]))

(define (sequence-lex<? left right item<? item=?)
  (cond
    [(null? left) (pair? right)]
    [(null? right) #f]
    [(item=? (car left) (car right))
     (sequence-lex<? (cdr left) (cdr right) item<? item=?)]
    [else (item<? (car left) (car right))]))

(define (bytes-lex<? left right)
  (sequence-lex<? (bytes->list left) (bytes->list right) < =))

;; Exact formula numbers are ordered by their mathematical real and imaginary
;; coordinates.  In particular, presentation strings never participate in
;; the semantic order used to canonicalise a boundary.
(define (exact-number<? left right)
  (cond
    [(and (real? left) (not (real? right))) #t]
    [(and (not (real? left)) (real? right)) #f]
    [(< (real-part left) (real-part right)) #t]
    [(> (real-part left) (real-part right)) #f]
    [else (< (imag-part left) (imag-part right))]))

;; formula-datum? restricts this comparator to a finite family of immutable
;; symbolic forms, so this is a genuine total structural order rather than a
;; presentation-string heuristic.  It is public so deterministic research
;; reports can use exactly the order that canonical boundaries use.
(define (symbolic-datum<? left right)
  (unless (formula-datum? left)
    (raise-argument-error 'symbolic-datum<? "formula-datum?" left))
  (unless (formula-datum? right)
    (raise-argument-error 'symbolic-datum<? "formula-datum?" right))
  (define left-rank (datum-rank left))
  (define right-rank (datum-rank right))
  (cond
    [(equal? left right) #f]
    [(< left-rank right-rank) #t]
    [(> left-rank right-rank) #f]
    [(null? left) #f]
    [(boolean? left) (and (not left) right)]
    [(char? left) (char<? left right)]
    [(number? left) (exact-number<? left right)]
    [(symbol? left) (string<? (symbol->string left) (symbol->string right))]
    [(keyword? left)
     (string<? (keyword->string left) (keyword->string right))]
    [(string? left) (string<? left right)]
    [(bytes? left) (bytes-lex<? left right)]
    [(pair? left)
     (cond
       [(equal? (car left) (car right))
        (symbolic-datum<? (cdr left) (cdr right))]
       [else (symbolic-datum<? (car left) (car right))])]
    [(vector? left)
     (sequence-lex<? (vector->list left)
                     (vector->list right)
                     symbolic-datum<?
                     equal?)]))

(define (formula-context->list context)
  (unless (formula-context? context)
    (raise-argument-error 'formula-context->list "formula-context?" context))
  (append-map
   (lambda (formula)
     (make-list (hash-ref (formula-context-counts context) formula) formula))
   (sort (hash-keys (formula-context-counts context)) symbolic-datum<?)))

(struct sequent (left right)
  #:constructor-name make-sequent/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (sequent? right)
          (recur (sequent-left left) (sequent-left right))
          (recur (sequent-right left) (sequent-right right))))
   (lambda (value recur)
     (recur (list (sequent-left value) (sequent-right value))))
   (lambda (value recur)
     (recur (list (sequent-right value) (sequent-left value))))))

(define (coerce-formula-context who value)
  (cond
    [(formula-context? value) value]
    [(list? value) (make-formula-context value)]
    [else (raise-argument-error who "(or/c formula-context? list?)" value)]))

(define (make-sequent left right)
  (make-sequent/internal (coerce-formula-context 'make-sequent left)
                         (coerce-formula-context 'make-sequent right)))

(struct hypersequent (counts)
  #:constructor-name make-hypersequent/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (hypersequent? right)
          (recur (hypersequent-counts left)
                 (hypersequent-counts right))))
   (lambda (value recur) (recur (hypersequent-counts value)))
   (lambda (value recur) (recur (hypersequent-counts value)))))

(struct component-occurrence (index sequent)
  #:constructor-name make-component-occurrence/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (component-occurrence? right)
          (recur (component-occurrence-index left)
                 (component-occurrence-index right))
          (recur (component-occurrence-sequent left)
                 (component-occurrence-sequent right))))
   (lambda (value recur)
     (recur (list (component-occurrence-index value)
                  (component-occurrence-sequent value))))
   (lambda (value recur)
     (recur (list (component-occurrence-sequent value)
                  (component-occurrence-index value))))))

(define (make-hypersequent sequents)
  (unless (and (list? sequents) (pair? sequents))
    (raise-argument-error 'make-hypersequent "nonempty-list?" sequents))
  (make-hypersequent/internal
   (for/fold ([counts (hash)]) ([component (in-list sequents)])
     (unless (sequent? component)
       (raise-argument-error 'make-hypersequent "(listof sequent?)" sequents))
     (hash-update counts component add1 0))))

(define (singleton-hypersequent left [right '()])
  (make-hypersequent (list (make-sequent left right))))

(define (hypersequent-count boundary component)
  (unless (hypersequent? boundary)
    (raise-argument-error 'hypersequent-count "hypersequent?" boundary))
  (unless (sequent? component)
    (raise-argument-error 'hypersequent-count "sequent?" component))
  (hash-ref (hypersequent-counts boundary) component 0))

(define (hypersequent-size boundary)
  (unless (hypersequent? boundary)
    (raise-argument-error 'hypersequent-size "hypersequent?" boundary))
  (for/sum ([count (in-hash-values (hypersequent-counts boundary))])
    count))

(define (formula-context<? left right)
  (sequence-lex<? (formula-context->list left)
                  (formula-context->list right)
                  symbolic-datum<?
                  equal?))

(define (sequent<? left right)
  (cond
    [(equal? (sequent-left left) (sequent-left right))
     (formula-context<? (sequent-right left) (sequent-right right))]
    [else (formula-context<? (sequent-left left) (sequent-left right))]))

(define (hypersequent-sequents boundary)
  (unless (hypersequent? boundary)
    (raise-argument-error 'hypersequent-sequents "hypersequent?" boundary))
  (append-map
   (lambda (component)
     (make-list (hash-ref (hypersequent-counts boundary) component) component))
   (sort (hash-keys (hypersequent-counts boundary)) sequent<?)))

(define (hypersequent-components boundary)
  (for/list ([component (in-list (hypersequent-sequents boundary))]
             [index (in-naturals 1)])
    (make-component-occurrence/internal index component)))

(define (hypersequent-union first-boundary . remaining-boundaries)
  (define boundaries (cons first-boundary remaining-boundaries))
  (for ([boundary (in-list boundaries)])
    (unless (hypersequent? boundary)
      (raise-argument-error 'hypersequent-union "hypersequent?" boundary)))
  (make-hypersequent
   (append-map hypersequent-sequents boundaries)))

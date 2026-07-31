#lang racket/base

(require racket/list
         "boundary.rkt")

(provide concrete-occurrence?
         make-concrete-occurrence
         concrete-occurrence-id
         concrete-occurrence-kind
         concrete-occurrence-tag
         concrete-occurrence-instance
         concrete-occurrence-premises
         concrete-occurrence-conclusion
         concrete-occurrence-incidence
         occurrence-arity
         occurrence-premise
         equipped-calculus?
         make-equipped-calculus
         calculus-lookup
         calculus-admits?
         calculus-occurrences
         calculus-size)

(struct concrete-occurrence
  (id kind tag instance premises conclusion incidence)
  #:constructor-name make-concrete-occurrence/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (concrete-occurrence? right)
          (recur (concrete-occurrence-id left)
                 (concrete-occurrence-id right))
          (recur (concrete-occurrence-kind left)
                 (concrete-occurrence-kind right))
          (recur (concrete-occurrence-tag left)
                 (concrete-occurrence-tag right))
          (recur (concrete-occurrence-instance left)
                 (concrete-occurrence-instance right))
          (recur (concrete-occurrence-premises left)
                 (concrete-occurrence-premises right))
          (recur (concrete-occurrence-conclusion left)
                 (concrete-occurrence-conclusion right))
          (recur (concrete-occurrence-incidence left)
                 (concrete-occurrence-incidence right))))
   (lambda (value recur)
     (recur (list (concrete-occurrence-id value)
                  (concrete-occurrence-kind value)
                  (concrete-occurrence-tag value)
                  (concrete-occurrence-instance value)
                  (concrete-occurrence-premises value)
                  (concrete-occurrence-conclusion value)
                  (concrete-occurrence-incidence value))))
   (lambda (value recur)
     (recur (list (concrete-occurrence-incidence value)
                  (concrete-occurrence-conclusion value)
                  (concrete-occurrence-premises value)
                  (concrete-occurrence-instance value)
                  (concrete-occurrence-tag value)
                  (concrete-occurrence-kind value)
                  (concrete-occurrence-id value))))))

(define admitted-kinds '(material logical structural))

(define (immutable-registry-datum? value)
  (cond
    [(or (symbol? value)
         (keyword? value)
         (number? value)
         (boolean? value)
         (char? value)
         (null? value))
     #t]
    [(string? value) (immutable? value)]
    [(bytes? value) (immutable? value)]
    [(pair? value)
     (and (immutable-registry-datum? (car value))
          (immutable-registry-datum? (cdr value)))]
    [(vector? value)
     (and (immutable? value)
          (for/and ([item (in-vector value)])
            (immutable-registry-datum? item)))]
    [(box? value)
     (and (immutable? value)
          (immutable-registry-datum? (unbox value)))]
    [(hash? value)
     (and (immutable? value)
          (for/and ([(key item) (in-hash value)])
            (and (immutable-registry-datum? key)
                 (immutable-registry-datum? item))))]
    [else #f]))

(define (make-concrete-occurrence id premises conclusion
                                  #:kind [kind 'logical]
                                  #:tag [tag id]
                                  #:instance [instance #f]
                                  #:incidence [incidence '()])
  (unless (symbol? id)
    (raise-argument-error 'make-concrete-occurrence "symbol?" id))
  (unless (memq kind admitted-kinds)
    (raise-arguments-error
     'make-concrete-occurrence
     "kind must be material, logical, or structural"
     "kind" kind))
  (unless (symbol? tag)
    (raise-argument-error 'make-concrete-occurrence "symbol?" tag))
  (unless (and (list? premises) (andmap hypersequent? premises))
    (raise-argument-error
     'make-concrete-occurrence
     "(listof hypersequent?)"
     premises))
  (unless (hypersequent? conclusion)
    (raise-argument-error
     'make-concrete-occurrence "hypersequent?" conclusion))
  (unless (immutable-registry-datum? instance)
    (raise-arguments-error
     'make-concrete-occurrence
     "instance data must be deeply immutable symbolic data"
     "instance" instance))
  (unless (immutable-registry-datum? incidence)
    (raise-arguments-error
     'make-concrete-occurrence
     "incidence data must be deeply immutable symbolic data"
     "incidence" incidence))
  (make-concrete-occurrence/internal
   id
   kind
   tag
   instance
   (vector->immutable-vector (list->vector premises))
   conclusion
   incidence))

(define (occurrence-arity occurrence)
  (unless (concrete-occurrence? occurrence)
    (raise-argument-error 'occurrence-arity "concrete-occurrence?" occurrence))
  (vector-length (concrete-occurrence-premises occurrence)))

(define (occurrence-premise occurrence slot)
  (unless (concrete-occurrence? occurrence)
    (raise-argument-error 'occurrence-premise "concrete-occurrence?" occurrence))
  (unless (and (exact-positive-integer? slot)
               (<= slot (occurrence-arity occurrence)))
    (raise-arguments-error
     'occurrence-premise
     "slot must name an existing 1-based premise"
     "slot" slot
     "arity" (occurrence-arity occurrence)))
  (vector-ref (concrete-occurrence-premises occurrence) (sub1 slot)))

(struct equipped-calculus (registry)
  #:constructor-name make-equipped-calculus/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (equipped-calculus? right)
          (recur (equipped-calculus-registry left)
                 (equipped-calculus-registry right))))
   (lambda (value recur) (recur (equipped-calculus-registry value)))
   (lambda (value recur) (recur (equipped-calculus-registry value)))))

(define (make-equipped-calculus occurrences)
  (unless (and (list? occurrences) (andmap concrete-occurrence? occurrences))
    (raise-argument-error
     'make-equipped-calculus
     "(listof concrete-occurrence?)"
     occurrences))
  (make-equipped-calculus/internal
   (for/fold ([registry (hash)]) ([occurrence (in-list occurrences)])
     (define id (concrete-occurrence-id occurrence))
     (when (hash-has-key? registry id)
       (raise-arguments-error
        'make-equipped-calculus
        "concrete occurrence keys must be unique"
        "duplicate key" id))
     (hash-set registry id occurrence))))

(define (calculus-lookup calculus id)
  (unless (equipped-calculus? calculus)
    (raise-argument-error 'calculus-lookup "equipped-calculus?" calculus))
  (hash-ref (equipped-calculus-registry calculus) id #f))

(define (calculus-admits? calculus occurrence-or-id)
  (unless (equipped-calculus? calculus)
    (raise-argument-error 'calculus-admits? "equipped-calculus?" calculus))
  (cond
    [(symbol? occurrence-or-id)
     (hash-has-key? (equipped-calculus-registry calculus) occurrence-or-id)]
    [(concrete-occurrence? occurrence-or-id)
     (eq? occurrence-or-id
          (calculus-lookup calculus
                           (concrete-occurrence-id occurrence-or-id)))]
    [else #f]))

(define (calculus-occurrences calculus)
  (unless (equipped-calculus? calculus)
    (raise-argument-error 'calculus-occurrences "equipped-calculus?" calculus))
  (sort (hash-values (equipped-calculus-registry calculus))
        string<?
        #:key (lambda (occurrence)
                (symbol->string (concrete-occurrence-id occurrence)))))

(define (calculus-size calculus)
  (unless (equipped-calculus? calculus)
    (raise-argument-error 'calculus-size "equipped-calculus?" calculus))
  (hash-count (equipped-calculus-registry calculus)))

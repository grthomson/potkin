#lang racket/base

(require racket/list
         racket/pretty
         "../algebra/formal-sum.rkt"
         "../analysis/ancestry.rkt"
         "../dsl/term.rkt"
         "../hopf/antipode.rkt"
         "../hopf/ck.rkt"
         "../kernel/address.rkt"
         "../kernel/boundary.rkt"
         "../kernel/calculus.rkt"
         "../kernel/check.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt"
         "analysis.rkt")

(provide checked-term->datum
         proof-forest->datum
         formal-sum->datum
         analysis->datum
         write-analysis)

(define (immutable-string value)
  (if (immutable? value) value (string->immutable-string value)))

(define (immutable-bytes value)
  (if (immutable? value) value (bytes->immutable-bytes value)))

;; Registry instances are allowed to be richer than formula data.  This key
;; records the host datum's structural variant before its payload, including
;; boxes and hash equality modes.  The resulting key itself lies in the
;; symbolic-datum order; neither printing nor hash traversal orders it.
(define (number-order-key value)
  (cond
    [(and (exact? value) (real? value))
     (list 'exact-real (numerator value) (denominator value))]
    [(exact? value)
     (list 'exact-complex
           (number-order-key (real-part value))
           (number-order-key (imag-part value)))]
    [(and (real? value) (single-flonum? value))
     (list 'inexact-real-single
           (immutable-bytes
            (real->floating-point-bytes value 4 #t)))]
    [(real? value)
     (list (if (double-flonum? value)
               'inexact-real-double
               'inexact-real-other)
           (immutable-bytes
            (real->floating-point-bytes value 8 #t)))]
    [else
     (list 'inexact-complex
           (number-order-key (real-part value))
           (number-order-key (imag-part value)))]))

(define (hash-mode value)
  (cond
    [(hash-eq? value) 'eq]
    [(hash-eqv? value) 'eqv]
    [(hash-equal-always? value) 'equal-always]
    [else 'equal]))

(define (registry-order-key value)
  (cond
    [(null? value) '(0)]
    [(boolean? value) (list 1 (if value 1 0))]
    [(char? value) (list 2 (char->integer value))]
    [(number? value) (list 3 (number-order-key value))]
    [(symbol? value)
     (list 4 (immutable-string (symbol->string value)))]
    [(keyword? value)
     (list 5 (immutable-string (keyword->string value)))]
    [(string? value) (list 6 value)]
    [(bytes? value) (list 7 value)]
    [(pair? value)
     (list 8
           (registry-order-key (car value))
           (registry-order-key (cdr value)))]
    [(vector? value)
     (list 9
           (for/list ([item (in-vector value)])
             (registry-order-key item)))]
    [(box? value) (list 10 (registry-order-key (unbox value)))]
    [(hash? value)
     (define entry-keys
       (for/list ([(key item) (in-hash value)])
         (list (registry-order-key key) (registry-order-key item))))
     (list 11
           (hash-mode value)
           (sort entry-keys symbolic-datum<?))]
    [else
     ;; All concrete-occurrence registry data is validated before a report is
     ;; built, so reaching this branch is an internal contract violation.
     (raise-arguments-error
      'analysis->datum
      "unsupported registry datum"
      "value" value)]))

(define (registry-datum<? left right)
  (symbolic-datum<? (registry-order-key left)
                    (registry-order-key right)))

(define (canonical-registry-datum value)
  (cond
    [(pair? value)
     (cons (canonical-registry-datum (car value))
           (canonical-registry-datum (cdr value)))]
    [(vector? value)
     (list* 'vector
            (for/list ([item (in-vector value)])
              (canonical-registry-datum item)))]
    [(box? value)
     (list 'immutable-box (canonical-registry-datum (unbox value)))]
    [(hash? value)
     (define entries
       (sort
        (for/list ([(key item) (in-hash value)]) (cons key item))
        (lambda (left right)
          (symbolic-datum<?
           (list (registry-order-key (car left))
                 (registry-order-key (cdr left)))
           (list (registry-order-key (car right))
                 (registry-order-key (cdr right)))))))
     (list* 'immutable-hash
            (list 'mode (hash-mode value))
            (for/list ([entry (in-list entries)])
              (list 'entry
                    (canonical-registry-datum (car entry))
                    (canonical-registry-datum (cdr entry)))))]
    [else value]))

(define (formula-context->datum context)
  (list* 'formula-context (formula-context->list context)))

(define (sequent->datum value)
  (list 'sequent
        (list* 'left
               (formula-context->list (sequent-left value)))
        (list* 'right
               (formula-context->list (sequent-right value)))))

(define (hypersequent->datum value)
  (list*
   'hypersequent
   (for/list ([component (in-list (hypersequent-components value))])
     (list 'component
           (component-occurrence-index component)
           (sequent->datum
            (component-occurrence-sequent component))))))

(define (checked-term->datum/internal term embedded?)
  (cond
    [(checked-hole? term)
     (list (if embedded? 'hole 'Box)
           (hypersequent->datum (checked-hole-boundary term)))]
    [else
     (list*
      'node
      (concrete-occurrence-id (checked-node-occurrence term))
      (for/list ([child (in-list (checked-node-children term))])
        (checked-term->datum/internal child #t)))]))

(define (checked-term->datum term)
  (unless (checked-term? term)
    (raise-argument-error 'checked-term->datum "checked-term?" term))
  (checked-term->datum/internal term #f))

(define (checked-term<? left right)
  (symbolic-datum<? (checked-term->datum left)
                    (checked-term->datum right)))

(define (group-equal sorted-values)
  (let loop ([remaining sorted-values] [groups '()])
    (cond
      [(null? remaining) (reverse groups)]
      [else
       (define first-value (car remaining))
       (define-values (same rest)
         (splitf-at remaining (lambda (value) (equal? value first-value))))
       (loop rest (cons (cons first-value (length same)) groups))])))

(define (canonical-forest-factors forest)
  (sort (proof-forest-factors forest) checked-term<?))

(define (proof-forest->datum forest)
  (unless (proof-forest? forest)
    (raise-argument-error 'proof-forest->datum "proof-forest?" forest))
  (cond
    [(proof-forest-empty? forest) '(forest-unit)]
    [else
     (list*
      'commutative-forest
      (for/list
          ([group
            (in-list
             (group-equal (canonical-forest-factors forest)))])
        (list 'factor
              (checked-term->datum (car group))
              'multiplicity
              (cdr group))))]))

(define (sequence<? left right item<?)
  (cond
    [(null? left) (pair? right)]
    [(null? right) #f]
    [(equal? (car left) (car right))
     (sequence<? (cdr left) (cdr right) item<?)]
    [else (item<? (car left) (car right))]))

(define (forest<? left right)
  (sequence<?
   (map checked-term->datum (canonical-forest-factors left))
   (map checked-term->datum (canonical-forest-factors right))
   symbolic-datum<?))

(define (tensor-key<? left right)
  (sequence<? (vector->list left) (vector->list right) forest<?))

(define (canonical-formal-terms sum)
  (sort (formal-sum-terms sum)
        (lambda (left right)
          (tensor-key<? (car left) (car right)))))

(define (formal-sum->datum sum)
  (unless (formal-sum? sum)
    (raise-argument-error 'formal-sum->datum "formal-sum?" sum))
  (cond
    [(formal-zero? sum)
     (list 'formal-zero (list 'rank (formal-sum-rank sum)))]
    [else
     (list*
      'formal-sum
      (list 'rank (formal-sum-rank sum))
      (for/list ([entry (in-list (canonical-formal-terms sum))])
        (list 'summand
              (list 'coefficient (cdr entry))
              (list*
               'tensor
               (for/list ([forest (in-vector (car entry))])
                 (proof-forest->datum forest))))))]))

(define (address-set<? left right)
  (sequence<? (sort left address<?) (sort right address<?) address<?))

(define (address-word<? left right)
  (sequence<? left right address<?))

(define (telescope-entry->datum entry)
  (list 'puncture
        (telescope-entry-address entry)
        (hypersequent->datum (telescope-entry-requirement entry))))

(define (detached-entry->datum entry)
  (list 'detached
        (detached-entry-address entry)
        (checked-term->datum (detached-entry-term entry))))

(define (premise-slot-analysis->datum slot)
  (list 'premise-slot
        (premise-slot-analysis-slot slot)
        (list 'requires
              (hypersequent->datum
               (premise-slot-analysis-requirement slot)))
        (list 'child-address
              (premise-slot-analysis-child-address slot))
        (list 'child-kind (premise-slot-analysis-child-kind slot))))

(define (vertex-analysis->datum vertex)
  (list 'vertex
        (vertex-analysis-address vertex)
        (list 'id (vertex-analysis-id vertex))
        (list 'tag (vertex-analysis-tag vertex))
        (list 'kind (vertex-analysis-kind vertex))
        (list 'instance
              (canonical-registry-datum
               (vertex-analysis-instance vertex)))
        (list*
         'premise-slots
         (map premise-slot-analysis->datum
              (vertex-analysis-premise-slots vertex)))))

(define (cut-analysis->datum cut)
  (list 'cut-witness
        (list 'addresses (cut-analysis-addresses cut))
        (list*
         'aligned-detached
         (map detached-entry->datum
              (sort (cut-analysis-detached cut)
                    address<?
                    #:key detached-entry-address)))
        (list 'detached-forest
              (proof-forest->datum (cut-analysis-forest cut)))
        (list 'retained-context
              (checked-term->datum (cut-analysis-remainder cut)))
        (list 'reconstructs? (cut-analysis-reconstructs? cut))))

(define (analysis-limit->datum value)
  (list 'not-computed
        (list 'message "not computed: limit")
        (list 'operation (analysis-limit-operation value))
        (list 'limit (analysis-limit-limit value))
        (list 'required (analysis-limit-required value))
        (list 'metric (analysis-limit-metric value))
        (list 'details
              (structured-hash->datum
               (analysis-limit-details value)))))

(define (analysis-error->datum value)
  (list 'analysis-error
        (list 'code (analysis-error-code value))
        (list 'operation (analysis-error-operation value))
        (list 'message (analysis-error-message value))
        (list 'expected
              (value->datum (analysis-error-expected value)))
        (list 'actual (value->datum (analysis-error-actual value)))
        (list 'details
              (structured-hash->datum
               (analysis-error-details value)))))

(define (analysis-unavailable->datum value)
  (list 'not-applicable
        (list 'reason (analysis-unavailable-reason value))
        (list 'details
              (structured-hash->datum
               (analysis-unavailable-details value)))))

(define (law-check->datum value)
  (if (eq? (law-check-status value) 'pass)
      (list 'law (law-check-name value) 'pass)
      (list 'law
            (law-check-name value)
            (law-check-status value)
            (list 'expected (value->datum (law-check-expected value)))
            (list 'actual (value->datum (law-check-actual value))))))

(define (hopf-law-analysis->datum value)
  (list 'finite-input-hopf-laws
        (law-check->datum
         (hopf-law-analysis-coassociativity value))
        (law-check->datum (hopf-law-analysis-counit-left value))
        (law-check->datum (hopf-law-analysis-counit-right value))
        (law-check->datum (hopf-law-analysis-antipode-left value))
        (law-check->datum (hopf-law-analysis-antipode-right value))
        (law-check->datum
         (hopf-law-analysis-coaction-coassociativity value))
        (law-check->datum (hopf-law-analysis-coaction-counit value))
        (law-check->datum (hopf-law-analysis-zeta-order-map value))
        (law-check->datum
         (hopf-law-analysis-omega-linear-extension value))))

(define (context-interface->datum value)
  (list 'context-interface
        (list*
         'input-word
         (map hypersequent->datum (context-input-word value)))
        (list 'output
              (hypersequent->datum
               (context-output-boundary value)))))

(define (occurrence->datum occurrence)
  (list 'occurrence
        (list 'id (concrete-occurrence-id occurrence))
        (list 'tag (concrete-occurrence-tag occurrence))
        (list 'kind (concrete-occurrence-kind occurrence))
        (list 'instance
              (canonical-registry-datum
               (concrete-occurrence-instance occurrence)))))

(define (final-corolla->datum value)
  (list 'final-corolla-factorization
        (list 'source
              (checked-term->datum
               (final-corolla-factorization-source value)))
        (occurrence->datum
         (final-corolla-factorization-occurrence value))
        (list*
         'aligned-children
         (for/list
             ([child
               (in-vector
                (final-corolla-factorization-aligned-children value))]
              [slot (in-naturals 1)])
           (list 'slot slot (checked-term->datum child))))
        (list 'premise-forest
              (proof-forest->datum
               (final-corolla-factorization-premise-forest value)))
        (list 'corolla
              (checked-term->datum
               (final-corolla-factorization-corolla value)))))

(define (cut-polynomial->datum value)
  (cond
    [(not (vector? value)) (value->datum value)]
    [else
     (define terms
       (for/list ([coefficient (in-vector value)]
                  [power (in-naturals)]
                  #:when (positive? coefficient))
         (cond
           [(zero? power) coefficient]
           [(= power 1)
            (if (= coefficient 1) 'q (list '* coefficient 'q))]
           [else
            (define power-term (list 'expt 'q power))
            (if (= coefficient 1)
                power-term
                (list '* coefficient power-term))])))
     (list 'cut-polynomial
           (list 'expression
                 (cond
                   [(null? terms) 0]
                   [(null? (cdr terms)) (car terms)]
                   [else (list* '+ terms)]))
           (list* 'coefficients (vector->list value)))]))

(define (canonical-ideals value)
  (if (list? value)
      (sort (map (lambda (ideal) (sort ideal address<?)) value)
            address-set<?)
      value))

(define (canonical-orders value)
  (if (list? value)
      (sort value address-word<?)
      value))

(define (count-or-result value)
  (if (list? value) (length value) value))

(define (derivation-analysis->datum value)
  (define cuts (derivation-analysis-cut-witnesses value))
  (define coproduct-value (derivation-analysis-coproduct value))
  (define ideals
    (canonical-ideals (derivation-analysis-ancestry-ideals value)))
  (define orders
    (canonical-orders (derivation-analysis-refinement-orders value)))
  (list
   'potkin-derivation-analysis
   (list 'source (checked-term->datum (derivation-analysis-source value)))
   (list 'root (hypersequent->datum (derivation-analysis-root value)))
   (list 'complete? (derivation-analysis-complete? value))
   (context-interface->datum (derivation-analysis-interface value))
   (list 'vertex-count (derivation-analysis-vertex-count value))
   (list*
    'vertex-table
    (map vertex-analysis->datum
         (sort (derivation-analysis-vertex-table value)
               address<? #:key vertex-analysis-address)))
   (list*
    'puncture-telescope
    (map telescope-entry->datum
         (derivation-analysis-puncture-telescope value)))
   (list 'cut-witness-count (value->datum (count-or-result cuts)))
   (list*
    'cut-witnesses
    (if (list? cuts)
        (map cut-analysis->datum
             (sort cuts address-set<? #:key cut-analysis-addresses))
        (list (value->datum cuts))))
   (list 'singleton-basis
         (formal-sum->datum (derivation-analysis-singleton value)))
   (list 'coproduct-support-size
         (if (formal-sum? coproduct-value)
             (formal-sum-support-size coproduct-value)
             (value->datum coproduct-value)))
   (list 'collected-coproduct (value->datum coproduct-value))
   (list 'reduced-coproduct
         (value->datum (derivation-analysis-reduced-coproduct value)))
   (list 'root-coaction
         (value->datum (derivation-analysis-root-coaction value)))
   (list 'degree (derivation-analysis-degree value))
   (list 'counit (derivation-analysis-counit value))
   (list 'antipode (value->datum (derivation-analysis-antipode value)))
   (list 'final-corolla
         (value->datum
          (derivation-analysis-final-corolla-factorization value)))
   (list 'final-corolla-tensor
         (value->datum
          (derivation-analysis-final-corolla-projection value)))
   (cut-polynomial->datum
    (derivation-analysis-cut-size-polynomial value))
   (list 'ancestry-orientation 'descendant<=ancestor)
   (list 'ancestry-vertices
         (value->datum (derivation-analysis-ancestry-vertices value)))
   (list 'ancestry-cover-edges
         (value->datum (derivation-analysis-ancestry-cover-edges value)))
   (list 'ancestry-ideal-count (value->datum (count-or-result ideals)))
   (list 'ancestry-ideals (value->datum ideals))
   (list 'nonroot-ancestry-width
         (value->datum (derivation-analysis-ancestry-width value)))
   (list 'weak-order-map-count-2
         (value->datum
          (derivation-analysis-weak-order-map-count value)))
   (list 'zeta-convolution-power-2
         (value->datum
          (derivation-analysis-zeta-convolution-power value)))
   (list 'linear-extension-count
         (value->datum
          (derivation-analysis-linear-extension-count value)))
   (list 'omega-one-convolution-power-degree
         (value->datum
          (derivation-analysis-omega-one-convolution-power value)))
   (list 'refinement-history-count
         (value->datum
          (derivation-analysis-refinement-order-count value)))
   (list 'root-first-refinement-histories (value->datum orders))
   (hopf-law-analysis->datum (derivation-analysis-hopf-laws value))
   (list 'analysis-limit (derivation-analysis-limit value))))

(define (context-analysis->datum value)
  (list 'potkin-context-analysis
        (list 'source (checked-term->datum (context-analysis-source value)))
        (list 'root (hypersequent->datum (context-analysis-root value)))
        (context-interface->datum (context-analysis-interface value))
        (list 'vertex-count (context-analysis-vertex-count value))
        (list*
         'puncture-telescope
         (map telescope-entry->datum
              (context-analysis-puncture-telescope value)))
        (list 'connected-analysis
              (value->datum (context-analysis-connected value)))))

(define (forest-analysis->datum value)
  (list 'potkin-forest-analysis
        (list 'source (proof-forest->datum (forest-analysis-source value)))
        (list 'factor-count (forest-analysis-size value))
        (list 'degree (forest-analysis-degree value))
        (list 'basis (formal-sum->datum (forest-analysis-basis value)))
        (list 'coproduct (value->datum (forest-analysis-coproduct value)))
        (list 'reduced-coproduct
              (value->datum (forest-analysis-reduced-coproduct value)))
        (list 'counit (forest-analysis-counit value))
        (list 'antipode (value->datum (forest-analysis-antipode value)))
        (hopf-law-analysis->datum (forest-analysis-hopf-laws value))
        (list 'analysis-limit (forest-analysis-limit value))))

(define (algebra-error->datum value)
  (list 'algebra-error
        (list 'code (algebra-error-code value))
        (list 'operation (algebra-error-operation value))
        (list 'message (algebra-error-message value))))

(define (hopf-error->datum value)
  (list 'hopf-error
        (list 'code (hopf-error-code value))
        (list 'operation (hopf-error-operation value))
        (list 'message (hopf-error-message value))))

(define (antipode-error->datum value)
  (list 'antipode-error
        (list 'code (antipode-error-code value))
        (list 'operation (antipode-error-operation value))
        (list 'message (antipode-error-message value))))

(define (validation-error->datum value)
  (list 'validation-error
        (list 'code (validation-error-code value))
        (list 'address (validation-error-address value))
        (list 'message (validation-error-message value))
        (list 'expected (value->datum (validation-error-expected value)))
        (list 'actual (value->datum (validation-error-actual value)))
        (list 'details
              (structured-hash->datum
               (validation-error-details value)))))

(define (context-error->datum value)
  (list 'context-error
        (list 'code (context-error-code value))
        (list 'address (context-error-address value))
        (list 'message (context-error-message value))
        (list 'expected (value->datum (context-error-expected value)))
        (list 'actual (value->datum (context-error-actual value)))
        (list 'details
              (structured-hash->datum (context-error-details value)))))

(define (dsl-error->datum value)
  (list 'dsl-error
        (list 'code (dsl-error-code value))
        (list 'operation (dsl-error-operation value))
        (list 'address (dsl-error-address value))
        (list 'message (dsl-error-message value))
        (list 'expected (value->datum (dsl-error-expected value)))
        (list 'actual (value->datum (dsl-error-actual value)))
        (list 'details
              (structured-hash->datum (dsl-error-details value)))))

(define (cut-error->datum value)
  (list 'cut-error
        (list 'code (cut-error-code value))
        (list 'address (cut-error-address value))
        (list 'message (cut-error-message value))
        (list 'details
              (structured-hash->datum (cut-error-details value)))))

(define (cut-witness->datum value)
  (list 'cut-witness
        (list 'addresses (cut-witness-addresses value))
        (list*
         'aligned-detached
         (map detached-entry->datum
              (sort (cut-witness-detached value)
                    address<? #:key detached-entry-address)))
        (list 'detached-forest
              (proof-forest->datum (cut-witness-forest value)))
        (list 'retained-context
              (checked-term->datum (cut-witness-remainder value)))
        (list 'reconstructs? (cut-witness-reconstructs? value))))

(define (equipped-calculus->datum value)
  (list*
   'equipped-calculus-snapshot
   (for/list
       ([occurrence
         (in-list
          (sort (calculus-occurrences value)
                symbolic-datum<?
                #:key concrete-occurrence-id))])
     (occurrence->datum occurrence))))

;; Structured diagnostics may contain checked terms and other kernel values,
;; so they cannot be sent through the narrower registry-metadata converter.
;; Convert each complete key/value pair first, then sort that pair by its
;; typed structural key.
(define (structured-hash->datum value)
  (unless (hash? value)
    (raise-argument-error 'structured-hash->datum "hash?" value))
  (define entries
    (for/list ([(key item) (in-hash value)])
      (list 'entry (value->datum key) (value->datum item))))
  (list* 'immutable-hash
         (list 'mode (hash-mode value))
         (sort entries
               (lambda (left right)
                 (symbolic-datum<?
                  (registry-order-key left)
                  (registry-order-key right))))))

(define (value->datum value)
  (cond
    [(derivation-analysis? value) (derivation-analysis->datum value)]
    [(context-analysis? value) (context-analysis->datum value)]
    [(forest-analysis? value) (forest-analysis->datum value)]
    [(hopf-law-analysis? value) (hopf-law-analysis->datum value)]
    [(law-check? value) (law-check->datum value)]
    [(analysis-unavailable? value) (analysis-unavailable->datum value)]
    [(analysis-limit? value) (analysis-limit->datum value)]
    [(analysis-error? value) (analysis-error->datum value)]
    [(formal-sum? value) (formal-sum->datum value)]
    [(proof-forest? value) (proof-forest->datum value)]
    [(checked-term? value) (checked-term->datum value)]
    [(hypersequent? value) (hypersequent->datum value)]
    [(sequent? value) (sequent->datum value)]
    [(formula-context? value) (formula-context->datum value)]
    [(context-interface? value) (context-interface->datum value)]
    [(final-corolla-factorization? value) (final-corolla->datum value)]
    [(validation-error? value) (validation-error->datum value)]
    [(context-error? value) (context-error->datum value)]
    [(dsl-error? value) (dsl-error->datum value)]
    [(cut-error? value) (cut-error->datum value)]
    [(cut-witness? value) (cut-witness->datum value)]
    [(detached-entry? value) (detached-entry->datum value)]
    [(telescope-entry? value) (telescope-entry->datum value)]
    [(concrete-occurrence? value) (occurrence->datum value)]
    [(equipped-calculus? value) (equipped-calculus->datum value)]
    [(empty-cut-choice? value) '(empty-cut-choice)]
    [(whole-cut-choice? value) '(whole-cut-choice)]
    [(proper-cut-choice? value)
     (list 'proper-cut-choice (proper-cut-choice-addresses value))]
    [(algebra-error? value) (algebra-error->datum value)]
    [(hopf-error? value) (hopf-error->datum value)]
    [(antipode-error? value) (antipode-error->datum value)]
    [(vector? value)
     (list* 'vector (for/list ([item (in-vector value)])
                      (value->datum item)))]
    [(list? value) (map value->datum value)]
    [(pair? value)
     (cons (value->datum (car value)) (value->datum (cdr value)))]
    [(box? value) (list 'immutable-box (value->datum (unbox value)))]
    [(hash? value) (structured-hash->datum value)]
    [else value]))

(define (analysis->datum value)
  (unless (or (derivation-analysis? value)
              (context-analysis? value)
              (forest-analysis? value)
              (hopf-law-analysis? value)
              (law-check? value)
              (analysis-unavailable? value)
              (analysis-limit? value)
              (analysis-error? value))
    (raise-argument-error
     'analysis->datum
     "Potkin analysis report or structured analysis result"
     value))
  (value->datum value))

(define (write-analysis value [output (current-output-port)])
  (unless (output-port? output)
    (raise-argument-error 'write-analysis "output-port?" output))
  (pretty-write (analysis->datum value) output)
  (void))

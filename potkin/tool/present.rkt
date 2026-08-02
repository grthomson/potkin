#lang racket/base

(require racket/list
         racket/pretty
         "../algebra/formal-sum.rkt"
         "../analysis/ancestry.rkt"
         "../analysis/cocycle.rkt"
         "../analysis/component-trace.rkt"
         "../analysis/derivative-frame.rkt"
         "../analysis/recurrence.rkt"
         "../dsl/term.rkt"
         "../hopf/antipode.rkt"
         "../hopf/ck.rkt"
         "../kernel/address.rkt"
         "../kernel/boundary.rkt"
         "../kernel/calculus.rkt"
         "../kernel/check.rkt"
         "../kernel/component-incidence.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt"
         "analysis.rkt"
         "recurrence.rkt")

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

(define (component-occurrence->datum value)
  (list 'component
        (component-occurrence-index value)
        (sequent->datum (component-occurrence-sequent value))))

(define (addressed-component->datum value)
  (list 'addressed-component
        (list 'address (addressed-component-address value))
        (component-occurrence->datum
         (addressed-component-component value))))

(define (component-incidence->datum value)
  (list
   'component-incidence
   (list*
    'ordered-premises
    (map hypersequent->datum (component-incidence-premises value)))
   (list 'conclusion
         (hypersequent->datum (component-incidence-conclusion value)))
   (list*
    'edges
    (for/list ([edge (in-list (component-incidence-edges value))])
      (list 'edge
            (list 'premise-slot
                  (component-edge-premise-slot edge))
            (list 'source-component
                  (component-edge-source-index edge))
            (list 'target-component
                  (component-edge-target-index edge)))))))

(define (component-analysis-unavailable->datum value)
  (list 'component-analysis-unavailable
        (list 'reason (component-analysis-unavailable-reason value))
        (list 'details
              (structured-hash->datum
               (component-analysis-unavailable-details value)))))

(define (component-trace-blocker->datum value)
  (list 'opaque-vertex
        (list 'address (component-trace-blocker-address value))
        (list 'occurrence-id
              (component-trace-blocker-occurrence-id value))))

(define (component-trace-input->datum value)
  (list 'input
        (list 'puncture-address (component-trace-input-address value))
        (list 'requirement
              (hypersequent->datum
               (component-trace-input-boundary value)))))

(define (component-trace-edge->datum value)
  (list 'edge
        (addressed-component->datum
         (component-trace-edge-source value))
        (list 'target
              (component-occurrence->datum
               (component-trace-edge-target value)))))

(define (component-trace->datum value)
  (list
   'component-trace
   (list 'status 'known)
   (list*
    'inputs
    (map component-trace-input->datum (component-trace-inputs value)))
   (list*
    'source-universe
    (map addressed-component->datum (component-trace-sources value)))
   (list 'output (hypersequent->datum (component-trace-output value)))
   (list*
    'target-universe
    (map component-occurrence->datum (component-trace-targets value)))
   (list*
    'edges
    (map component-trace-edge->datum
         (sort (component-trace-edges value)
               (lambda (left right)
                 (define left-source
                   (component-trace-edge-source left))
                 (define right-source
                   (component-trace-edge-source right))
                 (define left-address
                   (addressed-component-address left-source))
                 (define right-address
                   (addressed-component-address right-source))
                 (cond
                   [(not (equal? left-address right-address))
                    (address<? left-address right-address)]
                   [(not
                     (= (component-occurrence-index
                         (addressed-component-component left-source))
                        (component-occurrence-index
                         (addressed-component-component right-source))))
                    (< (component-occurrence-index
                        (addressed-component-component left-source))
                       (component-occurrence-index
                        (addressed-component-component right-source)))]
                   [else
                    (< (component-occurrence-index
                        (component-trace-edge-target left))
                       (component-occurrence-index
                        (component-trace-edge-target right)))])))))))

(define (component-trace-unavailable->datum value)
  (list
   'component-trace
   (list 'status 'unknown)
   (list*
    'inputs
    (map component-trace-input->datum
         (component-trace-unavailable-inputs value)))
   (list*
    'source-universe
    (map addressed-component->datum
         (component-trace-unavailable-sources value)))
   (list 'output
         (hypersequent->datum
          (component-trace-unavailable-output value)))
   (list*
    'target-universe
    (map component-occurrence->datum
         (component-trace-unavailable-targets value)))
   (list*
    'blockers
    (map component-trace-blocker->datum
         (sort (component-trace-unavailable-blockers value)
               address<?
               #:key component-trace-blocker-address)))
   (list*
    'known-edges
    (map component-trace-edge->datum
         (component-trace-unavailable-known-edges value)))))

(define (component-relation-classification->datum value)
  (list 'classification
        (list 'functional?
              (component-relation-classification-functional? value))
        (list 'inverse-functional?
              (component-relation-classification-inverse-functional? value))
        (list 'total?
              (component-relation-classification-total? value))
        (list 'surjective?
              (component-relation-classification-surjective? value))
        (list 'splitting?
              (component-relation-classification-splitting? value))
        (list 'merger?
              (component-relation-classification-merger? value))
        (list 'erasure?
              (component-relation-classification-erasure? value))
        (list 'unsupported-creation?
              (component-relation-classification-unsupported-creation?
               value))))

(define (local-component-analysis->datum value)
  (list
   'vertex-component-relation
   (list 'address (local-component-analysis-address value))
   (list 'occurrence-id
         (concrete-occurrence-id
          (local-component-analysis-occurrence value)))
   (list 'relation (value->datum (local-component-analysis-relation value)))
   (list 'classification
         (value->datum (local-component-analysis-classification value)))
   (list 'proof-factor-defect
         (local-component-analysis-proof-factor-defect value))
   (list 'hypersequent-defect
         (local-component-analysis-hypersequent-defect value))))

(define (component-scalar-analysis->datum value)
  (list
   'scalar-structural-calibration
   (list 'proof-factor
         (list 'total (component-scalar-analysis-proof-factor-total value))
         (list 'euler-expected
               (component-scalar-analysis-proof-factor-expected value))
         (list 'euler-holds?
               (component-scalar-analysis-proof-factor-euler-holds? value)))
   (list 'hypersequent
         (list 'total (component-scalar-analysis-hypersequent-total value))
         (list 'euler-expected
               (component-scalar-analysis-hypersequent-expected value))
         (list 'euler-holds?
               (component-scalar-analysis-hypersequent-euler-holds? value)))))

(define (ck-component-profile->datum value)
  (list
   'ck-component-profile
   (list 'cut-addresses (ck-component-profile-addresses value))
   (list*
    'aligned-detached
    (map detached-entry->datum (ck-component-profile-detached value)))
   (list*
    'puncture-telescope
    (map telescope-entry->datum
         (ck-component-profile-puncture-telescope value)))
   (list 'retained-remainder
         (checked-term->datum (ck-component-profile-remainder value)))
   (list*
    'source-frontier
    (map addressed-component->datum
         (ck-component-profile-source-components value)))
   (list*
    'output-frontier
    (map component-occurrence->datum
         (ck-component-profile-output-components value)))
   (list 'trace (value->datum (ck-component-profile-trace value)))
   (list 'reconstruction
         (checked-term->datum (ck-component-profile-reconstruction value)))
   (list 'reconstructs? (ck-component-profile-reconstructs? value))))

(define (component-analysis->datum value)
  (define profiles (component-analysis-ck-profiles value))
  (list
   'component-analysis
   (list*
    'local-relations
    (map local-component-analysis->datum
         (sort (component-analysis-local-relations value)
               address<?
               #:key local-component-analysis-address)))
   (component-scalar-analysis->datum
    (component-analysis-scalar-analysis value))
   (list 'net-context-trace
         (value->datum (component-analysis-net-trace value)))
   (list 'ck-profile-count
         (if (list? profiles) (length profiles) (value->datum profiles)))
   (list*
    'ck-profiles
    (if (list? profiles)
        (map ck-component-profile->datum
             (sort profiles address-set<?
                   #:key ck-component-profile-addresses))
        (list (value->datum profiles))))))

(define (attached-component-analysis->datum value)
  (if (component-analysis? value)
      (component-analysis->datum value)
      (list 'component-analysis (value->datum value))))

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
   (attached-component-analysis->datum
    (derivation-analysis-component-analysis value))
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
              (value->datum (context-analysis-connected value)))
        (attached-component-analysis->datum
         (context-analysis-component-analysis value))))

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

(define (frame-off-spine->datum value)
  (list 'off-spine-premise
        (list 'slot (frame-off-spine-slot value))
        (list 'boundary
              (hypersequent->datum
               (frame-off-spine-boundary value)))))

(define (derivative-frame-edge-order-key value)
  (list
   (hypersequent->datum (derivative-frame-edge-source value))
   (hypersequent->datum (derivative-frame-edge-target value))
   (concrete-occurrence-id (derivative-frame-edge-occurrence value))
   (derivative-frame-edge-slot value)))

(define (derivative-frame-edge<? left right)
  (symbolic-datum<?
   (derivative-frame-edge-order-key left)
   (derivative-frame-edge-order-key right)))

(define (derivative-frame-edge->datum value)
  (list
   'derivative-frame-edge
   (list 'occurrence-id
         (concrete-occurrence-id
          (derivative-frame-edge-occurrence value)))
   (list 'slot (derivative-frame-edge-slot value))
   (list 'source
         (hypersequent->datum (derivative-frame-edge-source value)))
   (list 'target
         (hypersequent->datum (derivative-frame-edge-target value)))
   (list*
    'ordered-off-spine
    (map frame-off-spine->datum
         (sort (derivative-frame-edge-off-spine value)
               < #:key frame-off-spine-slot)))
   (list 'selected-address
         (derivative-frame-edge-selected-address value))
   (list 'open-corolla
         (checked-term->datum (derivative-frame-edge-corolla value)))
   (list 'component-incidence
         (value->datum (derivative-frame-edge-incidence value)))))

(define (derivative-frame-graph->datum value)
  (list
   'derivative-frame-graph
   (list 'calculus
         (equipped-calculus->datum
          (derivative-frame-graph-calculus value)))
   (list*
    'vertices
    (sort
     (map hypersequent->datum
          (derivative-frame-graph-vertices value))
     symbolic-datum<?))
   (list*
    'edges
    (map derivative-frame-edge->datum
         (sort (derivative-frame-graph-edges value)
               derivative-frame-edge<?)))))

(define (productivity-witness->datum value)
  (list
   'productivity-witness
   (list 'boundary
         (hypersequent->datum (productivity-witness-boundary value)))
   (list 'height (productivity-witness-height value))
   (list 'occurrence-id
         (concrete-occurrence-id
          (productivity-witness-occurrence value)))
   (list 'proof
         (checked-term->datum (productivity-witness-proof value)))
   (list*
    'ordered-premise-witnesses
    (for/list
        ([premise
          (in-list (productivity-witness-premise-witnesses value))]
         [slot (in-naturals 1)])
      (list 'slot slot
            (hypersequent->datum
             (productivity-witness-boundary premise)))))))

(define (frame-productivity->datum value)
  (list
   'frame-productivity
   (list 'work (frame-productivity-work value))
   (list*
    'witnesses
    (map productivity-witness->datum
         (sort
          (frame-productivity-witnesses value)
          symbolic-datum<?
          #:key
          (lambda (witness)
            (hypersequent->datum
             (productivity-witness-boundary witness))))))))

(define (frame-cycle->datum value)
  (list
   'frame-cycle
   (list 'boundary (hypersequent->datum (frame-cycle-boundary value)))
   ;; This is a path, not a commutative collection.  Preserve its order.
   (list*
    'ordered-cycle-path
    (for/list ([edge (in-list (frame-cycle-edges value))]
               [step (in-naturals 1)])
      (list 'step step (derivative-frame-edge->datum edge))))
   (list 'distinguished-address
         (frame-cycle-distinguished-address value))
   (list 'off-spine-addresses
         (sort (frame-cycle-off-spine-addresses value) address<?))
   (list 'raw-context
         (checked-term->datum (frame-cycle-raw-context value)))
   (list 'simple? (frame-cycle-simple? value))))

(define (frame-filler->datum entry)
  (list 'filler
        (list 'address (car entry))
        (list 'proof (checked-term->datum (cdr entry)))))

(define (frame-realisation->datum value)
  (list
   'frame-realisation
   (list 'status (frame-realisation-status value))
   (list 'cycle (frame-cycle->datum (frame-realisation-cycle value)))
   (list*
    'fillers
    (map frame-filler->datum
         (sort (frame-realisation-fillers value) address<? #:key car)))
   (list 'context
         (checked-term->datum (frame-realisation-context value)))
   (list 'seed-proof
         (value->datum (frame-realisation-seed-proof value)))))

(define (boundary-recurrence->datum value)
  (list
   'boundary-recurrence
   (list 'boundary
         (hypersequent->datum (boundary-recurrence-boundary value)))
   (list 'status (boundary-recurrence-status value))
   (list 'theorem-holds? (boundary-recurrence-theorem-holds? value))
   (list 'raw-cycle (value->datum (boundary-recurrence-raw-cycle value)))
   (list 'realised-cycle
         (value->datum (boundary-recurrence-realised-cycle value)))
   (list 'realisation
         (value->datum (boundary-recurrence-realisation value)))
   (list 'context-decomposition
         (value->datum (boundary-recurrence-decomposition value)))
   (list 'productivity
         (value->datum (boundary-recurrence-productivity value)))))

(define (return-spine-frame->datum value)
  (list
   'return-spine-frame
   (list 'address (return-spine-frame-address value))
   (list 'occurrence-id
         (concrete-occurrence-id
          (return-spine-frame-occurrence value)))
   (list 'selected-slot (return-spine-frame-selected-slot value))
   (list 'root-boundary
         (hypersequent->datum (return-spine-frame-root-boundary value)))
   (list 'selected-boundary
         (hypersequent->datum
          (return-spine-frame-selected-boundary value)))
   (list*
    'ordered-off-spine-children
    (for/list
        ([entry
          (in-list
           (sort (return-spine-frame-off-spine-children value)
                 < #:key car))])
      (list 'slot (car entry)
            (checked-term->datum (cdr entry)))))
   (list 'proper-return? (return-spine-frame-return? value))))

(define (return-spine-decomposition->datum value)
  (list
   'return-spine-decomposition
   (list 'source
         (checked-term->datum (return-spine-decomposition-source value)))
   (list 'puncture (return-spine-decomposition-puncture value))
   (list*
    'constructor-frames
    (map return-spine-frame->datum
         (return-spine-decomposition-frames value)))
   (list 'proper-return-addresses
         (return-spine-decomposition-proper-return-addresses value))
   (list 'reconstructed
         (checked-term->datum
          (return-spine-decomposition-reconstructed value)))
   (list 'reconstructs?
         (return-spine-decomposition-reconstructs? value))))

(define (return-expansion-step->datum value)
  (list
   'return-expansion-step
   (list 'stage (return-expansion-step-stage value))
   (list 'kind (return-expansion-step-kind value))
   (list 'addresses
         (sort (return-expansion-step-addresses value) address<?))
   (list 'source-forest
         (proof-forest->datum
          (return-expansion-step-source-forest value)))
   (list 'cut-witness
         (value->datum (return-expansion-step-cut-witness value)))
   (list 'left-forest
         (proof-forest->datum
          (return-expansion-step-left-forest value)))
   (list 'right-forest
         (proof-forest->datum
          (return-expansion-step-right-forest value)))))

(define (ordered-forests->datum tag forests)
  (list*
   tag
   (for/list ([forest (in-list forests)]
              [coordinate (in-naturals 1)])
     (list 'coordinate coordinate (proof-forest->datum forest)))))

(define (return-iterated-witness->datum value)
  (list
   'return-iterated-witness
   (list 'power (return-iterated-witness-power value))
   (list*
    'ordered-expansion-steps
    (map return-expansion-step->datum
         (return-iterated-witness-steps value)))
   (ordered-forests->datum
    'ordered-coordinate-forests
    (return-iterated-witness-coordinate-forests value))
   (list 'tensor
         (formal-sum->datum (return-iterated-witness-tensor value)))
   (list 'coordinate-values
         (return-iterated-witness-coordinate-values value))
   (list 'survives? (return-iterated-witness-survives? value))
   (list 'reverse-chain-addresses
         (return-iterated-witness-reverse-chain-addresses value))))

(define (return-chain-witness->datum value)
  (list
   'return-chain-witness
   (list 'constructor-decisions
         (return-chain-witness-constructor-decisions value))
   (list 'addresses (return-chain-witness-addresses value))
   (list*
    'ordered-staged-cut-witnesses
    (map cut-witness->datum
         (return-chain-witness-staged-witnesses value)))
   (ordered-forests->datum
    'ordered-coordinate-forests
    (return-chain-witness-coordinate-forests value))
   (list 'tensor (formal-sum->datum (return-chain-witness-tensor value)))
   (list 'reconstructs? (return-chain-witness-reconstructs? value))))

(define (return-witness-bijection->datum value)
  (list
   'return-witness-bijection
   (list 'addresses (return-witness-bijection-addresses value))
   (list 'chain-witness
         (return-chain-witness->datum
          (return-witness-bijection-chain-witness value)))
   (list 'iterated-witness
         (return-iterated-witness->datum
          (return-witness-bijection-iterated-witness value)))
   (list 'forward-tensor-equal?
         (return-witness-bijection-forward-tensor-equal? value))
   (list 'reverse-chain-equal?
         (return-witness-bijection-reverse-chain-equal? value))
   (list 'roundtrip? (return-witness-bijection-roundtrip? value))))

(define (return-tensor-evaluation->datum value)
  (list
   'return-tensor-evaluation
   (list*
    'tensor
    (for/list ([forest (in-vector (return-tensor-evaluation-key value))])
      (proof-forest->datum forest)))
   (list 'coefficient (return-tensor-evaluation-coefficient value))
   (list 'coordinate-values
         (return-tensor-evaluation-coordinate-values value))
   (list 'contribution (return-tensor-evaluation-contribution value))
   (list 'survives? (return-tensor-evaluation-survives? value))))

(define (return-power-certificate->datum value)
  (list
   'return-convolution-power-certificate
   (list 'power (return-power-certificate-power value))
   (list 'source
         (checked-term->datum (return-power-certificate-source value)))
   (list 'spine-decomposition
         (return-spine-decomposition->datum
          (return-power-certificate-spine-decomposition value)))
   (list 'actual-iterated-coproduct
         (formal-sum->datum
          (return-power-certificate-actual-iterated-coproduct value)))
   (list*
    'collected-tensor-evaluations
    (map return-tensor-evaluation->datum
         (sort
          (return-power-certificate-tensor-evaluations value)
          tensor-key<?
          #:key return-tensor-evaluation-key)))
   (list 'actual-survivor-projection
         (formal-sum->datum
          (return-power-certificate-actual-survivor-projection value)))
   (list*
    'uncollected-iterated-witnesses
    (map return-iterated-witness->datum
         (return-power-certificate-iterated-occurrence-witnesses value)))
   (list 'uncollected-iterated-witness-count
         (length
          (return-power-certificate-iterated-occurrence-witnesses value)))
   (list 'uncollected-iterated-sum
         (formal-sum->datum
          (return-power-certificate-uncollected-iterated-sum value)))
   (list*
    'surviving-uncollected-witnesses
    (map return-iterated-witness->datum
         (return-power-certificate-surviving-occurrence-witnesses value)))
   (list 'surviving-uncollected-witness-count
         (length
          (return-power-certificate-surviving-occurrence-witnesses value)))
   (list 'uncollected-survivor-projection
         (formal-sum->datum
          (return-power-certificate-uncollected-survivor-projection value)))
   (list*
    'recursive-chain-witnesses
    (map return-chain-witness->datum
         (return-power-certificate-chain-witnesses value)))
   (list 'recursive-chain-projection
         (formal-sum->datum
          (return-power-certificate-recursive-chain-projection value)))
   (list*
    'witness-bijections
    (map return-witness-bijection->datum
         (sort
          (return-power-certificate-witness-bijections value)
          address-word<?
          #:key return-witness-bijection-addresses)))
   (list 'actual-value (return-power-certificate-actual-value value))
   (list 'chain-count (return-power-certificate-chain-count value))
   (list 'binomial-expected
         (return-power-certificate-binomial-expected value))
   (list 'uncollected-iterated-equal?
         (return-power-certificate-uncollected-iterated-equal? value))
   (list 'occurrence-projection-equal?
         (return-power-certificate-occurrence-projection-equal? value))
   (list 'projection-equal?
         (return-power-certificate-projection-equal? value))
   (list 'scalar-equal?
         (return-power-certificate-scalar-equal? value))
   (list 'witness-count-equal?
         (return-power-certificate-witness-count-equal? value))
   (list 'witness-bijection-holds?
         (return-power-certificate-witness-bijection-holds? value))))

(define (return-polynomial->datum value)
  (list
   'return-factorisation-polynomial
   (list 'return-count (return-polynomial-data-return-count value))
   (list 'coefficients
         (vector->list (return-polynomial-data-coefficients value)))
   (list 'closed-form-coefficients
         (vector->list
          (return-polynomial-data-closed-form-coefficients value)))
   (list 'equal? (return-polynomial-data-equal? value))))

(define (first-return-certificate->datum value)
  (list
   'first-return-certificate
   (list 'source
         (checked-term->datum (first-return-certificate-source value)))
   (list 'boundary
         (hypersequent->datum
          (boundary-return-character-boundary
           (first-return-certificate-character value))))
   (list 'puncture (first-return-certificate-puncture value))
   (list 'proper-return-addresses
         (first-return-certificate-proper-return-addresses value))
   (list*
    'convolution-powers
    (map return-power-certificate->datum
         (first-return-certificate-power-certificates value)))
   (list 'polynomial
         (return-polynomial->datum
          (first-return-certificate-polynomial value)))
   (list 'antipode-image
         (formal-sum->datum
          (first-return-certificate-antipode-image value)))
   (list 'antipode-character-value
         (first-return-certificate-antipode-character-value value))
   (list 'polynomial-at-minus-one
         (first-return-certificate-polynomial-at-minus-one value))
   (list 'first-return-indicator
         (first-return-certificate-first-return-indicator value))
   (list 'classification
         (if (= (first-return-certificate-first-return-indicator value) 1)
             'first-return
             'composite))
   (list 'direct-first-return?
         (first-return-certificate-direct-first-return? value))
   (list 'polynomial-antipode-sign-law?
         (first-return-certificate-polynomial-antipode-sign-law? value))
   (list 'indicator-law?
         (first-return-certificate-indicator-law? value))
   (list 'theorem-holds?
         (first-return-certificate-theorem-holds? value))))

(define (unfolding-layer->datum value)
  (list
   'unfolding-layer
   (list 'power (unfolding-layer-power value))
   (list 'context (checked-term->datum (unfolding-layer-context value)))
   (list 'inserted-root-address
         (unfolding-layer-inserted-root-address value))
   (list 'puncture-address (unfolding-layer-puncture-address value))
   (list 'return-certificate
         (first-return-certificate->datum
          (unfolding-layer-return-certificate value)))
   (list 'power-law? (unfolding-layer-power-law? value))))

(define (seeded-unfolding-certificate->datum value)
  (list
   'seeded-unfolding-certificate
   (list 'power (seeded-unfolding-certificate-power value))
   (list*
    'layers
    (map unfolding-layer->datum
         (seeded-unfolding-certificate-layers value)))
   (list 'seed
         (checked-term->datum (seeded-unfolding-certificate-seed value)))
   (list 'completed-proof
         (checked-term->datum
          (seeded-unfolding-certificate-completed-proof value)))
   (list 'separation-addresses
         (seeded-unfolding-certificate-separation-addresses value))
   (list*
    'ordered-staged-cut-witnesses
    (map cut-witness->datum
         (seeded-unfolding-certificate-staged-witnesses value)))
   (ordered-forests->datum
    'ordered-coordinate-forests
    (seeded-unfolding-certificate-coordinate-forests value))
   (list 'actual-iterated-coproduct
         (formal-sum->datum
          (seeded-unfolding-certificate-actual-iterated-coproduct value)))
   (list 'collected-coefficient
         (seeded-unfolding-certificate-collected-coefficient value))
   (list 'reconstructs?
         (seeded-unfolding-certificate-reconstructs? value))))

(define (side-evidence-data->datum value)
  (list
   'side-evidence-factorisation
   (list 'source (checked-term->datum (side-evidence-data-source value)))
   (list 'puncture (side-evidence-data-puncture value))
   (list 'spine-addresses (side-evidence-data-spine-addresses value))
   (list 'frontier-addresses
         (sort (side-evidence-data-frontier-addresses value) address<?))
   (list 'cut-witness (value->datum (side-evidence-data-witness value)))
   (list 'side-evidence-forest
         (proof-forest->datum (side-evidence-data-forest value)))
   (list 'bare-spine-remainder
         (checked-term->datum
          (side-evidence-data-bare-spine-remainder value)))
   (list 'new-puncture-addresses
         (sort (side-evidence-data-new-puncture-addresses value) address<?))
   (list 'reconstruction
         (checked-term->datum (side-evidence-data-reconstruction value)))
   (list 'reconstructs? (side-evidence-data-reconstructs? value))))

(define (side-evidence-product->datum value)
  (list
   'side-evidence-product-certificate
   (list 'outer
         (checked-term->datum
          (side-evidence-product-certificate-outer value)))
   (list 'inner
         (checked-term->datum
          (side-evidence-product-certificate-inner value)))
   (list 'composed
         (checked-term->datum
          (side-evidence-product-certificate-composed value)))
   (list 'prefixed-inner-frontier
         (sort
          (side-evidence-product-certificate-prefixed-inner-frontier value)
          address<?))
   (list 'expected-forest
         (proof-forest->datum
          (side-evidence-product-certificate-expected-forest value)))
   (list 'frontier-equal?
         (side-evidence-product-certificate-frontier-equal? value))
   (list 'forest-equal?
         (side-evidence-product-certificate-forest-equal? value))
   (list 'reconstruction-holds?
         (side-evidence-product-certificate-reconstruction-holds? value))))

(define (relation-pair<? left right)
  (or (< (car left) (car right))
      (and (= (car left) (car right))
           (< (cadr left) (cadr right)))))

(define (component-relation-power->datum value)
  (list
   'component-relation-power
   (list 'power (component-relation-power-power value))
   (list 'relation-pairs
         (sort (component-relation-power-edges value) relation-pair<?))
   (list 'checked-context
         (checked-term->datum (component-relation-power-context value)))
   (list 'direct-trace
         (value->datum (component-relation-power-direct-trace value)))
   (list 'direct-relation-pairs
         (and (component-relation-power-direct-edges value)
              (sort (component-relation-power-direct-edges value)
                    relation-pair<?)))
   (list 'agrees? (component-relation-power-agrees? value))))

(define (component-recurrence->datum value)
  (list
   'component-recurrence-analysis
   (list 'status (component-recurrence-analysis-status value))
   (list 'source
         (checked-term->datum (component-recurrence-analysis-source value)))
   (list 'trace (value->datum (component-recurrence-analysis-trace value)))
   (list*
    'finite-relation-powers
    (map component-relation-power->datum
         (component-recurrence-analysis-powers value)))
   (list 'repeat-start
         (component-recurrence-analysis-repeat-start value))
   (list 'period (component-recurrence-analysis-period value))
   (list 'relation-state-count-bound
         (component-recurrence-analysis-relation-state-count-bound value))
   (list 'exhaustive-state-bound-reached?
         (component-recurrence-analysis-exhaustive-state-bound-reached? value))
   (list 'direct-power-agreement?
         (component-recurrence-analysis-direct-power-agreement? value))
   (list 'scalar-analysis
         (component-scalar-analysis->datum
          (component-recurrence-analysis-scalar-analysis value)))
   (list 'scalar-calibrated?
         (component-recurrence-analysis-scalar-calibrated? value))
   (list 'local-scalar-distribution
         (component-recurrence-analysis-local-scalar-distribution value))))

(define (pointed-input-position->datum value)
  (list
   'pointed-input-position
   (list 'index (pointed-input-position-index value))
   (list 'outer-address (pointed-input-position-outer-address value))
   (list 'boundary
         (hypersequent->datum (pointed-input-position-boundary value)))
   (list 'input (checked-term->datum (pointed-input-position-input value)))))

(define (pointed-coaction-choice->datum value)
  (list
   'pointed-coaction-choice
   (list 'position
         (pointed-input-position-index
          (pointed-coaction-choice-position value)))
   (list 'kind (pointed-coaction-choice-kind value))
   (list 'relative-addresses
         (sort (pointed-coaction-choice-relative-addresses value) address<?))
   (list 'cut-witness
         (value->datum (pointed-coaction-choice-witness value)))
   (list 'detached-forest
         (proof-forest->datum
          (pointed-coaction-choice-detached-forest value)))
   (list 'retained-input
         (checked-term->datum
          (pointed-coaction-choice-retained-input value)))))

(define (pointed-choice-tuple->datum value)
  (list
   'pointed-choice-tuple
   (list*
    'ordered-choices
    (map pointed-coaction-choice->datum
         (pointed-choice-tuple-choices value)))
   (list 'multiplied-detached-forest
         (proof-forest->datum
          (pointed-choice-tuple-detached-forest value)))
   (list*
    'ordered-retained-inputs
    (for/list ([input (in-list (pointed-choice-tuple-retained-inputs value))]
               [position (in-naturals 1)])
      (list 'position position (checked-term->datum input))))
   (list 'global-addresses
         (sort (pointed-choice-tuple-global-addresses value) address<?))))

(define (pointed-input-coaction->datum value)
  (list
   'pointed-input-coaction-certificate
   (list 'protected-positions
         (pointed-input-coaction-certificate-protected-positions value))
   (list*
    'ordered-positions
    (map pointed-input-position->datum
         (pointed-input-coaction-certificate-positions value)))
   (list*
    'ordered-choice-families
    (for/list
        ([family
          (in-list
           (pointed-input-coaction-certificate-choice-families value))]
         [position (in-naturals 1)])
      (list*
       'position
       position
       (map pointed-coaction-choice->datum family))))
   (list 'tuple-count
         (pointed-input-coaction-certificate-tuple-count value))
   (list*
    'tuples
    (map pointed-choice-tuple->datum
         (pointed-input-coaction-certificate-tuples value)))))

(define (grafting-choice-certificate->datum value)
  (list
   'grafting-choice-witness
   (list 'choice-tuple
         (pointed-choice-tuple->datum
          (grafting-choice-certificate-choice-tuple value)))
   (list 'grafted-remainder
         (checked-term->datum
          (grafting-choice-certificate-grafted-remainder value)))
   (list 'global-cut-witness
         (cut-witness->datum
          (grafting-choice-certificate-global-witness value)))
   (list 'reconstruction
         (checked-term->datum
          (grafting-choice-certificate-reconstruction value)))
   (list 'reconstructs?
         (grafting-choice-certificate-reconstructs? value))
   (list 'forest-agrees?
         (grafting-choice-certificate-forest-agrees? value))
   (list 'remainder-agrees?
         (grafting-choice-certificate-remainder-agrees? value))
   (list 'tensor
         (formal-sum->datum
          (grafting-choice-certificate-tensor value)))))

(define (grafting-reverse-certificate->datum value)
  (list
   'grafting-reverse-witness
   (list 'cut-witness
         (cut-witness->datum
          (grafting-reverse-certificate-witness value)))
   (list 'recovered-choice-tuple
         (pointed-choice-tuple->datum
          (grafting-reverse-certificate-recovered-choice-tuple value)))
   (list 'forward-addresses
         (sort (grafting-reverse-certificate-forward-addresses value)
               address<?))
   (list 'addresses-round-trip?
         (grafting-reverse-certificate-addresses-round-trip? value))
   (list 'choices-round-trip?
         (grafting-reverse-certificate-choices-round-trip? value))))

(define (typed-grafting-cocycle->datum value)
  (list
   'typed-grafting-cocycle-certificate
   (list 'occurrence
         (occurrence->datum
          (typed-grafting-cocycle-certificate-occurrence value)))
   (list*
    'ordered-premise-profile
    (for/list
        ([boundary
          (in-list
           (typed-grafting-cocycle-certificate-premise-profile value))]
         [slot (in-naturals 1)])
      (list 'slot slot (hypersequent->datum boundary))))
   (list*
    'ordered-inputs
    (for/list
        ([input (in-list (typed-grafting-cocycle-certificate-inputs value))]
         [slot (in-naturals 1)])
      (list 'slot slot (checked-term->datum input))))
   (list 'grafted
         (checked-term->datum
          (typed-grafting-cocycle-certificate-grafted value)))
   (list 'input-coaction
         (pointed-input-coaction->datum
          (typed-grafting-cocycle-certificate-input-coaction value)))
   (list 'whole-tree-endpoint
         (formal-sum->datum
          (typed-grafting-cocycle-certificate-endpoint value)))
   (list*
    'forward-witnesses
    (map grafting-choice-certificate->datum
         (sort
          (typed-grafting-cocycle-certificate-forward-certificates value)
          address-set<?
          #:key
          (lambda (certificate)
            (cut-witness-addresses
             (grafting-choice-certificate-global-witness certificate))))))
   (list*
    'reverse-witnesses
    (map grafting-reverse-certificate->datum
         (sort
          (typed-grafting-cocycle-certificate-reverse-certificates value)
          address-set<?
          #:key
          (lambda (certificate)
            (cut-witness-addresses
             (grafting-reverse-certificate-witness certificate))))))
   (list 'recursive-collected-tensor
         (formal-sum->datum
          (typed-grafting-cocycle-certificate-recursive-coproduct value)))
   (list 'direct-collected-tensor
         (formal-sum->datum
          (typed-grafting-cocycle-certificate-direct-coproduct value)))
   (list 'defect-kind
         (if (typed-grafting-cocycle-certificate-equal? value)
             'zero-cocycle-defect
             'nonzero-cocycle-defect))
   (list 'forward-valid?
         (typed-grafting-cocycle-certificate-forward-valid? value))
   (list 'reverse-valid?
         (typed-grafting-cocycle-certificate-reverse-valid? value))
   (list 'witness-bijection?
         (typed-grafting-cocycle-certificate-witness-bijection? value))
   (list 'equal?
         (typed-grafting-cocycle-certificate-equal? value))))

(define (vertex-origin->datum value)
  (list
   'vertex-origin
   (list 'address (vertex-origin-address value))
   (list 'kind (vertex-origin-kind value))
   (list 'position (vertex-origin-position value))
   (list 'outer-address (vertex-origin-outer-address value))
   (list 'relative-address (vertex-origin-relative-address value))
   (list 'occurrence-id
         (concrete-occurrence-id
          (checked-node-occurrence (vertex-origin-vertex value))))))

(define (protected-cut-record->datum value)
  (list
   'protected-cut-record
   (list 'addresses
         (sort (protected-cut-record-addresses value) address<?))
   (list 'disposition (protected-cut-record-disposition value))
   (list*
    'selected-origins
    (map vertex-origin->datum
         (sort (protected-cut-record-selected-origins value)
               address<? #:key vertex-origin-address)))
   (list 'cut-witness
         (cut-witness->datum (protected-cut-record-witness value)))
   (list 'retained-context
         (checked-term->datum
          (protected-cut-record-retained-context value)))
   (list 'reconstruction
         (checked-term->datum
          (protected-cut-record-reconstruction value)))
   (list 'reconstructs? (protected-cut-record-reconstructs? value))
   (list 'cancellation-round-trip?
         (protected-cut-record-cancellation-round-trip? value))
   (list 'tensor
         (formal-sum->datum (protected-cut-record-tensor value)))))

(define (protected-choice-certificate->datum value)
  (list
   'protected-choice-witness
   (list 'choice-tuple
         (pointed-choice-tuple->datum
          (protected-choice-certificate-choice-tuple value)))
   (list 'evaluated-remainder
         (checked-term->datum
          (protected-choice-certificate-evaluated-remainder value)))
   (list 'global-cut-witness
         (cut-witness->datum
          (protected-choice-certificate-global-witness value)))
   (list 'reconstruction
         (checked-term->datum
          (protected-choice-certificate-reconstruction value)))
   (list 'reconstructs?
         (protected-choice-certificate-reconstructs? value))
   (list 'forest-agrees?
         (protected-choice-certificate-forest-agrees? value))
   (list 'remainder-agrees?
         (protected-choice-certificate-remainder-agrees? value))
   (list 'tensor
         (formal-sum->datum
          (protected-choice-certificate-tensor value)))))

(define (protected-factorization->datum value)
  (define defect (protected-factorization-certificate-defect value))
  (list
   'protected-factorisation-defect-certificate
   (list 'context
         (checked-term->datum
          (protected-factorization-certificate-context value)))
   (list*
    'addressed-telescope
    (map telescope-entry->datum
         (protected-factorization-certificate-telescope value)))
   (list*
    'ordered-inputs
    (for/list
        ([input
          (in-list (protected-factorization-certificate-inputs value))]
         [position (in-naturals 1)])
      (list 'position position (checked-term->datum input))))
   (list 'protected-positions
         (protected-factorization-certificate-protected-positions value))
   (list 'output
         (checked-term->datum
          (protected-factorization-certificate-output value)))
   (list 'protected-input-coaction
         (pointed-input-coaction->datum
          (protected-factorization-certificate-input-coaction value)))
   (list*
    'protected-choice-witnesses
    (map protected-choice-certificate->datum
         (sort
          (protected-factorization-certificate-choice-certificates value)
          address-set<?
          #:key
          (lambda (certificate)
            (cut-witness-addresses
             (protected-choice-certificate-global-witness certificate))))))
   (list*
    'vertex-provenance
    (map vertex-origin->datum
         (sort
          (protected-factorization-certificate-vertex-origins value)
          address<? #:key vertex-origin-address)))
   (list*
    'cut-records
    (map protected-cut-record->datum
         (sort
          (protected-factorization-certificate-cut-records value)
          address-set<? #:key protected-cut-record-addresses)))
   (list 'direct-root-coaction
         (formal-sum->datum
          (protected-factorization-certificate-direct-coaction value)))
   (list 'evaluated-protected-input-coaction
         (formal-sum->datum
          (protected-factorization-certificate-evaluated-input-coaction
           value)))
   (list 'defect (formal-sum->datum defect))
   (list 'defect-kind
         (if (formal-zero? defect)
             'zero-protected-defect
             'nonzero-protected-defect))
   (list 'residual-witness-sum
         (formal-sum->datum
          (protected-factorization-certificate-residual-witness-sum value)))
   (list 'cancellation-bijection?
         (protected-factorization-certificate-cancellation-bijection? value))
   (list 'support-theorem?
         (protected-factorization-certificate-support-theorem? value))
   (list 'collected-coefficients-agree?
         (protected-factorization-certificate-collected-coefficients-agree?
          value))))

(define (calculus-recurrence-report->datum value)
  (list
   'calculus-recurrence-report
   (list 'calculus
         (equipped-calculus->datum
          (calculus-recurrence-report-calculus value)))
   (list 'boundary
         (hypersequent->datum
          (calculus-recurrence-report-boundary value)))
   (list 'status (calculus-recurrence-report-status value))
   (list 'component-bound
         (calculus-recurrence-report-component-bound value))
   (list 'limit (calculus-recurrence-report-limit value))
   (list 'graph
         (derivative-frame-graph->datum
          (calculus-recurrence-report-graph value)))
   (list 'recurrence
         (value->datum (calculus-recurrence-report-recurrence value)))
   (list 'return-report
         (value->datum (calculus-recurrence-report-return-report value)))))

(define (return-context-report->datum value)
  (list
   'return-context-report
   (list 'calculus
         (equipped-calculus->datum
          (return-context-report-calculus value)))
   (list 'boundary
         (hypersequent->datum (return-context-report-boundary value)))
   (list 'source
         (checked-term->datum (return-context-report-source value)))
   (list 'status (return-context-report-status value))
   (list 'component-status
         (return-context-report-component-status value))
   (list 'component-bound
         (return-context-report-component-bound value))
   (list 'limit (return-context-report-limit value))
   (list 'first-return-analysis
         (value->datum (return-context-report-certificate value)))
   (list 'component-recurrence
         (value->datum
          (return-context-report-component-recurrence value)))))

(define (grafting-cocycle-report->datum value)
  (list
   'grafting-cocycle-report
   (list 'calculus
         (equipped-calculus->datum
          (grafting-cocycle-report-calculus value)))
   (list 'occurrence
         (occurrence->datum (grafting-cocycle-report-occurrence value)))
   (list*
    'ordered-inputs
    (for/list ([input (in-list (grafting-cocycle-report-inputs value))]
               [slot (in-naturals 1)])
      (list 'slot slot (checked-term->datum input))))
   (list 'status (grafting-cocycle-report-status value))
   (list 'limit (grafting-cocycle-report-limit value))
   (list 'certificate
         (value->datum (grafting-cocycle-report-certificate value)))))

(define (protected-defect-report->datum value)
  (list
   'protected-defect-report
   (list 'calculus
         (equipped-calculus->datum
          (protected-defect-report-calculus value)))
   (list 'context
         (checked-term->datum (protected-defect-report-context value)))
   (list*
    'ordered-inputs
    (for/list ([input (in-list (protected-defect-report-inputs value))]
               [position (in-naturals 1)])
      (list 'position position (checked-term->datum input))))
   (list 'protected-positions
         (protected-defect-report-protected-positions value))
   (list 'status (protected-defect-report-status value))
   (list 'limit (protected-defect-report-limit value))
   (list 'certificate
         (value->datum (protected-defect-report-certificate value)))))

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
    [(calculus-recurrence-report? value)
     (calculus-recurrence-report->datum value)]
    [(return-context-report? value) (return-context-report->datum value)]
    [(grafting-cocycle-report? value)
     (grafting-cocycle-report->datum value)]
    [(protected-defect-report? value)
     (protected-defect-report->datum value)]
    [(typed-grafting-cocycle-certificate? value)
     (typed-grafting-cocycle->datum value)]
    [(protected-factorization-certificate? value)
     (protected-factorization->datum value)]
    [(boundary-recurrence? value) (boundary-recurrence->datum value)]
    [(derivative-frame-graph? value) (derivative-frame-graph->datum value)]
    [(derivative-frame-edge? value) (derivative-frame-edge->datum value)]
    [(frame-off-spine? value) (frame-off-spine->datum value)]
    [(frame-productivity? value) (frame-productivity->datum value)]
    [(productivity-witness? value) (productivity-witness->datum value)]
    [(frame-cycle? value) (frame-cycle->datum value)]
    [(frame-realisation? value) (frame-realisation->datum value)]
    [(first-return-certificate? value) (first-return-certificate->datum value)]
    [(return-power-certificate? value)
     (return-power-certificate->datum value)]
    [(return-polynomial-data? value) (return-polynomial->datum value)]
    [(return-spine-decomposition? value)
     (return-spine-decomposition->datum value)]
    [(return-spine-frame? value) (return-spine-frame->datum value)]
    [(return-expansion-step? value) (return-expansion-step->datum value)]
    [(return-iterated-witness? value)
     (return-iterated-witness->datum value)]
    [(return-chain-witness? value) (return-chain-witness->datum value)]
    [(return-witness-bijection? value)
     (return-witness-bijection->datum value)]
    [(return-tensor-evaluation? value)
     (return-tensor-evaluation->datum value)]
    [(unfolding-layer? value) (unfolding-layer->datum value)]
    [(seeded-unfolding-certificate? value)
     (seeded-unfolding-certificate->datum value)]
    [(side-evidence-data? value) (side-evidence-data->datum value)]
    [(side-evidence-product-certificate? value)
     (side-evidence-product->datum value)]
    [(component-recurrence-analysis? value)
     (component-recurrence->datum value)]
    [(component-relation-power? value)
     (component-relation-power->datum value)]
    [(pointed-input-position? value) (pointed-input-position->datum value)]
    [(pointed-coaction-choice? value)
     (pointed-coaction-choice->datum value)]
    [(pointed-choice-tuple? value) (pointed-choice-tuple->datum value)]
    [(pointed-input-coaction-certificate? value)
     (pointed-input-coaction->datum value)]
    [(grafting-choice-certificate? value)
     (grafting-choice-certificate->datum value)]
    [(grafting-reverse-certificate? value)
     (grafting-reverse-certificate->datum value)]
    [(vertex-origin? value) (vertex-origin->datum value)]
    [(protected-choice-certificate? value)
     (protected-choice-certificate->datum value)]
    [(protected-cut-record? value) (protected-cut-record->datum value)]
    [(derivation-analysis? value) (derivation-analysis->datum value)]
    [(context-analysis? value) (context-analysis->datum value)]
    [(forest-analysis? value) (forest-analysis->datum value)]
    [(hopf-law-analysis? value) (hopf-law-analysis->datum value)]
    [(law-check? value) (law-check->datum value)]
    [(analysis-unavailable? value) (analysis-unavailable->datum value)]
    [(component-analysis? value) (component-analysis->datum value)]
    [(component-analysis-unavailable? value)
     (component-analysis-unavailable->datum value)]
    [(component-incidence? value) (component-incidence->datum value)]
    [(component-trace? value) (component-trace->datum value)]
    [(component-trace-unavailable? value)
     (component-trace-unavailable->datum value)]
    [(component-relation-classification? value)
     (component-relation-classification->datum value)]
    [(local-component-analysis? value)
     (local-component-analysis->datum value)]
    [(component-scalar-analysis? value)
     (component-scalar-analysis->datum value)]
    [(ck-component-profile? value) (ck-component-profile->datum value)]
    [(addressed-component? value) (addressed-component->datum value)]
    [(component-trace-edge? value) (component-trace-edge->datum value)]
    [(component-trace-input? value) (component-trace-input->datum value)]
    [(component-trace-blocker? value)
     (component-trace-blocker->datum value)]
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
              (calculus-recurrence-report? value)
              (return-context-report? value)
              (grafting-cocycle-report? value)
              (protected-defect-report? value)
              (typed-grafting-cocycle-certificate? value)
              (pointed-input-coaction-certificate? value)
              (protected-factorization-certificate? value)
              (boundary-recurrence? value)
              (derivative-frame-graph? value)
              (frame-cycle? value)
              (frame-realisation? value)
              (first-return-certificate? value)
              (return-power-certificate? value)
              (return-polynomial-data? value)
              (return-spine-decomposition? value)
              (return-iterated-witness? value)
              (return-chain-witness? value)
              (return-witness-bijection? value)
              (unfolding-layer? value)
              (seeded-unfolding-certificate? value)
              (side-evidence-data? value)
              (side-evidence-product-certificate? value)
              (component-recurrence-analysis? value)
              (component-relation-power? value)
              (context-analysis? value)
              (forest-analysis? value)
              (hopf-law-analysis? value)
              (law-check? value)
              (analysis-unavailable? value)
              (analysis-limit? value)
              (analysis-error? value)
              (component-analysis? value)
              (component-analysis-unavailable? value)
              (component-trace-result? value)
              (component-incidence? value)
              (component-relation-classification? value)
              (ck-component-profile? value))
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

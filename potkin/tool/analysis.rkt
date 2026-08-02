#lang racket/base

(require racket/list
         "../algebra/formal-sum.rkt"
         "../analysis/ancestry.rkt"
         "../analysis/convolution.rkt"
         "../dsl/term.rkt"
         "../hopf/antipode.rkt"
         "../hopf/ck.rkt"
         "../kernel/address.rkt"
         "../kernel/calculus.rkt"
         "../kernel/check.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt")

(provide (struct-out analysis-unavailable)
         (struct-out premise-slot-analysis)
         (struct-out vertex-analysis)
         (struct-out cut-analysis)
         (struct-out law-check)
         (struct-out hopf-law-analysis)
         (struct-out derivation-analysis)
         (struct-out context-analysis)
         (struct-out forest-analysis)
         analyze-derivation
         analyze-context
         analyze-forest
         check-hopf-laws)

;; Reports contain the exact executable values.  Rendering is a separate,
;; provenance-forgetting presentation step in present.rkt.
(struct analysis-unavailable (reason details) #:transparent)
(struct premise-slot-analysis
  (slot requirement child-address child-kind)
  #:transparent)
(struct vertex-analysis
  (address id tag kind instance premise-slots)
  #:transparent)
(struct cut-analysis
  (addresses detached remainder forest reconstructs?)
  #:transparent)
(struct law-check (name status expected actual) #:transparent)
(struct hopf-law-analysis
  (source
   coassociativity
   counit-left
   counit-right
   antipode-left
   antipode-right
   coaction-coassociativity
   coaction-counit
   zeta-order-map
   omega-linear-extension)
  #:transparent)
(struct derivation-analysis
  (source
   root
   complete?
   interface
   vertex-count
   vertex-table
   puncture-telescope
   cut-witnesses
   singleton
   coproduct
   reduced-coproduct
   root-coaction
   degree
   counit
   antipode
   final-corolla-factorization
   final-corolla-projection
   cut-size-polynomial
   ancestry-vertices
   ancestry-cover-edges
   ancestry-ideals
   ancestry-width
   weak-order-map-count
   zeta-convolution-power
   linear-extension-count
   omega-one-convolution-power
   refinement-orders
   refinement-order-count
   hopf-laws
   limit)
  #:transparent)
(struct context-analysis
  (source root interface vertex-count puncture-telescope connected)
  #:transparent)
(struct forest-analysis
  (source size degree basis coproduct reduced-coproduct counit antipode
          hopf-laws limit)
  #:transparent)

(define (check-analysis-limit who limit)
  (unless (or (not limit) (exact-nonnegative-integer? limit))
    (raise-argument-error
     who "(or/c #f exact-nonnegative-integer?)" limit)))

(define (over-limit? value limit)
  (and limit (> value limit)))

(define (cap-add left right limit)
  (define value (+ left right))
  (if (over-limit? value limit) (add1 limit) value))

(define (cap-multiply left right limit)
  (cond
    [(or (zero? left) (zero? right)) 0]
    [(not limit) (* left right)]
    [(or (> left limit) (> right limit)) (add1 limit)]
    [(> left (quotient limit right)) (add1 limit)]
    [else (* left right)]))

(define (cap-power base exponent limit)
  (let loop ([remaining exponent] [result 1])
    (cond
      [(zero? remaining) result]
      [else
       (define next (cap-multiply result base limit))
       (if (over-limit? next limit)
           next
           (loop (sub1 remaining) next))])))

(define (tool-limit operation limit required metric [details (hash)])
  (analysis-limit
   'not-computed-limit
   "the exact report analysis exceeds its configured finite limit"
   operation limit required metric details))

(define (result-status value)
  (cond
    [(analysis-limit? value) 'not-computed]
    [(or (analysis-error? value)
         (algebra-error? value)
         (hopf-error? value)
         (antipode-error? value))
     'error]
    [else #f]))

(define (equality-law name expected actual)
  (define exceptional
    (or (result-status expected) (result-status actual)))
  (cond
    [(eq? exceptional 'not-computed)
     (law-check name 'not-computed expected actual)]
    [exceptional (law-check name 'error expected actual)]
    [(equal? expected actual)
     (law-check name 'pass expected actual)]
    [else (law-check name 'fail expected actual)]))

(define (unavailable-law name reason)
  (define unavailable (analysis-unavailable reason (hash)))
  (law-check name 'not-applicable unavailable unavailable))

(define (limited-law name limit-value)
  (law-check name 'not-computed limit-value limit-value))

(define (formal-input source who)
  (cond
    [(checked-node? source) (checked-node-basis source)]
    [(proof-forest? source) (forest-basis source)]
    [(formal-sum? source)
     (unless (= (formal-sum-rank source) 1)
       (raise-arguments-error
        who
        "Hopf-law inspection requires a rank-one formal sum"
        "rank" (formal-sum-rank source)))
     source]
    [else
     (raise-argument-error
      who "(or/c checked-node? proof-forest? formal-sum?)" source)]))

(define (polynomial-coefficient-sum polynomial)
  (for/sum ([coefficient (in-vector polynomial)]) coefficient))

;; This upper bound is computed before any exponential cut traversal.  It is
;; the total absolute coefficient mass of the first coproduct before possible
;; cancellation between separate input summands.
(define (connected-coproduct-mass term limit operation)
  (define ancestry (premise-ancestry-of term))
  (cond
    [(analysis-error? ancestry) ancestry]
    [else
     (define polynomial (cut-size-polynomial ancestry #:limit limit))
     (if (analysis-limit? polynomial)
         polynomial
         (let ([mass (+ 2 (polynomial-coefficient-sum polynomial))])
           (if (over-limit? mass limit)
               (tool-limit
                operation limit mass 'coproduct-coefficient-mass
                (hash 'vertex-count (derivation-vertex-count term)))
               mass)))]))

(define (forest-coproduct-mass forest limit operation)
  (let loop ([factors (proof-forest-factors forest)] [mass 1])
    (cond
      [(null? factors) mass]
      [else
       (define factor-mass
         (connected-coproduct-mass (car factors) limit operation))
       (cond
         [(analysis-limit? factor-mass)
          ;; Limit diagnostics are deliberately forest-global, so an
          ;; unspecified commutative-factor traversal cannot affect them.
          (tool-limit
           operation limit (add1 limit) 'coproduct-coefficient-mass
           (hash 'forest-degree (forest-degree forest)))]
         [(analysis-error? factor-mass) factor-mass]
         [else
          (define next (cap-multiply mass factor-mass limit))
          (if (over-limit? next limit)
              (tool-limit
               operation limit next 'coproduct-coefficient-mass
               (hash 'forest-degree (forest-degree forest)))
              (loop (cdr factors) next))])])))

(define (formal-coproduct-preflight sum limit operation)
  (let loop ([entries (formal-sum-terms sum)] [mass 0])
    (cond
      [(null? entries) mass]
      [else
       (define entry (car entries))
       (define forest (vector-ref (car entry) 0))
       (define forest-mass
         (forest-coproduct-mass forest limit operation))
       (cond
         [(analysis-limit? forest-mass)
          ;; As above, report only input-global data before returning early
          ;; from an unordered formal-support traversal.
          (tool-limit
           operation limit (add1 limit) 'coproduct-coefficient-mass
           (hash 'support-size (formal-sum-support-size sum)))]
         [(analysis-error? forest-mass) forest-mass]
         [else
          (define weighted
            (cap-multiply (abs (cdr entry)) forest-mass limit))
          (define next (cap-add mass weighted limit))
          (if (over-limit? next limit)
              (tool-limit
               operation limit next 'coproduct-coefficient-mass
               (hash 'support-size (formal-sum-support-size sum)))
              (loop (cdr entries) next))])])))

;; A first coproduct bound alone does not bound either a rank-three
;; coassociativity expansion or the recursive antipode.  This deliberately
;; conservative finite-tree bound gates every compound law check before any
;; such work starts.  Rejecting early is preferable to presenting partially
;; explored algebra as an exact report.
(define (connected-work-bound term limit)
  (define degree (derivation-vertex-count term))
  (cap-power (max 3 (add1 degree)) degree limit))

(define (forest-work-bound forest limit)
  (let loop ([factors (proof-forest-factors forest)] [bound 1])
    (cond
      [(null? factors) bound]
      [else
       (define next
         (cap-multiply
          bound (connected-work-bound (car factors) limit) limit))
       (if (over-limit? next limit)
           next
           (loop (cdr factors) next))])))

(define (formal-work-preflight sum limit operation)
  (let loop ([entries (formal-sum-terms sum)] [bound 0])
    (cond
      [(null? entries) bound]
      [else
       (define entry (car entries))
       (define weighted
         (cap-multiply
          (abs (cdr entry))
          (forest-work-bound (vector-ref (car entry) 0) limit)
          limit))
       (define next (cap-add bound weighted limit))
       (if (over-limit? next limit)
           (tool-limit
            operation limit next 'compound-hopf-work-bound
            (hash 'support-size (formal-sum-support-size sum)))
           (loop (cdr entries) next))])))

(define (all-limited-laws source value)
  (define connected? (checked-node? source))
  (hopf-law-analysis
   source
   (limited-law 'coassociativity value)
   (limited-law 'counit-left value)
   (limited-law 'counit-right value)
   (limited-law 'antipode-left value)
   (limited-law 'antipode-right value)
   (if connected?
       (limited-law 'coaction-coassociativity value)
       (unavailable-law
        'coaction-coassociativity 'not-connected-input))
   (if connected?
       (limited-law 'coaction-counit value)
       (unavailable-law 'coaction-counit 'not-connected-input))
   (if connected?
       (limited-law 'zeta-order-map value)
       (unavailable-law 'zeta-order-map 'not-connected-input))
   (if connected?
       (limited-law 'omega-linear-extension value)
       (unavailable-law
        'omega-linear-extension 'not-connected-input))))

(define (singleton-root-coaction forest)
  (define factors (proof-forest-factors forest))
  (cond
    [(and (= (length factors) 1) (checked-node? (car factors)))
     (root-coaction (car factors))]
    [else
     (make-formal-sum
      (proof-forest-calculus forest)
      2
      '())]))

(define (check-hopf-laws source #:limit [limit analysis-default-limit])
  (check-analysis-limit 'check-hopf-laws limit)
  (define sum (formal-input source 'check-hopf-laws))
  (define preflight
    (formal-coproduct-preflight sum limit 'check-hopf-laws))
  (define work-preflight
    (if (or (analysis-limit? preflight) (analysis-error? preflight))
        preflight
        (formal-work-preflight sum limit 'check-hopf-laws)))
  (cond
    [(analysis-limit? work-preflight)
     (all-limited-laws source work-preflight)]
    [(analysis-error? work-preflight)
     (define error-law
       (law-check
        'hopf-preflight 'error work-preflight work-preflight))
     (hopf-law-analysis
      source error-law error-law error-law error-law error-law
      error-law error-law error-law error-law)]
    [else
     (define delta (coproduct sum))
     (define coassoc-left
       (if (formal-sum? delta)
           (formal-sum-expand-coordinate delta 1 2 forest-coproduct)
           delta))
     (define coassoc-right
       (if (formal-sum? delta)
           (formal-sum-expand-coordinate delta 2 2 forest-coproduct)
           delta))
     (define counit-left-value
       (if (formal-sum? delta) (tensor-counit-left delta) delta))
     (define counit-right-value
       (if (formal-sum? delta) (tensor-counit-right delta) delta))
     (define epsilon (counit sum))
     (define antipode-target
       (if (exact-integer? epsilon)
           (formal-sum-scale
            epsilon
            (algebra-unit (formal-sum-calculus sum)))
           epsilon))
     (define antipode-left-value (antipode-convolution-left sum))
     (define antipode-right-value (antipode-convolution-right sum))

     (define connected? (checked-node? source))
     (define coaction-coassoc-law
       (if connected?
           (let* ([rooted (root-coaction source)]
                  [left
                   (if (formal-sum? rooted)
                       (formal-sum-expand-coordinate
                        rooted 1 2 forest-coproduct)
                       rooted)]
                  [right
                   (if (formal-sum? rooted)
                       (formal-sum-expand-coordinate
                        rooted 2 2 singleton-root-coaction)
                       rooted)])
             (equality-law 'coaction-coassociativity left right))
           (unavailable-law
            'coaction-coassociativity 'not-connected-input)))
     (define coaction-counit-law
       (if connected?
           (let ([rooted (root-coaction source)])
             (equality-law
              'coaction-counit
              (checked-node-basis source)
              (if (formal-sum? rooted)
                  (formal-sum-contract-coordinate
                   rooted 1 forest-counit)
                  rooted)))
           (unavailable-law 'coaction-counit 'not-connected-input)))

     (define-values (zeta-law omega-law)
       (if connected?
           (let* ([ancestry (premise-ancestry-of source)]
                  [degree (derivation-vertex-count source)]
                  [weak (weak-order-map-count ancestry 2 #:limit limit)]
                  [zeta
                   (zeta-convolution-power source 2 #:limit limit)]
                  [linear
                   (linear-extension-count ancestry #:limit limit)]
                  [omega
                   (omega-one-convolution-power
                    source degree #:limit limit)])
             (values
              (equality-law 'zeta-order-map weak zeta)
              (equality-law 'omega-linear-extension linear omega)))
           (values
            (unavailable-law 'zeta-order-map 'not-connected-input)
            (unavailable-law
             'omega-linear-extension 'not-connected-input))))

     (hopf-law-analysis
      source
      (equality-law 'coassociativity coassoc-left coassoc-right)
      (equality-law 'counit-left sum counit-left-value)
      (equality-law 'counit-right sum counit-right-value)
      (equality-law 'antipode-left antipode-target antipode-left-value)
      (equality-law 'antipode-right antipode-target antipode-right-value)
      coaction-coassoc-law
      coaction-counit-law
      zeta-law
      omega-law)]))

(define (make-vertex-table term)
  (for/list ([address (in-list (vertex-addresses term))])
    (define node (vertex-at-address term address))
    (define occurrence (checked-node-occurrence node))
    (define slots
      (for/list ([child (in-list (checked-node-children node))]
                 [slot (in-naturals 1)])
        (premise-slot-analysis
         slot
         (occurrence-premise occurrence slot)
         (append address (list slot))
         (if (checked-hole? child) 'puncture 'vertex))))
    (vertex-analysis
     address
     (concrete-occurrence-id occurrence)
     (concrete-occurrence-tag occurrence)
     (concrete-occurrence-kind occurrence)
     (concrete-occurrence-instance occurrence)
     slots)))

(define (make-cut-table term)
  (for/list ([witness (in-admissible-cut-witnesses term)])
    (cut-analysis
     (cut-witness-addresses witness)
     (cut-witness-detached witness)
     (cut-witness-remainder witness)
     (cut-witness-forest witness)
     (cut-witness-reconstructs? witness))))

(define (sequence-or-result value)
  (if (or (analysis-limit? value) (analysis-error? value))
      value
      (for/list ([item value]) item)))

(define (connected-report-limit term polynomial limit metric)
  (cond
    [(analysis-limit? polynomial) polynomial]
    [else
     (define coproduct-mass
       (+ 2 (polynomial-coefficient-sum polynomial)))
     (define work-bound (connected-work-bound term limit))
     (define required (max coproduct-mass work-bound))
     (and (over-limit? required limit)
          (tool-limit
           'analyze-derivation limit required metric
           (hash 'vertex-count (derivation-vertex-count term)
                 'coproduct-coefficient-mass coproduct-mass
                 'compound-hopf-work-bound work-bound)))]))

(define (analyze-derivation term #:limit [limit analysis-default-limit])
  (unless (checked-node? term)
    (raise-argument-error 'analyze-derivation "checked-node?" term))
  (check-analysis-limit 'analyze-derivation limit)
  (define ancestry (premise-ancestry-of term))
  (define polynomial
    (if (analysis-error? ancestry)
        ancestry
        (cut-size-polynomial ancestry #:limit limit)))
  (define hopf-limit
    (if (or (analysis-limit? polynomial) (analysis-error? polynomial))
        polynomial
        (connected-report-limit
         term polynomial limit 'compound-hopf-work-bound)))
  (define ordinary-count
    (and (vector? polynomial)
         (polynomial-coefficient-sum polynomial)))
  (define witness-limit
    (cond
      [(or (analysis-limit? polynomial) (analysis-error? polynomial))
       polynomial]
      [(over-limit? (add1 ordinary-count) limit)
       (tool-limit
        'analyze-derivation limit (add1 ordinary-count)
        'cut-witness-count)]
      [else #f]))

  (define calculus (checked-node-calculus term))
  (define source-forest (make-proof-forest calculus (list term)))
  (define singleton (forest-basis source-forest))
  (define final-factorization
    (if (complete-proof? term)
        (final-corolla-factorization term)
        (analysis-unavailable
         'incomplete-context
         (hash 'operation 'final-corolla-factorization))))
  (define ideals
    (if (analysis-error? ancestry)
        ancestry
        (sequence-or-result
         (in-ancestry-ideals ancestry #:limit limit))))
  (define orders
    (if (analysis-error? ancestry)
        ancestry
        (sequence-or-result
         (in-root-first-refinement-orders ancestry #:limit limit))))
  (define linear
    (if (analysis-error? ancestry)
        ancestry
        (linear-extension-count ancestry #:limit limit)))
  (define degree (derivation-vertex-count term))

  (derivation-analysis
   term
   (derivation-root-boundary term)
   (complete-proof? term)
   (context-interface-of term)
   degree
   (make-vertex-table term)
   (premise-telescope term)
   (if witness-limit witness-limit (make-cut-table term))
   singleton
   (if hopf-limit hopf-limit (connected-coproduct term))
   (if hopf-limit hopf-limit (reduced-coproduct source-forest))
   (if hopf-limit hopf-limit (root-coaction term))
   degree
   (counit singleton)
   (if hopf-limit hopf-limit (antipode singleton))
   final-factorization
   (cond
     [(not (complete-proof? term))
      (analysis-unavailable
       'incomplete-context
       (hash 'operation 'final-corolla-projection))]
     [hopf-limit hopf-limit]
     [else (final-corolla-projection term)])
   polynomial
   (if (analysis-error? ancestry) ancestry (ancestry-vertices ancestry))
   (if (analysis-error? ancestry) ancestry (ancestry-cover-edges ancestry))
   ideals
   (if (analysis-error? ancestry)
       ancestry
       (nonroot-ancestry-width ancestry))
   (if (analysis-error? ancestry)
       ancestry
       (weak-order-map-count ancestry 2 #:limit limit))
   (zeta-convolution-power term 2 #:limit limit)
   linear
   (omega-one-convolution-power term degree #:limit limit)
   orders
   (if (list? orders) (length orders) orders)
   (check-hopf-laws term #:limit limit)
   limit))

(define (analyze-context context #:limit [limit analysis-default-limit])
  (unless (proof-context? context)
    (raise-argument-error 'analyze-context "proof-context?" context))
  (check-analysis-limit 'analyze-context limit)
  (context-analysis
   context
   (derivation-root-boundary context)
   (context-interface-of context)
   (derivation-vertex-count context)
   (premise-telescope context)
   (if (checked-node? context)
       (analyze-derivation context #:limit limit)
       (analysis-unavailable
        'nodeless-box
        (hash 'message
              "Box is a typed context identity, not a Hopf generator")))))

(define (analyze-forest forest #:limit [limit analysis-default-limit])
  (unless (proof-forest? forest)
    (raise-argument-error 'analyze-forest "proof-forest?" forest))
  (check-analysis-limit 'analyze-forest limit)
  (define basis (forest-basis forest))
  (define preflight
    (formal-coproduct-preflight basis limit 'analyze-forest))
  (define work-preflight
    (if (or (analysis-limit? preflight) (analysis-error? preflight))
        preflight
        (formal-work-preflight basis limit 'analyze-forest)))
  (define unavailable?
    (or (analysis-limit? work-preflight)
        (analysis-error? work-preflight)))
  (forest-analysis
   forest
   (proof-forest-size forest)
   (forest-degree forest)
   basis
   (if unavailable? work-preflight (forest-coproduct forest))
   (if unavailable? work-preflight (reduced-coproduct forest))
   (forest-counit forest)
   (if unavailable? work-preflight (forest-antipode forest))
   (check-hopf-laws forest #:limit limit)
   limit))

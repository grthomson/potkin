#lang racket/base

(require racket/list
         "../algebra/formal-sum.rkt"
         "../kernel/address.rkt"
         "../kernel/check.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt")

(provide connected-coproduct
         forest-coproduct
         coproduct
         reduced-coproduct
         root-coaction
         final-corolla-factorization
         final-corolla-factorization?
         final-corolla-factorization-source
         final-corolla-factorization-occurrence
         final-corolla-factorization-aligned-children
         final-corolla-factorization-premise-forest
         final-corolla-factorization-corolla
         final-corolla-projection
         one-slot-context-insertion
         singleton-cut-coproduct
         forest-counit
         counit
         tensor-counit-left
         tensor-counit-right
         forest-degree
         formal-sum-support-degrees
         formal-sum-homogeneous-degree
         hopf-error?
         hopf-error-code
         hopf-error-message
         hopf-error-operation
         hopf-error-expected
         hopf-error-actual
         hopf-error-details)

(struct hopf-error
  (code message operation expected actual details)
  #:transparent)

;; A complete proof has one exact final occurrence and one immediate child in
;; each of that occurrence's ordered premise slots.  The aligned vector is
;; retained alongside its commutative forest image because the latter cannot
;; recover premise order.
(struct final-corolla-data
  (source occurrence aligned-children premise-forest corolla)
  #:transparent)

(define final-corolla-factorization? final-corolla-data?)
(define final-corolla-factorization-source final-corolla-data-source)
(define final-corolla-factorization-occurrence final-corolla-data-occurrence)
(define final-corolla-factorization-aligned-children
  final-corolla-data-aligned-children)
(define final-corolla-factorization-premise-forest
  final-corolla-data-premise-forest)
(define final-corolla-factorization-corolla final-corolla-data-corolla)

(define (make-hopf-error code message operation
                         #:expected [expected #f]
                         #:actual [actual #f]
                         #:details [details (hash)])
  (hopf-error code message operation expected actual details))

(define (hopf-layer-error? value)
  (or (hopf-error? value) (algebra-error? value)))

(define (rank-error sum expected operation)
  (and (not (= (formal-sum-rank sum) expected))
       (make-hopf-error
        'rank-mismatch
        "the Hopf operation received the wrong formal tensor rank"
        operation
        #:expected expected
        #:actual (formal-sum-rank sum))))

(define (connected-coproduct term)
  (unless (checked-node? term)
    (raise-argument-error 'connected-coproduct "checked-node?" term))
  (define calculus (checked-node-calculus term))
  (define empty-forest (empty-proof-forest calculus))
  (define source-forest (make-proof-forest calculus (list term)))

  ;; This endpoint is not an admissible CK root cut.  The empty witness below
  ;; separately contributes 1 tensor t exactly once.
  (define endpoint
    (pure-tensor calculus (vector source-forest empty-forest)))
  (if (algebra-error? endpoint)
      endpoint
      (let loop ([witnesses
                  (for/list
                      ([witness (in-admissible-cut-witnesses term)])
                    witness)]
                 [result endpoint])
        (cond
          [(null? witnesses) result]
          [else
           (define witness (car witnesses))
           (when (cut-error? witness)
             (error
              'connected-coproduct
              "the admissible-cut enumerator produced an invalid witness: ~e"
              witness))
           (define remainder-forest
             (make-proof-forest
              calculus
              (list (cut-witness-remainder witness))))
           (define witness-term
             (pure-tensor
              calculus
              (vector (cut-witness-forest witness)
                      remainder-forest)))
           (cond
             [(algebra-error? witness-term) witness-term]
             [else
              (define next (formal-sum-add result witness-term))
              (if (algebra-error? next)
                  next
                  (loop (cdr witnesses) next))])]))))

(define (forest-coproduct forest)
  (unless (proof-forest? forest)
    (raise-argument-error 'forest-coproduct "proof-forest?" forest))
  (define calculus (proof-forest-calculus forest))
  (let loop ([factors (proof-forest-factors forest)]
             [result (tensor-unit calculus 2)])
    (cond
      [(hopf-layer-error? result) result]
      [(null? factors) result]
      [else
       ;; proof-forest-factors expands the multiset, so equal occurrences are
       ;; multiplied independently and generate the required coefficients.
       (define factor-coproduct (connected-coproduct (car factors)))
       (cond
         [(hopf-layer-error? factor-coproduct) factor-coproduct]
         [else
          (define next
            (formal-sum-multiply result factor-coproduct))
          (if (hopf-layer-error? next)
              next
              (loop (cdr factors) next))])])))

(define (coproduct sum)
  (unless (formal-sum? sum)
    (raise-argument-error 'coproduct "formal-sum?" sum))
  (define wrong-rank (rank-error sum 1 'coproduct))
  (cond
    [wrong-rank wrong-rank]
    [else
     (define calculus (formal-sum-calculus sum))
     (let loop ([terms (formal-sum-terms sum)]
                [result (tensor-zero calculus 2)])
       (cond
         [(hopf-layer-error? result) result]
         [(null? terms) result]
         [else
          (define term (car terms))
          (define basis-coproduct
            (forest-coproduct (vector-ref (car term) 0)))
          (cond
            [(hopf-layer-error? basis-coproduct) basis-coproduct]
            [else
             (define scaled
               (formal-sum-scale (cdr term) basis-coproduct))
             (cond
               [(hopf-layer-error? scaled) scaled]
               [else
                (define next (formal-sum-add result scaled))
                (if (hopf-layer-error? next)
                    next
                    (loop (cdr terms) next))])])]))]))

;; This is the literal reduced formula used by the connected antipode
;; recursion.  Its natural domain is the augmentation ideal.  We nevertheless
;; preserve the stated formula on every proof forest: on the empty-forest unit
;; it evaluates to -1 tensor 1, rather than being silently changed to zero.
(define (reduced-coproduct forest)
  (unless (proof-forest? forest)
    (raise-argument-error 'reduced-coproduct "proof-forest?" forest))
  (define calculus (proof-forest-calculus forest))
  (define empty-forest (empty-proof-forest calculus))
  (define delta (forest-coproduct forest))
  (cond
    [(hopf-layer-error? delta) delta]
    [else
     (define left-endpoint
       (pure-tensor calculus (vector forest empty-forest)))
     (cond
       [(hopf-layer-error? left-endpoint) left-endpoint]
       [else
        (define right-endpoint
          (pure-tensor calculus (vector empty-forest forest)))
        (cond
          [(hopf-layer-error? right-endpoint) right-endpoint]
          [else
           (define without-left-endpoint
             (formal-sum-subtract delta left-endpoint))
           (if (hopf-layer-error? without-left-endpoint)
               without-left-endpoint
               (formal-sum-subtract
                without-left-endpoint
                right-endpoint))])])]))

(define (singleton-forest/internal term)
  (make-proof-forest (checked-term-calculus term) (list term)))

(define (root-coaction term)
  (unless (checked-node? term)
    (raise-argument-error 'root-coaction "checked-node?" term))
  (define calculus (checked-node-calculus term))
  (define source-root (derivation-root-boundary term))
  (define source-forest (singleton-forest/internal term))
  (define empty-forest (empty-proof-forest calculus))
  (define delta (connected-coproduct term))
  (cond
    [(hopf-layer-error? delta) delta]
    [else
     ;; Remove only the separately adjoined whole-tree endpoint.  The empty
     ;; cut remains and contributes 1 tensor term.
     (define endpoint
       (pure-tensor calculus (vector source-forest empty-forest)))
     (cond
       [(hopf-layer-error? endpoint) endpoint]
       [else
        (define coaction (formal-sum-subtract delta endpoint))
        (cond
          [(hopf-layer-error? coaction) coaction]
          [else
           (define bad-right-coordinate
             (for/first
                 ([entry (in-list (formal-sum-terms coaction))]
                  #:do
                  [(define right-forest (vector-ref (car entry) 1))
                   (define factors (proof-forest-factors right-forest))]
                  #:unless
                  (and (= (length factors) 1)
                       (checked-node? (car factors))
                       (checked-term-has-exact-calculus?
                        (car factors) calculus)
                       (equal? (derivation-root-boundary (car factors))
                               source-root)))
               right-forest))
           (if bad-right-coordinate
               (make-hopf-error
                'root-coaction-invariant
                "a root coaction right coordinate was not a singleton retained context of the source root"
                'root-coaction
                #:expected (list 'singleton-connected-root source-root)
                #:actual bad-right-coordinate
                #:details (hash 'source term))
               coaction)])])]))

(define (final-corolla-factorization term)
  (unless (checked-node? term)
    (raise-argument-error
     'final-corolla-factorization "checked-node?" term))
  (define operation 'final-corolla-factorization)
  (cond
    [(not (complete-proof? term))
     (make-hopf-error
      'incomplete-source
      "final-corolla factorization requires a complete connected proof"
      operation
      #:expected 'complete-rule-rooted-proof
      #:actual term)]
    [else
     (define calculus (checked-node-calculus term))
     (define occurrence (checked-node-occurrence term))
     (define children (checked-node-children term))
     (define full-premise-corolla (corolla calculus occurrence))
     (cond
       [(context-error? full-premise-corolla)
        (make-hopf-error
         'final-corolla-invariant
         "constructing the admitted final corolla unexpectedly failed"
         operation
         #:expected occurrence
         #:actual full-premise-corolla
         #:details (hash 'source term))]
       [else
        (define premise-forest (make-proof-forest calculus children))
        (define recomposed
          (context-compose full-premise-corolla children))
        (cond
          [(or (context-error? recomposed)
               (not (equal? recomposed term))
               (not (checked-term-has-exact-calculus?
                     recomposed calculus)))
           (make-hopf-error
            'final-corolla-recomposition-invariant
            "the ordered immediate premises did not recompose their source proof"
            operation
            #:expected term
            #:actual recomposed
            #:details
            (hash 'corolla full-premise-corolla
                  'aligned-children children))]
          [else
           (final-corolla-data
            term
            occurrence
            (vector->immutable-vector (list->vector children))
            premise-forest
            full-premise-corolla)])])]))

(define (one-vertex-connected-projection calculus forest)
  (define factors (proof-forest-factors forest))
  (if (and (= (length factors) 1)
           (= (derivation-vertex-count (car factors)) 1))
      (forest-basis forest)
      (formal-zero calculus)))

(define (final-corolla-projection term)
  (unless (checked-node? term)
    (raise-argument-error 'final-corolla-projection "checked-node?" term))
  (define operation 'final-corolla-projection)
  (define factorization (final-corolla-factorization term))
  (cond
    [(hopf-error? factorization) factorization]
    [else
     (define calculus (checked-node-calculus term))
     (define delta (connected-coproduct term))
     (cond
       [(hopf-layer-error? delta) delta]
       [else
        (define projection
          (formal-sum-expand-coordinate
           delta
           2
           1
           (lambda (forest)
             (one-vertex-connected-projection calculus forest))))
        (cond
          [(hopf-layer-error? projection) projection]
          [else
           (define corolla-forest
             (singleton-forest/internal
              (final-corolla-factorization-corolla factorization)))
           (define expected
             (pure-tensor
              calculus
              (vector
               (final-corolla-factorization-premise-forest factorization)
               corolla-forest)))
           (cond
             [(hopf-layer-error? expected) expected]
             [(not (equal? projection expected))
              (make-hopf-error
               'final-corolla-projection-invariant
               "the one-vertex right projection did not isolate the final corolla"
               operation
               #:expected expected
               #:actual projection
               #:details (hash 'source term))]
             [else projection])])])]))

(define (one-slot-context-insertion inner outer)
  (unless (checked-node? inner)
    (raise-argument-error
     'one-slot-context-insertion "checked-node?" inner))
  (unless (checked-node? outer)
    (raise-argument-error
     'one-slot-context-insertion "checked-node?" outer))
  (define operation 'one-slot-context-insertion)
  (define calculus (checked-node-calculus inner))
  (cond
    [(or (not (eq? calculus (checked-node-calculus outer)))
         (not (checked-term-has-exact-calculus? inner calculus))
         (not (checked-term-has-exact-calculus? outer calculus)))
     (make-hopf-error
      'calculus-mismatch
      "one-slot insertion requires exact common calculus provenance"
      operation
      #:expected calculus
      #:actual (checked-node-calculus outer)
      #:details (hash 'inner inner 'outer outer))]
    [else
     (define inner-root (derivation-root-boundary inner))
     (let loop ([entries (premise-telescope outer)]
                [result (formal-zero calculus)])
       (cond
         [(hopf-layer-error? result) result]
         [(null? entries) result]
         [else
          (define entry (car entries))
          (cond
            [(not (equal? inner-root
                          (telescope-entry-requirement entry)))
             (loop (cdr entries) result)]
            [else
             (define inserted
               (context-insert
                outer
                (telescope-entry-address entry)
                inner))
             (cond
               [(context-error? inserted)
                (make-hopf-error
                 'one-slot-insertion-invariant
                 "an exactly typed telescope insertion unexpectedly failed"
                 operation
                 #:expected (telescope-entry-requirement entry)
                 #:actual inserted
                 #:details
                 (hash 'address (telescope-entry-address entry)
                       'inner inner
                       'outer outer))]
               [else
                (define next
                  (formal-sum-add result (checked-node-basis inserted)))
                (if (hopf-layer-error? next)
                    next
                    (loop (cdr entries) next))])])]))]))

(define (singleton-cut-coproduct term)
  (unless (checked-node? term)
    (raise-argument-error 'singleton-cut-coproduct "checked-node?" term))
  (define operation 'singleton-cut-coproduct)
  (define calculus (checked-node-calculus term))
  (let loop ([addresses
              (filter (lambda (address) (not (null? address)))
                      (vertex-addresses term))]
             [result (tensor-zero calculus 2)])
    (cond
      [(hopf-layer-error? result) result]
      [(null? addresses) result]
      [else
       (define witness (make-cut-witness term (list (car addresses))))
       (cond
         [(cut-error? witness)
          (make-hopf-error
           'singleton-cut-invariant
           "a nonroot vertex address unexpectedly failed singleton cutting"
           operation
           #:expected 'admissible-singleton-cut
           #:actual witness
           #:details (hash 'source term 'address (car addresses)))]
         [else
          (define remainder-forest
            (singleton-forest/internal (cut-witness-remainder witness)))
          (define summand
            (pure-tensor
             calculus
             (vector (cut-witness-forest witness) remainder-forest)))
          (cond
            [(hopf-layer-error? summand) summand]
            [else
             (define next (formal-sum-add result summand))
             (if (hopf-layer-error? next)
                 next
                 (loop (cdr addresses) next))])])])))

(define (forest-counit forest)
  (unless (proof-forest? forest)
    (raise-argument-error 'forest-counit "proof-forest?" forest))
  (if (proof-forest-empty? forest) 1 0))

(define (counit sum)
  (unless (formal-sum? sum)
    (raise-argument-error 'counit "formal-sum?" sum))
  (define wrong-rank (rank-error sum 1 'counit))
  (if wrong-rank
      wrong-rank
      (forest-coefficient
       sum
       (empty-proof-forest (formal-sum-calculus sum)))))

(define (tensor-counit-left sum)
  (unless (formal-sum? sum)
    (raise-argument-error 'tensor-counit-left "formal-sum?" sum))
  (define wrong-rank (rank-error sum 2 'tensor-counit-left))
  (if wrong-rank
      wrong-rank
      (formal-sum-contract-coordinate sum 1 forest-counit)))

(define (tensor-counit-right sum)
  (unless (formal-sum? sum)
    (raise-argument-error 'tensor-counit-right "formal-sum?" sum))
  (define wrong-rank (rank-error sum 2 'tensor-counit-right))
  (if wrong-rank
      wrong-rank
      (formal-sum-contract-coordinate sum 2 forest-counit)))

(define (forest-degree forest)
  (unless (proof-forest? forest)
    (raise-argument-error 'forest-degree "proof-forest?" forest))
  (for/sum ([factor (in-list (proof-forest-factors forest))])
    (derivation-vertex-count factor)))

(define (support-degrees/internal sum)
  (remove-duplicates
   (sort
    (for/list ([key (in-list (formal-sum-support sum))])
      (forest-degree (vector-ref key 0)))
    <)))

(define (formal-sum-support-degrees sum)
  (unless (formal-sum? sum)
    (raise-argument-error
     'formal-sum-support-degrees "formal-sum?" sum))
  (define wrong-rank
    (rank-error sum 1 'formal-sum-support-degrees))
  (if wrong-rank wrong-rank (support-degrees/internal sum)))

(define (formal-sum-homogeneous-degree sum)
  (unless (formal-sum? sum)
    (raise-argument-error
     'formal-sum-homogeneous-degree "formal-sum?" sum))
  (define wrong-rank
    (rank-error sum 1 'formal-sum-homogeneous-degree))
  (cond
    [wrong-rank wrong-rank]
    [else
     (define degrees (support-degrees/internal sum))
     (cond
       [(null? degrees)
        (make-hopf-error
         'empty-support
         "formal zero has no homogeneous support degree"
         'formal-sum-homogeneous-degree
         #:expected 'nonempty-support
         #:actual '())]
       [(null? (cdr degrees)) (car degrees)]
       [else
        (make-hopf-error
         'nonhomogeneous
         "the formal sum has support in more than one degree"
         'formal-sum-homogeneous-degree
         #:expected 'single-degree
         #:actual degrees
         #:details (hash 'degrees degrees))])]))

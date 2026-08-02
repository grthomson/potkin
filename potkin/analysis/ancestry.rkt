#lang racket/base

(require racket/generator
         racket/list
         racket/vector
         "../kernel/address.rkt"
         "../kernel/check.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt")

(provide analysis-default-limit
         (struct-out analysis-error)
         (struct-out analysis-limit)
         premise-ancestry?
         premise-ancestry-source
         make-premise-ancestry
         premise-ancestry-of
         ancestry-vertices
         ancestry-cover-edges
         ancestry-immediate-children
         ancestry<=?
         ancestry-ideal?
         (struct-out empty-cut-choice)
         proper-cut-choice
         proper-cut-choice?
         proper-cut-choice-addresses
         (struct-out whole-cut-choice)
         cut-choice?
         cut-choice->ideal
         ancestry-ideal->cut-choice
         in-ancestry-ideals
         cut-size-polynomial
         cut-size-polynomial-evaluate
         nonroot-ancestry-width
         in-root-first-refinement-orders
         refinement-order-reconstructs?)

(define analysis-default-limit 10000)

(struct analysis-error
  (code message operation expected actual details)
  #:transparent)

(struct analysis-limit
  (code message operation limit required metric details)
  #:transparent)

(define (limit-value operation limit required metric [details (hash)])
  (analysis-limit
   'not-computed-limit
   "the exact analysis exceeds its configured finite limit"
   operation limit required metric details))

(define (check-limit who limit)
  (unless (or (not limit) (exact-nonnegative-integer? limit))
    (raise-argument-error who "(or/c #f exact-nonnegative-integer?)" limit)))

(define (over-limit? value limit)
  (and limit (> value limit)))

(define (cap-add left right limit)
  (define value (+ left right))
  (if (over-limit? value limit) (add1 limit) value))

(define (cap-multiply left right limit)
  (cond
    [(or (zero? left) (zero? right)) 0]
    [(not limit) (* left right)]
    [(> left (quotient limit right)) (add1 limit)]
    [else (* left right)]))

;; Addresses, rather than occurrence data, are the identities of vertices in
;; this presentation poset.  The exact calculus is retained operationally.
(struct premise-ancestry (source vertices cover-edges child-table)
  #:constructor-name make-premise-ancestry/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (premise-ancestry? right)
          (eq? (checked-term-calculus (premise-ancestry-source left))
               (checked-term-calculus (premise-ancestry-source right)))
          (recur (premise-ancestry-source left)
                 (premise-ancestry-source right))
          (recur (premise-ancestry-vertices left)
                 (premise-ancestry-vertices right))
          (recur (premise-ancestry-cover-edges left)
                 (premise-ancestry-cover-edges right))))
   (lambda (value recur)
     (bitwise-xor
      (eq-hash-code
       (checked-term-calculus (premise-ancestry-source value)))
      (recur (list (premise-ancestry-source value)
                   (premise-ancestry-vertices value)
                   (premise-ancestry-cover-edges value)))))
   (lambda (value recur)
     (bitwise-xor
      #x2d2816fe
      (eq-hash-code
       (checked-term-calculus (premise-ancestry-source value)))
      (recur (list (premise-ancestry-cover-edges value)
                   (premise-ancestry-vertices value)
                   (premise-ancestry-source value)))))))

(define (premise-ancestry-of source)
  (unless (checked-node? source)
    (raise-argument-error 'premise-ancestry-of "checked-node?" source))
  (define calculus (checked-term-calculus source))
  (cond
    [(not (checked-term-has-exact-calculus? source calculus))
     (analysis-error
      'mixed-calculus-provenance
      "premise ancestry requires one exact calculus snapshot throughout"
      'premise-ancestry-of calculus (checked-term-calculus source)
      (hash 'source source))]
    [else
     (define vertices (sort (vertex-addresses source) address<?))
     (define cover-edges
       (for/list ([child (in-list (cdr vertices))])
         (list child (drop-right child 1))))
     (define child-table
       (for/fold ([table
                   (for/hash ([vertex (in-list vertices)])
                     (values vertex '()))])
                 ([edge (in-list cover-edges)])
         (hash-update table (second edge)
                      (lambda (children)
                        (sort (cons (first edge) children) address<?))
                      '())))
     (make-premise-ancestry/internal
      source vertices cover-edges child-table)]))

(define make-premise-ancestry premise-ancestry-of)

(define (ancestry-vertices ancestry)
  (unless (premise-ancestry? ancestry)
    (raise-argument-error 'ancestry-vertices "premise-ancestry?" ancestry))
  (premise-ancestry-vertices ancestry))

(define (ancestry-cover-edges ancestry)
  (unless (premise-ancestry? ancestry)
    (raise-argument-error
     'ancestry-cover-edges "premise-ancestry?" ancestry))
  (premise-ancestry-cover-edges ancestry))

(define (ancestry-immediate-children ancestry address)
  (unless (premise-ancestry? ancestry)
    (raise-argument-error
     'ancestry-immediate-children "premise-ancestry?" ancestry))
  (unless (address? address)
    (raise-argument-error 'ancestry-immediate-children "address?" address))
  (hash-ref (premise-ancestry-child-table ancestry) address '()))

;; Paper orientation: descendant <= ancestor.
(define (ancestry<=? ancestry lower upper)
  (unless (premise-ancestry? ancestry)
    (raise-argument-error 'ancestry<=? "premise-ancestry?" ancestry))
  (unless (address? lower)
    (raise-argument-error 'ancestry<=? "address?" lower))
  (unless (address? upper)
    (raise-argument-error 'ancestry<=? "address?" upper))
  (define vertices (premise-ancestry-vertices ancestry))
  (and (member lower vertices equal?)
       (member upper vertices equal?)
       (address-prefix? upper lower)
       #t))

(define (canonical-address-set value)
  (and (list? value)
       (andmap address? value)
       (not (check-duplicates value equal?))
       (sort value address<?)))

(define (ancestry-ideal? ancestry candidate)
  (unless (premise-ancestry? ancestry)
    (raise-argument-error 'ancestry-ideal? "premise-ancestry?" ancestry))
  (define canonical (canonical-address-set candidate))
  (and canonical
       (andmap (lambda (address)
                 (member address (premise-ancestry-vertices ancestry) equal?))
               canonical)
       ;; Downward closure may be checked on covers: including a parent forces
       ;; every immediate rule-child, and hence recursively every descendant.
       (for/and ([edge (in-list (premise-ancestry-cover-edges ancestry))])
         (or (not (member (second edge) canonical equal?))
             (member (first edge) canonical equal?)))
       #t))

(struct empty-cut-choice () #:transparent)
(struct whole-cut-choice () #:transparent)
(struct proper-cut-choice-value (addresses) #:transparent)

(define proper-cut-choice? proper-cut-choice-value?)
(define proper-cut-choice-addresses proper-cut-choice-value-addresses)

(define (prefix-free? addresses)
  (for*/and ([left (in-list addresses)]
             [right (in-list addresses)]
             #:unless (equal? left right))
    (not (proper-address-prefix? left right))))

(define (proper-cut-choice addresses)
  (unless (and (list? addresses) (pair? addresses) (andmap address? addresses))
    (raise-argument-error
     'proper-cut-choice "nonempty (listof address?)" addresses))
  (when (member root-address addresses equal?)
    (raise-arguments-error
     'proper-cut-choice "a proper choice cannot contain the root"
     "addresses" addresses))
  (when (check-duplicates addresses equal?)
    (raise-arguments-error
     'proper-cut-choice "a proper choice cannot repeat an address"
     "addresses" addresses))
  (define canonical (sort addresses address<?))
  (unless (prefix-free? canonical)
    (raise-arguments-error
     'proper-cut-choice "a proper choice must be prefix-free"
     "addresses" addresses))
  (proper-cut-choice-value canonical))

(define (cut-choice? value)
  (or (empty-cut-choice? value)
      (proper-cut-choice? value)
      (whole-cut-choice? value)))

(define (cut-choice->ideal ancestry choice)
  (unless (premise-ancestry? ancestry)
    (raise-argument-error 'cut-choice->ideal "premise-ancestry?" ancestry))
  (unless (cut-choice? choice)
    (raise-argument-error 'cut-choice->ideal "cut-choice?" choice))
  (cond
    [(empty-cut-choice? choice) '()]
    [(whole-cut-choice? choice) (premise-ancestry-vertices ancestry)]
    [else
     (define addresses (proper-cut-choice-addresses choice))
     (define validation
       (validate-ck-cut (premise-ancestry-source ancestry) addresses))
     (cond
       [(cut-error? validation)
        (analysis-error
         'invalid-proper-cut-choice
         "the proper choice is not an ordinary CK cut of this source"
         'cut-choice->ideal 'admissible-nonempty-nonroot-cut validation
         (hash 'choice choice 'source (premise-ancestry-source ancestry)))]
       [else
        (for/list ([vertex (in-list (premise-ancestry-vertices ancestry))]
                   #:when
                   (for/or ([cut-root (in-list validation)])
                     (ancestry<=? ancestry vertex cut-root)))
          vertex)])]))

(define (ancestry-ideal->cut-choice ancestry ideal)
  (unless (premise-ancestry? ancestry)
    (raise-argument-error
     'ancestry-ideal->cut-choice "premise-ancestry?" ancestry))
  (cond
    [(not (ancestry-ideal? ancestry ideal))
     (analysis-error
      'invalid-ancestry-ideal
      "the supplied vertex set is not a downward ancestry ideal"
      'ancestry-ideal->cut-choice 'downward-address-set ideal
      (hash 'source (premise-ancestry-source ancestry)))]
    [else
     (define canonical (sort ideal address<?))
     (cond
       [(null? canonical) (empty-cut-choice)]
       [(equal? canonical (premise-ancestry-vertices ancestry))
        (whole-cut-choice)]
       [else
        (define maximal
          (for/list ([vertex (in-list canonical)]
                     #:unless
                     (for/or ([other (in-list canonical)])
                       (and (not (equal? vertex other))
                            (ancestry<=? ancestry vertex other))))
            vertex))
        (proper-cut-choice maximal)])]))

(define (in-ancestry-ideals ancestry #:limit [limit analysis-default-limit])
  (unless (premise-ancestry? ancestry)
    (raise-argument-error
     'in-ancestry-ideals "premise-ancestry?" ancestry))
  (check-limit 'in-ancestry-ideals limit)
  ;; For a rooted tree, an ideal either contains its root (and is total), or
  ;; omits it and independently chooses an ideal in every rule-child subtree.
  ;; Saturating this recurrence gives a true preflight before cut enumeration.
  (define (ideal-count address)
    (cap-add
     1
     (for/fold ([product 1])
               ([child
                 (in-list
                  (ancestry-immediate-children ancestry address))])
       (cap-multiply product (ideal-count child) limit))
     limit))
  (define count (ideal-count root-address))
  (cond
    [(over-limit? count limit)
     (limit-value 'in-ancestry-ideals limit (add1 limit) 'ideal-count)]
    [else
     ;; Materialise only after the exact saturated count is within budget: a
     ;; caller can never consume a partial enumeration before seeing a limit.
     (define ordinary-ideals
       (for/list
           ([addresses
             (in-admissible-cuts (premise-ancestry-source ancestry))])
         (cut-choice->ideal
          ancestry
          (if (null? addresses)
              (empty-cut-choice)
              (proper-cut-choice addresses)))))
     (define internal-error (findf analysis-error? ordinary-ideals))
     (if internal-error
         internal-error
         (in-list
          (append ordinary-ideals
                  (list (premise-ancestry-vertices ancestry)))))]))

;; Immutable coefficient vectors: coordinate k is the coefficient of q^k.
(define (poly-trim coefficients)
  (define mutable (if (vector? coefficients)
                      (vector-copy coefficients)
                      (list->vector coefficients)))
  (let loop ([length (vector-length mutable)])
    (cond
      [(<= length 1)
       (vector->immutable-vector (vector-copy mutable 0 1))]
      [(zero? (vector-ref mutable (sub1 length))) (loop (sub1 length))]
      [else (vector->immutable-vector (vector-copy mutable 0 length))])))

(define (poly-multiply left right limit)
  (define result
    (make-vector (sub1 (+ (vector-length left) (vector-length right))) 0))
  (for* ([i (in-range (vector-length left))]
         [j (in-range (vector-length right))])
    (define old (vector-ref result (+ i j)))
    (define product
      (cap-multiply (vector-ref left i) (vector-ref right j) limit))
    (vector-set! result (+ i j) (cap-add old product limit)))
  (poly-trim result))

(define (subtree-antichain-polynomial ancestry address limit memo)
  (hash-ref!
   memo address
   (lambda ()
     (define child-product
       (for/fold ([product (vector-immutable 1)])
                 ([child
                   (in-list
                    (ancestry-immediate-children ancestry address))])
         (poly-multiply
          product
          (subtree-antichain-polynomial ancestry child limit memo)
          limit)))
     (define length (max 2 (vector-length child-product)))
     (define with-node (make-vector length 0))
     (for ([index (in-range (vector-length child-product))])
       (vector-set! with-node index (vector-ref child-product index)))
     (vector-set!
      with-node 1
      (cap-add (vector-ref with-node 1) 1 limit))
     (poly-trim with-node))))

(define (cut-size-polynomial ancestry #:limit [limit analysis-default-limit])
  (unless (premise-ancestry? ancestry)
    (raise-argument-error
     'cut-size-polynomial "premise-ancestry?" ancestry))
  (check-limit 'cut-size-polynomial limit)
  (define memo (make-hash))
  (define nonroot-antichains
    (for/fold ([product (vector-immutable 1)])
              ([child
                (in-list
                 (ancestry-immediate-children ancestry root-address))])
      (poly-multiply
       product
       (subtree-antichain-polynomial ancestry child limit memo)
       limit)))
  (define result (vector-copy nonroot-antichains))
  (vector-set! result 0 (sub1 (vector-ref result 0)))
  (define exact-result (poly-trim result))
  (define cut-count
    (for/fold ([count 0]) ([coefficient (in-vector exact-result)])
      (cap-add count coefficient limit)))
  (if (over-limit? cut-count limit)
      (limit-value
       'cut-size-polynomial limit (add1 limit) 'ordinary-cut-count)
      exact-result))

(define (cut-size-polynomial-evaluate polynomial q)
  (unless (and (vector? polynomial)
               (positive? (vector-length polynomial))
               (for/and ([coefficient (in-vector polynomial)])
                 (exact-nonnegative-integer? coefficient)))
    (raise-argument-error
     'cut-size-polynomial-evaluate
     "nonempty vector of exact nonnegative coefficients"
     polynomial))
  (unless (number? q)
    (raise-argument-error 'cut-size-polynomial-evaluate "number?" q))
  (for/fold ([value 0])
            ([coefficient (in-list (reverse (vector->list polynomial)))])
    (+ coefficient (* q value))))

(define (subtree-width ancestry address)
  (define children (ancestry-immediate-children ancestry address))
  (if (null? children)
      1
      (for/sum ([child (in-list children)])
        (subtree-width ancestry child))))

(define (nonroot-ancestry-width ancestry)
  (unless (premise-ancestry? ancestry)
    (raise-argument-error
     'nonroot-ancestry-width "premise-ancestry?" ancestry))
  (for/sum
      ([child
        (in-list
         (ancestry-immediate-children ancestry root-address))])
    (subtree-width ancestry child)))

(define (binomial/capped n k limit)
  (define small-k (min k (- n k)))
  (let loop ([i 1] [result 1])
    (cond
      [(> i small-k) result]
      [else
       (define next
         (quotient (* result (+ (- n small-k) i)) i))
       (if (over-limit? next limit)
           (add1 limit)
           (loop (add1 i) next))])))

(define (linear-extension-count/capped ancestry address limit memo)
  (hash-ref!
   memo address
   (lambda ()
     (define-values (children-size children-count)
       (for/fold ([size 0] [count 1])
                 ([child
                   (in-list
                    (ancestry-immediate-children ancestry address))])
         (define child-answer
           (linear-extension-count/capped ancestry child limit memo))
         (define child-size (car child-answer))
         (define child-count (cdr child-answer))
         (define shuffle
           (binomial/capped (+ size child-size) child-size limit))
         (values (+ size child-size)
                 (cap-multiply
                  (cap-multiply count child-count limit)
                  shuffle limit))))
     (cons (add1 children-size) children-count))))

(define (root-first-order-count ancestry limit)
  (cdr
   (linear-extension-count/capped
    ancestry root-address limit (make-hash))))

(define (in-root-first-refinement-orders
         ancestry #:limit [limit analysis-default-limit])
  (unless (premise-ancestry? ancestry)
    (raise-argument-error
     'in-root-first-refinement-orders "premise-ancestry?" ancestry))
  (check-limit 'in-root-first-refinement-orders limit)
  (define vertex-count (length (premise-ancestry-vertices ancestry)))
  (cond
    [(over-limit? vertex-count limit)
     (limit-value
      'in-root-first-refinement-orders limit vertex-count 'vertex-count)]
    [else
     (define count (root-first-order-count ancestry limit))
     (if (over-limit? count limit)
         (limit-value
          'in-root-first-refinement-orders limit (add1 limit)
          'refinement-order-count)
         (in-generator
          (define (walk frontier reversed-order)
            (cond
              [(null? frontier) (yield (reverse reversed-order))]
              [else
               (for ([selected (in-list (sort frontier address<?))])
                 (define remaining (remove selected frontier equal?))
                 (define exposed
                   (ancestry-immediate-children ancestry selected))
                 (walk (append remaining exposed)
                       (cons selected reversed-order)))]))
          (walk (list root-address) '()))) ]))

(define (refinement-order-reconstructs? ancestry order)
  (unless (premise-ancestry? ancestry)
    (raise-argument-error
     'refinement-order-reconstructs? "premise-ancestry?" ancestry))
  (unless (list? order)
    (raise-argument-error
     'refinement-order-reconstructs? "list?" order))
  (define target (premise-ancestry-source ancestry))
  (define vertices (premise-ancestry-vertices ancestry))
  (and (andmap address? order)
       (not (check-duplicates order equal?))
       (= (length order) (length vertices))
       (andmap (lambda (address) (member address vertices equal?)) order)
       (let loop ([current
                   (identity-context
                    (checked-term-calculus target)
                    (derivation-root-boundary target))]
                  [remaining order])
         (cond
           [(null? remaining)
            (and (checked-term? current)
                 (checked-term-has-exact-calculus?
                  current (checked-term-calculus target))
                 (equal? current target))]
           [else
            (define address (car remaining))
            (define target-node (vertex-at-address target address))
            (define selected (checked-term-at-address current address))
            (and target-node
                 (checked-hole? selected)
                 (let ([one-corolla
                        (corolla
                         (checked-term-calculus target)
                         (checked-node-occurrence target-node))])
                   (and (checked-term? one-corolla)
                        (let ([next
                               (context-insert current address one-corolla)])
                          (and (checked-term? next)
                               (loop next (cdr remaining)))))))]))))

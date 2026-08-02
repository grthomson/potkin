#lang racket/base

(require racket/list
         "../algebra/formal-sum.rkt"
         "../kernel/check.rkt"
         "../kernel/cut.rkt"
         "../hopf/ck.rkt"
         "ancestry.rkt")

(provide iterated-coproduct
         zeta-convolution-power
         omega-one-convolution-power
         weak-order-map-count
         linear-extension-count)

;; The public analyses in this module deliberately have two implementations:
;; convolution powers use the collected CK coproduct, while the comparison
;; counts below use only the rooted premise-ancestry poset.  In particular,
;; the latter do not infer identities from the unspecified order in which a
;; commutative proof forest happens to expose equal factors.

(define (check-limit who limit)
  (unless (or (not limit) (exact-nonnegative-integer? limit))
    (raise-argument-error
     who "(or/c #f exact-nonnegative-integer?)" limit)))

(define (check-positive-power who power)
  (unless (exact-positive-integer? power)
    (raise-argument-error who "exact-positive-integer?" power)))

(define (over-limit? value limit)
  (and limit (> value limit)))

;; A capped value is used only to decide that an exact answer is too large to
;; compute under the caller's budget.  It is never returned as that answer.
(define (cap-add left right limit)
  (define result (+ left right))
  (if (over-limit? result limit) (add1 limit) result))

(define (cap-multiply left right limit)
  (cond
    [(or (zero? left) (zero? right)) 0]
    [(not limit) (* left right)]
    [(or (> left limit) (> right limit)) (add1 limit)]
    [(> left (quotient limit right)) (add1 limit)]
    [else (* left right)]))

(define (not-computed operation limit required metric
                      [details (hash)])
  (analysis-limit
   'not-computed-limit
   "the exact analysis exceeds its configured finite limit"
   operation limit required metric details))

(define (invalid-basis operation code message expected actual
                       [details (hash)])
  (analysis-error code message operation expected actual details))

(struct normalized-basis (node sum ancestry) #:transparent)

;; Iterated CK convolution is intentionally restricted to a connected basis
;; term.  Linearity can be requested later without conflating a forest's
;; commutative factor enumeration with semantic occurrence identities.
(define (normalize-connected-basis source operation)
  (cond
    [(checked-node? source)
     (define ancestry (premise-ancestry-of source))
     (if (analysis-error? ancestry)
         ancestry
         (normalized-basis source (checked-node-basis source) ancestry))]
    [(formal-sum? source)
     (cond
       [(not (= (formal-sum-rank source) 1))
        (invalid-basis
         operation
         'rank-mismatch
         "the analysis requires a rank-one connected basis value"
         1
         (formal-sum-rank source))]
       [(not (= (formal-sum-support-size source) 1))
        (invalid-basis
         operation
         'not-singleton-connected-basis
         "the analysis requires exactly one coefficient-one connected basis term"
         'coefficient-one-singleton-connected-basis
         source
         (hash 'support-size (formal-sum-support-size source)))]
       [else
        (define entry (car (formal-sum-terms source)))
        (define key (car entry))
        (define coefficient (cdr entry))
        (define forest (vector-ref key 0))
        (define factors (proof-forest-factors forest))
        (cond
          [(or (not (= coefficient 1))
               (not (= (length factors) 1))
               (not (checked-node? (car factors))))
           (invalid-basis
            operation
            'not-singleton-connected-basis
            "the analysis requires exactly one coefficient-one connected basis term"
            'coefficient-one-singleton-connected-basis
            source
            (hash 'coefficient coefficient
                  'factor-count (length factors)))]
          [else
           (define node (car factors))
           (define ancestry (premise-ancestry-of node))
           (if (analysis-error? ancestry)
               ancestry
               (normalized-basis node source ancestry))])])]
    [else
     (raise-argument-error
      operation "(or/c checked-node? formal-sum?)" source)]))

(define (normalize-ancestry source operation)
  (cond
    [(premise-ancestry? source) source]
    [(checked-node? source) (premise-ancestry-of source)]
    [else
     (raise-argument-error
      operation "(or/c premise-ancestry? checked-node?)" source)]))

;; For descendant <= ancestor, fixing a vertex's label k permits every child
;; subtree to use labels at most k.  Each table therefore stores prefix sums:
;; coordinate k counts subtree maps into [k].
(define (weak-order-map-count/internal ancestry codomain-size limit operation)
  (define vertex-count (length (ancestry-vertices ancestry)))
  (define state-count (* vertex-count (add1 codomain-size)))
  (cond
    [(over-limit? vertex-count limit)
     (not-computed
      operation limit vertex-count 'vertex-count
      (hash 'codomain-size codomain-size))]
    [(over-limit? state-count limit)
     (not-computed
      operation limit state-count 'dynamic-program-states
      (hash 'vertex-count vertex-count
            'codomain-size codomain-size))]
    ;; Constant maps already supply this lower bound, so this is a genuine
    ;; preflight and avoids looping through an enormous codomain.
    [(over-limit? codomain-size limit)
     (not-computed
      operation limit codomain-size 'weak-order-map-count
      (hash 'vertex-count vertex-count
            'codomain-size codomain-size))]
    [else
     (define memo (make-hash))
     (define (subtree-prefix-table address)
       (hash-ref!
        memo address
        (lambda ()
          (define child-tables
            (for/list
                ([child
                  (in-list
                   (ancestry-immediate-children ancestry address))])
              (subtree-prefix-table child)))
          (define table (make-vector (add1 codomain-size) 0))
          (for ([label (in-range 1 (add1 codomain-size))])
            (define exact-label-count
              (for/fold ([product 1])
                        ([child-table (in-list child-tables)])
                (cap-multiply
                 product (vector-ref child-table label) limit)))
            (vector-set!
             table label
             (cap-add
              (vector-ref table (sub1 label))
              exact-label-count
              limit)))
          table)))
     (define count
       (vector-ref
        (subtree-prefix-table '())
        codomain-size))
     (if (over-limit? count limit)
         (not-computed
          operation limit (add1 limit) 'weak-order-map-count
          (hash 'vertex-count vertex-count
                'codomain-size codomain-size))
         count)]))

(define (weak-order-map-count
         source codomain-size #:limit [limit analysis-default-limit])
  (check-positive-power 'weak-order-map-count codomain-size)
  (check-limit 'weak-order-map-count limit)
  (define ancestry
    (normalize-ancestry source 'weak-order-map-count))
  (if (analysis-error? ancestry)
      ancestry
      (weak-order-map-count/internal
       ancestry codomain-size limit 'weak-order-map-count)))

;; This variant never constructs an enormous binomial coefficient merely to
;; discover that it exceeds the budget.  Successive binomial values are
;; monotone, so saturation after each exact recurrence step is sound.
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

(define (linear-extension-count/internal ancestry limit operation)
  (define vertex-count (length (ancestry-vertices ancestry)))
  (cond
    [(over-limit? vertex-count limit)
     (not-computed
      operation limit vertex-count 'vertex-count
      (hash 'orientation 'descendant<=ancestor))]
    [else
     (define memo (make-hash))
     ;; The root of each subtree is last.  Independently ordered child
     ;; subtrees may be shuffled in a multinomial number of ways.
     (define (subtree-result address)
       (hash-ref!
        memo address
        (lambda ()
          (define-values (children-size children-count)
            (for/fold
                ([accumulated-size 0]
                 [accumulated-count 1])
                ([child
                  (in-list
                   (ancestry-immediate-children ancestry address))])
              (define child-result (subtree-result child))
              (define child-size (car child-result))
              (define child-count (cdr child-result))
              (define shuffle-count
                (binomial/capped
                 (+ accumulated-size child-size)
                 child-size
                 limit))
              (values
               (+ accumulated-size child-size)
               (cap-multiply
                (cap-multiply
                 accumulated-count child-count limit)
                shuffle-count
                limit))))
          (cons (add1 children-size) children-count))))
     (define count (cdr (subtree-result '())))
     (if (over-limit? count limit)
         (not-computed
          operation limit (add1 limit) 'linear-extension-count
          (hash 'vertex-count vertex-count
                'orientation 'descendant<=ancestor))
         count)]))

(define (linear-extension-count
         source #:limit [limit analysis-default-limit])
  (check-limit 'linear-extension-count limit)
  (define ancestry
    (normalize-ancestry source 'linear-extension-count))
  (if (analysis-error? ancestry)
      ancestry
      (linear-extension-count/internal
       ancestry limit 'linear-extension-count)))

(define (iterated-coproduct
         source power #:limit [limit analysis-default-limit])
  (check-positive-power 'iterated-coproduct power)
  (check-limit 'iterated-coproduct limit)
  (define normalized
    (normalize-connected-basis source 'iterated-coproduct))
  (cond
    [(analysis-error? normalized) normalized]
    [else
     ;; The independent order-map count is exactly the total positive
     ;; coefficient mass of this iterated connected coproduct.  It is thus a
     ;; true preflight bound on all subsequent coordinate expansions.
     (define preflight
       (weak-order-map-count/internal
        (normalized-basis-ancestry normalized)
        power
        limit
        'iterated-coproduct))
     (cond
       [(analysis-limit? preflight) preflight]
       [else
        (let loop ([rank 1]
                   [current (normalized-basis-sum normalized)])
          (cond
            [(= rank power) current]
            [else
             ;; Always expand the rightmost coordinate.  Tensor coordinates
             ;; remain ordered; coassociativity, not forest order, relates the
             ;; alternative parenthesisations.
             (define next
               (formal-sum-expand-coordinate
                current rank 2 forest-coproduct))
             (if (formal-sum? next)
                 (loop (add1 rank) next)
                 (analysis-error
                  'coordinate-expansion-failed
                  "expanding a valid connected CK coordinate unexpectedly failed"
                  'iterated-coproduct
                  'formal-sum
                  next
                  (hash 'coordinate rank
                        'source source)))]))])]))

(define (analysis-result-for operation result)
  (cond
    [(analysis-limit? result)
     (analysis-limit
      (analysis-limit-code result)
      (analysis-limit-message result)
      operation
      (analysis-limit-limit result)
      (analysis-limit-required result)
      (analysis-limit-metric result)
      (analysis-limit-details result))]
    [(analysis-error? result)
     (analysis-error
      (analysis-error-code result)
      (analysis-error-message result)
      operation
      (analysis-error-expected result)
      (analysis-error-actual result)
      (analysis-error-details result))]
    [else result]))

(define (zeta-convolution-power
         source power #:limit [limit analysis-default-limit])
  (check-positive-power 'zeta-convolution-power power)
  (check-limit 'zeta-convolution-power limit)
  (define iterated
    (iterated-coproduct source power #:limit limit))
  (define result
    (if (formal-sum? iterated)
      (for/sum ([entry (in-list (formal-sum-terms iterated))])
        (cdr entry))
      iterated))
  (analysis-result-for 'zeta-convolution-power result))

(define (omega-one-convolution-power
         source power #:limit [limit analysis-default-limit])
  (check-positive-power 'omega-one-convolution-power power)
  (check-limit 'omega-one-convolution-power limit)
  (define iterated
    (iterated-coproduct source power #:limit limit))
  (define result
    (if (formal-sum? iterated)
      (for/sum ([entry (in-list (formal-sum-terms iterated))]
                #:when
                (for/and ([forest (in-vector (car entry))])
                  (= (forest-degree forest) 1)))
        (cdr entry))
      iterated))
  (analysis-result-for 'omega-one-convolution-power result))
